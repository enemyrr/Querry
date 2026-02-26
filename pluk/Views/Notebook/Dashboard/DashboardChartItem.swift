import AppKit
import SwiftUI

final class DashboardChartItem: NSCollectionViewItem {

    static let identifier = NSUserInterfaceItemIdentifier("DashboardChartItem")

    var onResize: ((NotebookBlock, CGFloat) -> Void)?
    var onWidthResize: ((NotebookBlock, CGFloat) -> Void)?
    var onDragBegan: ((NSEvent) -> Void)?
    var onDragMoved: ((NSEvent) -> Void)?
    var onDragEnded: ((NSEvent) -> Void)?

    private var dragHandle: DashboardDragHandle!
    private var titleLabel: NSTextField!
    private var blockContainer: NSView!
    private var resizeHandle: BlockResizeHandle!
    private var widthResizeHandle: BlockWidthResizeHandle!
    private var handleWidthConstraint: NSLayoutConstraint!
    private var hostingView: NSHostingView<AnyView>?
    private weak var currentBlock: NotebookBlock?
    private var trackingArea: NSTrackingArea?
    private var isHovered = false
    private var isPublished = false

    override func loadView() {
        let wrapper = NSView()
        wrapper.wantsLayer = true
        self.view = wrapper

        setupDragHandle()
        setupTitleLabel()
        setupBlockContainer()
        setupResizeHandle()
        setupWidthResizeHandle()
        setupConstraints()

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAppearanceChange),
            name: .appAppearanceDidChange,
            object: nil
        )
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    func configure(block: NotebookBlock, viewModel: ChartBlockViewModel, isPublished: Bool = false) {
        currentBlock = block
        self.isPublished = isPublished
        titleLabel.stringValue = block.title.isEmpty ? "Untitled Chart" : block.title
        titleLabel.isHidden = isPublished
        dragHandle.isHidden = isPublished
        resizeHandle.isHidden = isPublished
        widthResizeHandle.isHidden = isPublished
        handleWidthConstraint.constant = isPublished ? 0 : 12
        hostingView?.removeFromSuperview()

        let chartView = ChartPreviewView(viewModel: viewModel)
        let hosting = NSHostingView(rootView: AnyView(chartView))
        hosting.translatesAutoresizingMaskIntoConstraints = false
        blockContainer.addSubview(hosting)
        hostingView = hosting

        NSLayoutConstraint.activate([
            hosting.topAnchor.constraint(equalTo: blockContainer.topAnchor),
            hosting.leadingAnchor.constraint(equalTo: blockContainer.leadingAnchor),
            hosting.trailingAnchor.constraint(equalTo: blockContainer.trailingAnchor),
            hosting.bottomAnchor.constraint(equalTo: blockContainer.bottomAnchor),
        ])
    }

    // MARK: - Layout

    private func setupDragHandle() {
        dragHandle = DashboardDragHandle()
        dragHandle.translatesAutoresizingMaskIntoConstraints = false
        dragHandle.alphaValue = 0
        dragHandle.setContentHuggingPriority(.required, for: .horizontal)
        dragHandle.onDragBegan = { [weak self] event in self?.onDragBegan?(event) }
        dragHandle.onDragMoved = { [weak self] event in self?.onDragMoved?(event) }
        dragHandle.onDragEnded = { [weak self] event in self?.onDragEnded?(event) }
        view.addSubview(dragHandle)
    }

    private func setupTitleLabel() {
        titleLabel = NSTextField(labelWithString: "")
        titleLabel.font = .systemFont(ofSize: 11, weight: .medium)
        titleLabel.textColor = .tertiaryLabelColor
        titleLabel.lineBreakMode = .byTruncatingTail
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(titleLabel)
    }

    private func setupBlockContainer() {
        blockContainer = NSView()
        blockContainer.wantsLayer = true
        blockContainer.layer?.cornerRadius = 10
        blockContainer.layer?.borderWidth = 1
        blockContainer.layer?.borderColor = NSColor.clear.cgColor
        blockContainer.layer?.masksToBounds = true
        blockContainer.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(blockContainer)
    }

    private func setupResizeHandle() {
        resizeHandle = BlockResizeHandle(onDrag: { [weak self] delta in
            guard let self, let block = self.currentBlock else { return }
            let newHeight = max(280, block.blockHeight + Double(delta))
            self.onResize?(block, newHeight)
        })
        resizeHandle.translatesAutoresizingMaskIntoConstraints = false
        resizeHandle.alphaValue = 0
        view.addSubview(resizeHandle)
    }

    private func setupWidthResizeHandle() {
        widthResizeHandle = BlockWidthResizeHandle(onDrag: { [weak self] delta in
            guard let self, let block = self.currentBlock else { return }
            self.onWidthResize?(block, delta)
        })
        widthResizeHandle.translatesAutoresizingMaskIntoConstraints = false
        widthResizeHandle.alphaValue = 0
        view.addSubview(widthResizeHandle)
    }

    private func setupConstraints() {
        handleWidthConstraint = widthResizeHandle.widthAnchor.constraint(equalToConstant: 12)

        NSLayoutConstraint.activate([
            dragHandle.centerYAnchor.constraint(equalTo: titleLabel.centerYAnchor),
            dragHandle.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 2),
            dragHandle.widthAnchor.constraint(equalToConstant: 14),
            dragHandle.heightAnchor.constraint(equalToConstant: 14),

            titleLabel.topAnchor.constraint(equalTo: view.topAnchor),
            titleLabel.leadingAnchor.constraint(equalTo: dragHandle.trailingAnchor, constant: 2),
            titleLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -4),

            blockContainer.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 3),
            blockContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            blockContainer.trailingAnchor.constraint(equalTo: widthResizeHandle.leadingAnchor),

            widthResizeHandle.topAnchor.constraint(equalTo: blockContainer.topAnchor),
            widthResizeHandle.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            handleWidthConstraint,
            widthResizeHandle.bottomAnchor.constraint(equalTo: blockContainer.bottomAnchor),

            resizeHandle.topAnchor.constraint(equalTo: blockContainer.bottomAnchor),
            resizeHandle.leadingAnchor.constraint(equalTo: blockContainer.leadingAnchor),
            resizeHandle.trailingAnchor.constraint(equalTo: blockContainer.trailingAnchor),
            resizeHandle.heightAnchor.constraint(equalToConstant: 12),
            resizeHandle.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
    }

    // MARK: - Hover Tracking

    override func viewDidLayout() {
        super.viewDidLayout()
        setupTrackingArea()
    }

    private func setupTrackingArea() {
        if let existing = trackingArea { view.removeTrackingArea(existing) }
        let area = NSTrackingArea(
            rect: .zero,
            options: [.mouseEnteredAndExited, .activeInActiveApp, .inVisibleRect],
            owner: self
        )
        view.addTrackingArea(area)
        trackingArea = area
    }

    override func mouseEntered(with event: NSEvent) {
        setHovered(true)
    }

    override func mouseExited(with event: NSEvent) {
        setHovered(false)
    }

    private func setHovered(_ hovered: Bool) {
        guard hovered != isHovered else { return }
        isHovered = hovered
        guard !isPublished else { return }
        let borderColor: CGColor = hovered ? borderColorForAppearance() : NSColor.clear.cgColor
        blockContainer.layer?.borderColor = borderColor
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.15
            let alpha: CGFloat = hovered ? 1 : 0
            dragHandle.animator().alphaValue = alpha
            resizeHandle.animator().alphaValue = alpha
            widthResizeHandle.animator().alphaValue = alpha
        }
    }

    // MARK: - Appearance

    private func borderColorForAppearance() -> CGColor {
        var color: CGColor = NSColor.clear.cgColor
        NSApp.effectiveAppearance.performAsCurrentDrawingAppearance {
            let isDark = NSAppearance.currentDrawing().isDarkMode
            color = isDark
                ? NSColor.white.withAlphaComponent(0.1).cgColor
                : NSColor.black.withAlphaComponent(0.08).cgColor
        }
        return color
    }

    @objc private func handleAppearanceChange() {
        if isHovered {
            blockContainer.layer?.borderColor = borderColorForAppearance()
        }
    }
}
