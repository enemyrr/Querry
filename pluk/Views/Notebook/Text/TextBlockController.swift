import AppKit

@MainActor
final class TextBlockController: NSViewController, MarkdownTextViewDelegate {

    let block: NotebookBlock
    private let dataController: NotebookDataController

    private var titleLabel: NSTextField!
    private var blockContainer: NSView!
    private var menuButton: NSButton!
    private var markdownTextView: MarkdownTextView!
    private var saveDebounceTask: Task<Void, Never>?

    init(block: NotebookBlock, dataController: NotebookDataController) {
        self.block = block
        self.dataController = dataController
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    deinit {
        saveDebounceTask?.cancel()
        NotificationCenter.default.removeObserver(self)
    }

    override func loadView() {
        let wrapper = BlockHoverTrackingView { [weak self] isHovered in
            guard let self,
                  let blockIndex = self.dataController.blocks.firstIndex(where: { $0.id == self.block.id }) else { return }
            NotificationCenter.default.post(
                name: .notebookBlockHoverChanged,
                object: nil,
                userInfo: ["blockIndex": blockIndex, "isHovered": isHovered]
            )
        }
        wrapper.wantsLayer = true
        wrapper.translatesAutoresizingMaskIntoConstraints = false
        self.view = wrapper

        setupTitleLabel()
        setupBlockContainer()
        setupMenuButton()
        setupMarkdownTextView()
        setupConstraints()

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAppearanceChange),
            name: .appAppearanceDidChange,
            object: nil
        )
    }

    // MARK: - Layout

    private func setupTitleLabel() {
        titleLabel = NSTextField(string: block.title)
        titleLabel.placeholderString = "Untitled Text"
        titleLabel.font = .systemFont(ofSize: 11, weight: .medium)
        titleLabel.textColor = .tertiaryLabelColor
        titleLabel.backgroundColor = .clear
        titleLabel.isBordered = false
        titleLabel.isBezeled = false
        titleLabel.focusRingType = .none
        titleLabel.isEditable = true
        titleLabel.delegate = self
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(titleLabel)
    }

    private func setupBlockContainer() {
        blockContainer = NSView()
        blockContainer.wantsLayer = true
        blockContainer.layer?.cornerRadius = 10
        blockContainer.layer?.borderWidth = 1
        blockContainer.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(blockContainer)
        updateBorderColor()
    }

    private func setupMenuButton() {
        menuButton = NSButton(frame: .zero)
        menuButton.image = NSImage(systemSymbolName: "ellipsis", accessibilityDescription: "Block menu")
        menuButton.symbolConfiguration = .init(pointSize: 12, weight: .medium)
        menuButton.bezelStyle = .accessoryBar
        menuButton.isBordered = false
        menuButton.imagePosition = .imageOnly
        menuButton.contentTintColor = .tertiaryLabelColor
        menuButton.translatesAutoresizingMaskIntoConstraints = false
        menuButton.target = self
        menuButton.action = #selector(showBlockMenu(_:))
        view.addSubview(menuButton)
    }

    private func setupMarkdownTextView() {
        markdownTextView = MarkdownTextView(frame: .zero)
        markdownTextView.delegate = self
        markdownTextView.translatesAutoresizingMaskIntoConstraints = false
        blockContainer.addSubview(markdownTextView)

        NSLayoutConstraint.activate([
            markdownTextView.topAnchor.constraint(equalTo: blockContainer.topAnchor),
            markdownTextView.leadingAnchor.constraint(equalTo: blockContainer.leadingAnchor),
            markdownTextView.trailingAnchor.constraint(equalTo: blockContainer.trailingAnchor),
            markdownTextView.bottomAnchor.constraint(equalTo: blockContainer.bottomAnchor),
        ])

        markdownTextView.string = block.textContent
    }

    private func setupConstraints() {
        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: view.topAnchor),
            titleLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 4),
            titleLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -28),

            menuButton.topAnchor.constraint(equalTo: titleLabel.bottomAnchor),
            menuButton.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            menuButton.widthAnchor.constraint(equalToConstant: 24),
            menuButton.heightAnchor.constraint(equalToConstant: 24),

            blockContainer.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 3),
            blockContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            blockContainer.trailingAnchor.constraint(equalTo: menuButton.leadingAnchor, constant: -4),
            blockContainer.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
    }

    // MARK: - Focus

    func focusEditor() {
        markdownTextView?.focus()
    }

    // MARK: - MarkdownTextViewDelegate

    func markdownTextViewDidChange(_ textView: MarkdownTextView) {
        block.textContent = textView.string
        saveDebounceTask?.cancel()
        saveDebounceTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .milliseconds(500))
            guard let self, !Task.isCancelled else { return }
            self.dataController.updateBlock(self.block)
        }
    }

    func markdownTextViewDidChangeHeight(_ textView: MarkdownTextView) {
        view.invalidateIntrinsicContentSize()
        view.superview?.needsLayout = true
    }

    // MARK: - Block Menu

    private var popover: NSPopover?

    @objc private func showBlockMenu(_ sender: NSButton) {
        let block = self.block
        let dc = dataController
        let dismiss = { [weak self] in self?.popover?.performClose(nil) }

        let blockIndex = dc.blocks.firstIndex(where: { $0.id == block.id }) ?? 0
        let isFirst = blockIndex == 0
        let isLast = blockIndex == dc.blocks.count - 1

        let popoverVC = BlockMenuPopoverController(
            canMoveUp: !isFirst,
            canMoveDown: !isLast,
            onAddAbove: { dismiss(); dc.insertTextBlock(at: blockIndex) },
            onAddBelow: { dismiss(); dc.insertTextBlock(at: blockIndex + 1) },
            onMoveUp: { dismiss(); dc.moveBlockUp(block) },
            onMoveDown: { dismiss(); dc.moveBlockDown(block) },
            onDuplicate: { dismiss(); dc.duplicateBlock(block) },
            isHiddenInDashboard: block.isHiddenInDashboard,
            onToggleDashboardVisibility: { dismiss(); dc.toggleBlockDashboardVisibility(block) },
            onDelete: { dismiss(); dc.deleteBlock(block) }
        )

        let pop = NSPopover()
        pop.contentViewController = popoverVC
        pop.behavior = .transient
        pop.show(relativeTo: sender.bounds, of: sender, preferredEdge: .maxY)
        self.popover = pop
    }

    // MARK: - Appearance

    private func updateBorderColor() {
        NSApp.effectiveAppearance.performAsCurrentDrawingAppearance {
            let isDark = NSAppearance.currentDrawing().isDarkMode
            blockContainer.layer?.borderColor = isDark
                ? NSColor.white.withAlphaComponent(0.1).cgColor
                : NSColor.black.withAlphaComponent(0.08).cgColor
        }
    }

    @objc private func handleAppearanceChange() {
        updateBorderColor()
    }
}

// MARK: - NSTextFieldDelegate

extension TextBlockController: NSTextFieldDelegate {
    func controlTextDidEndEditing(_ obj: Notification) {
        guard let field = obj.object as? NSTextField, field === titleLabel else { return }
        block.title = field.stringValue
        dataController.updateBlock(block)
    }
}

