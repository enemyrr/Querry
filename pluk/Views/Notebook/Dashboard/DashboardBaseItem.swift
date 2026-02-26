import AppKit

class DashboardBaseItem: NSCollectionViewItem {

    var onResize: ((NotebookBlock, CGFloat) -> Void)?
    var onWidthResize: ((NotebookBlock, CGFloat) -> Void)?
    var onDragBegan: ((NSEvent) -> Void)?
    var onDragMoved: ((NSEvent) -> Void)?
    var onDragEnded: ((NSEvent) -> Void)?

    private(set) var dragHandle: DashboardDragHandle!
    private(set) var titleLabel: NSTextField!
    private(set) var blockContainer: NSView!
    private(set) var resizeHandle: BlockResizeHandle!
    private(set) var widthResizeHandle: BlockWidthResizeHandle!
    private(set) var handleWidthConstraint: NSLayoutConstraint!

    weak var currentBlock: NotebookBlock?
    private(set) var isPublished = false
    private var trackingArea: NSTrackingArea?
    private var isHovered = false

    var minimumContentHeight: CGFloat { 80 }

    override func loadView() {
        let wrapper = NSView()
        wrapper.wantsLayer = true
        self.view = wrapper

        setupDragHandle()
        setupTitleLabel()
        setupBlockContainer()
        setupContent()
        setupResizeHandle()
        setupWidthResizeHandle()
        setupBaseConstraints()

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

    func setupContent() {
        // Subclasses override to add their content to blockContainer
    }

    func configureBase(block: NotebookBlock, isPublished: Bool) {
        currentBlock = block
        self.isPublished = isPublished

        let defaultTitle = block.blockType == .chart ? "Untitled Chart" : "Untitled Text"
        titleLabel.stringValue = block.title.isEmpty ? defaultTitle : block.title
        titleLabel.isHidden = isPublished
        dragHandle.isHidden = isPublished
        resizeHandle.isHidden = isPublished
        widthResizeHandle.isHidden = isPublished
        handleWidthConstraint.constant = isPublished ? 0 : 12
    }

    // MARK: - Setup

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
            let newHeight = max(self.minimumContentHeight, block.blockHeight + Double(delta))
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

    private func setupBaseConstraints() {
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
        refreshTrackingArea()
    }

    private func refreshTrackingArea() {
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
        blockContainer.layer?.borderColor = hovered ? borderColorForAppearance() : NSColor.clear.cgColor
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
