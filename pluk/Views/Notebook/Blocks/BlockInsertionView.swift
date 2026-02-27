import AppKit
import SwiftUI

final class BlockInsertionView: NSView {

    private let insertionIndex: Int
    private let dataController: NotebookDataController
    private let plusContentView = NSView()
    private let plusButton = NSView()
    private let leftLine = FadingLineView(fadeLeading: true)
    private let rightLine = FadingLineView(fadeLeading: false)
    private var trackingArea: NSTrackingArea?
    private var scrollBoundsObserver: NSObjectProtocol?

    private var isExpanded = false
    private var isInsertionHovered = false
    private var isBlockHovered = false
    private var actionBarView: NSView?
    private var heightConstraint: NSLayoutConstraint!

    init(insertionIndex: Int, dataController: NotebookDataController) {
        self.insertionIndex = insertionIndex
        self.dataController = dataController
        super.init(frame: .zero)

        wantsLayer = true

        setupPlusContent()
        plusContentView.alphaValue = 0

        heightConstraint = heightAnchor.constraint(equalToConstant: 28)
        heightConstraint.isActive = true

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAppearanceChange),
            name: .appAppearanceDidChange,
            object: nil
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleBlockHoverChanged(_:)),
            name: .notebookBlockHoverChanged,
            object: nil
        )
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    deinit {
        if let observer = scrollBoundsObserver {
            NotificationCenter.default.removeObserver(observer)
        }
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: - Setup

    private func setupPlusContent() {
        plusContentView.wantsLayer = true
        plusContentView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(plusContentView)

        plusButton.wantsLayer = true
        plusButton.layer?.cornerRadius = 8
        plusButton.translatesAutoresizingMaskIntoConstraints = false
        plusContentView.addSubview(plusButton)
        updatePlusBackground()

        let plusIcon = NSImageView()
        plusIcon.image = NSImage(systemSymbolName: "plus", accessibilityDescription: "Insert block")
        plusIcon.symbolConfiguration = .init(pointSize: 9, weight: .semibold)
        plusIcon.contentTintColor = .secondaryLabelColor
        plusIcon.translatesAutoresizingMaskIntoConstraints = false
        plusButton.addSubview(plusIcon)

        leftLine.translatesAutoresizingMaskIntoConstraints = false
        plusContentView.addSubview(leftLine)

        rightLine.translatesAutoresizingMaskIntoConstraints = false
        plusContentView.addSubview(rightLine)

        NSLayoutConstraint.activate([
            plusContentView.topAnchor.constraint(equalTo: topAnchor),
            plusContentView.leadingAnchor.constraint(equalTo: leadingAnchor),
            plusContentView.trailingAnchor.constraint(equalTo: trailingAnchor),
            plusContentView.heightAnchor.constraint(equalToConstant: 28),

            plusButton.centerXAnchor.constraint(equalTo: plusContentView.centerXAnchor),
            plusButton.centerYAnchor.constraint(equalTo: plusContentView.centerYAnchor),
            plusButton.widthAnchor.constraint(equalToConstant: 16),
            plusButton.heightAnchor.constraint(equalToConstant: 16),

            plusIcon.centerXAnchor.constraint(equalTo: plusButton.centerXAnchor),
            plusIcon.centerYAnchor.constraint(equalTo: plusButton.centerYAnchor),

            leftLine.leadingAnchor.constraint(equalTo: plusContentView.leadingAnchor),
            leftLine.trailingAnchor.constraint(equalTo: plusButton.leadingAnchor, constant: -8),
            leftLine.centerYAnchor.constraint(equalTo: plusContentView.centerYAnchor),
            leftLine.heightAnchor.constraint(equalToConstant: 1),

            rightLine.leadingAnchor.constraint(equalTo: plusButton.trailingAnchor, constant: 8),
            rightLine.trailingAnchor.constraint(equalTo: plusContentView.trailingAnchor),
            rightLine.centerYAnchor.constraint(equalTo: plusContentView.centerYAnchor),
            rightLine.heightAnchor.constraint(equalToConstant: 1),
        ])
    }

    // MARK: - Expand / Collapse

    private func expand() {
        guard !isExpanded else { return }
        isExpanded = true

        plusContentView.alphaValue = 0
        plusContentView.isHidden = true

        let bar = NotebookActionBarView(
            dataController: dataController,
            insertionIndex: insertionIndex,
            onDidInsert: { [weak self] in
                self?.collapse()
            }
        )
        bar.translatesAutoresizingMaskIntoConstraints = false
        addSubview(bar)
        actionBarView = bar

        NSLayoutConstraint.activate([
            bar.centerXAnchor.constraint(equalTo: centerXAnchor),
            bar.centerYAnchor.constraint(equalTo: centerYAnchor),
            bar.topAnchor.constraint(greaterThanOrEqualTo: topAnchor),
            bar.bottomAnchor.constraint(lessThanOrEqualTo: bottomAnchor),
        ])

        heightConstraint.constant = 68

        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.2
            ctx.allowsImplicitAnimation = true
            self.superview?.layoutSubtreeIfNeeded()
        }
    }

    private func collapse() {
        guard isExpanded else { return }
        isExpanded = false

        actionBarView?.removeFromSuperview()
        actionBarView = nil

        plusContentView.isHidden = false
        heightConstraint.constant = 28
        updatePlusVisibility(animated: false)

        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.2
            ctx.allowsImplicitAnimation = true
            self.superview?.layoutSubtreeIfNeeded()
        }
    }

    // MARK: - Tracking

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let existing = trackingArea { removeTrackingArea(existing) }
        let area = NSTrackingArea(
            rect: .zero,
            options: [.mouseEnteredAndExited, .activeInActiveApp, .inVisibleRect],
            owner: self
        )
        addTrackingArea(area)
        trackingArea = area
        refreshInsertionHoverState(animated: false)
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        setupScrollBoundsObserver()
        refreshInsertionHoverState(animated: false)
    }

    override func viewDidMoveToSuperview() {
        super.viewDidMoveToSuperview()
        setupScrollBoundsObserver()
        refreshInsertionHoverState(animated: false)
    }

    override func mouseEntered(with event: NSEvent) {
        setInsertionHovered(true, animated: true)
    }

    override func mouseExited(with event: NSEvent) {
        setInsertionHovered(false, animated: true)
    }

    override func mouseDown(with event: NSEvent) {
        if isExpanded {
            if isMouseInsideActionBar(event.locationInWindow) {
                return
            }
            collapse()
        } else {
            expand()
        }
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        if isExpanded, let bar = actionBarView, !bar.isHidden {
            let pointInSelf = convert(point, from: superview)
            if let hit = bar.hitTest(pointInSelf) {
                return hit
            }
        }
        return super.hitTest(point)
    }

    // MARK: - Appearance

    @objc private func handleAppearanceChange() {
        updatePlusBackground()
    }

    @objc private func handleBlockHoverChanged(_ notification: Notification) {
        guard !isExpanded,
              let blockIndex = notification.userInfo?["blockIndex"] as? Int,
              let isHovered = notification.userInfo?["isHovered"] as? Bool else { return }

        let sourceBlockIndex = insertionIndex - 1
        if blockIndex == sourceBlockIndex {
            isBlockHovered = isHovered
        } else if isHovered {
            isBlockHovered = false
        } else {
            return
        }

        updatePlusVisibility(animated: true)
    }

    private func updatePlusBackground() {
        NSApp.effectiveAppearance.performAsCurrentDrawingAppearance {
            let isDark = NSAppearance.currentDrawing().isDarkMode
            plusButton.layer?.backgroundColor = isDark
                ? NSColor.white.withAlphaComponent(0.08).cgColor
                : NSColor.black.withAlphaComponent(0.06).cgColor
        }
    }

    private func setupScrollBoundsObserver() {
        if let observer = scrollBoundsObserver {
            NotificationCenter.default.removeObserver(observer)
            scrollBoundsObserver = nil
        }

        guard let clipView = enclosingScrollView?.contentView else { return }
        clipView.postsBoundsChangedNotifications = true
        scrollBoundsObserver = NotificationCenter.default.addObserver(
            forName: NSView.boundsDidChangeNotification,
            object: clipView,
            queue: .main
        ) { [weak self] _ in
            self?.refreshInsertionHoverState(animated: false)
        }
    }

    private func refreshInsertionHoverState(animated: Bool) {
        guard let window else {
            setInsertionHovered(false, animated: animated)
            return
        }

        let mouseLocation = convert(window.mouseLocationOutsideOfEventStream, from: nil)
        setInsertionHovered(bounds.contains(mouseLocation), animated: animated)
    }

    private func setInsertionHovered(_ hovered: Bool, animated: Bool) {
        guard hovered != isInsertionHovered else { return }
        isInsertionHovered = hovered
        updatePlusVisibility(animated: animated)
    }

    private func updatePlusVisibility(animated: Bool) {
        guard !isExpanded else { return }

        let alpha: CGFloat = (isInsertionHovered || isBlockHovered) ? 1 : 0
        if animated {
            NSAnimationContext.runAnimationGroup { ctx in
                ctx.duration = 0.15
                plusContentView.animator().alphaValue = alpha
            }
            return
        }

        plusContentView.alphaValue = alpha
    }

    private func isMouseInsideActionBar(_ locationInWindow: NSPoint) -> Bool {
        guard let bar = actionBarView, !bar.isHidden else { return false }
        let pointInBar = bar.convert(locationInWindow, from: nil)
        return bar.bounds.contains(pointInBar)
    }
}

// MARK: - Fading Line

private final class FadingLineView: NSView {

    private let fadeLeading: Bool
    private let gradientLayer = CAGradientLayer()

    init(fadeLeading: Bool) {
        self.fadeLeading = fadeLeading
        super.init(frame: .zero)
        wantsLayer = true
        gradientLayer.startPoint = CGPoint(x: 0, y: 0.5)
        gradientLayer.endPoint = CGPoint(x: 1, y: 0.5)
        layer?.addSublayer(gradientLayer)
        updateColors()

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appearanceChanged),
            name: .appAppearanceDidChange,
            object: nil
        )
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    override func layout() {
        super.layout()
        gradientLayer.frame = bounds
    }

    @objc private func appearanceChanged() {
        updateColors()
    }

    private func updateColors() {
        NSApp.effectiveAppearance.performAsCurrentDrawingAppearance {
            let separator = NSColor.separatorColor.cgColor
            let clear = NSColor.separatorColor.withAlphaComponent(0).cgColor
            gradientLayer.colors = fadeLeading ? [clear, separator] : [separator, clear]
        }
    }
}
