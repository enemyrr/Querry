import AppKit

final class DashboardTextItem: NSCollectionViewItem {

    static let identifier = NSUserInterfaceItemIdentifier("DashboardTextItem")

    var onResize: ((NotebookBlock, CGFloat) -> Void)?

    private var titleLabel: NSTextField!
    private var blockContainer: NSView!
    private var resizeHandle: BlockResizeHandle!
    private var textView: NSTextView!
    private var scrollView: NSScrollView!
    private weak var currentBlock: NotebookBlock?
    private var trackingArea: NSTrackingArea?
    private var isHovered = false
    private var isPublished = false

    override func loadView() {
        let wrapper = NSView()
        wrapper.wantsLayer = true
        self.view = wrapper

        setupTitleLabel()
        setupBlockContainer()
        setupTextView()
        setupResizeHandle()
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

    private let defaultParagraphStyle: NSParagraphStyle = {
        let style = NSMutableParagraphStyle()
        style.lineSpacing = 6
        return style
    }()

    func configure(block: NotebookBlock, isPublished: Bool = false) {
        currentBlock = block
        self.isPublished = isPublished
        titleLabel.isHidden = isPublished
        resizeHandle.isHidden = isPublished
        titleLabel.stringValue = block.title.isEmpty ? "Untitled Text" : block.title

        let text = block.textContent
        let defaultFont = NSFont.systemFont(ofSize: 14)
        let attrString = NSMutableAttributedString(string: text, attributes: [
            .font: defaultFont,
            .foregroundColor: NSColor.labelColor,
            .paragraphStyle: defaultParagraphStyle,
        ])

        let styledRanges = MarkdownParser.styledRanges(for: text, defaultFont: defaultFont)
        for styled in styledRanges {
            if styled.isMarker {
                attrString.addAttributes(MarkdownParser.hiddenMarkerAttributes, range: styled.range)
            } else {
                attrString.addAttributes(styled.attributes, range: styled.range)
            }
        }

        textView.textStorage?.setAttributedString(attrString)
    }

    // MARK: - Layout

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

    private func setupTextView() {
        scrollView = NSScrollView()
        scrollView.hasVerticalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.drawsBackground = false
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        blockContainer.addSubview(scrollView)

        let contentSize = scrollView.contentSize
        textView = NSTextView(frame: NSRect(origin: .zero, size: contentSize))
        textView.isEditable = false
        textView.isSelectable = true
        textView.drawsBackground = false
        textView.textContainerInset = NSSize(width: 16, height: 12)
        textView.textContainer?.lineFragmentPadding = 0
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        textView.textContainer?.containerSize = NSSize(width: contentSize.width, height: .greatestFiniteMagnitude)
        textView.textContainer?.widthTracksTextView = true
        scrollView.documentView = textView

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: blockContainer.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: blockContainer.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: blockContainer.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: blockContainer.bottomAnchor),
        ])
    }

    private func setupResizeHandle() {
        resizeHandle = BlockResizeHandle(onDrag: { [weak self] delta in
            guard let self, let block = self.currentBlock else { return }
            let newHeight = max(80, block.blockHeight + Double(delta))
            self.onResize?(block, newHeight)
        })
        resizeHandle.translatesAutoresizingMaskIntoConstraints = false
        resizeHandle.alphaValue = 0
        view.addSubview(resizeHandle)
    }

    private func setupConstraints() {
        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: view.topAnchor),
            titleLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 4),
            titleLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -4),

            blockContainer.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 3),
            blockContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            blockContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor),

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
        updateBorderColor()
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.15
            resizeHandle.animator().alphaValue = hovered ? 1 : 0
        }
    }

    // MARK: - Appearance

    private func updateBorderColor() {
        NSApp.effectiveAppearance.performAsCurrentDrawingAppearance {
            if isHovered {
                let isDark = NSAppearance.currentDrawing().isDarkMode
                blockContainer.layer?.borderColor = isDark
                    ? NSColor.white.withAlphaComponent(0.1).cgColor
                    : NSColor.black.withAlphaComponent(0.08).cgColor
            } else {
                blockContainer.layer?.borderColor = NSColor.clear.cgColor
            }
        }
    }

    @objc private func handleAppearanceChange() {
        updateBorderColor()
    }
}
