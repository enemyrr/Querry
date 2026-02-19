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

    private var isExpanded = false
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
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    deinit {
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
            bar.topAnchor.constraint(equalTo: topAnchor),
            bar.centerXAnchor.constraint(equalTo: centerXAnchor),
            bar.bottomAnchor.constraint(equalTo: bottomAnchor),
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

        heightConstraint.constant = 28

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
            rect: bounds,
            options: [.mouseEnteredAndExited, .activeInActiveApp],
            owner: self
        )
        addTrackingArea(area)
        trackingArea = area
    }

    override func mouseEntered(with event: NSEvent) {
        guard !isExpanded else { return }
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.15
            plusContentView.animator().alphaValue = 1
        }
    }

    override func mouseExited(with event: NSEvent) {
        guard !isExpanded else { return }
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.15
            plusContentView.animator().alphaValue = 0
        }
    }

    override func mouseDown(with event: NSEvent) {
        if isExpanded {
            collapse()
        } else {
            expand()
        }
    }

    // MARK: - Appearance

    @objc private func handleAppearanceChange() {
        updatePlusBackground()
    }

    private func updatePlusBackground() {
        NSApp.effectiveAppearance.performAsCurrentDrawingAppearance {
            let isDark = NSAppearance.currentDrawing().isDarkMode
            plusButton.layer?.backgroundColor = isDark
                ? NSColor.white.withAlphaComponent(0.08).cgColor
                : NSColor.black.withAlphaComponent(0.06).cgColor
        }
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
