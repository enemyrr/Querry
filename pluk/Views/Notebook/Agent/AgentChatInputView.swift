import AppKit

final class AgentChatInputView: NSView {

    var onSend: (String) -> Void = { _ in }
    var onStop: () -> Void = {}
    var onConnectionsChanged: (([Connection]) -> Void)?

    private let containerView: NSView
    private let chipScrollView: NSScrollView
    private let chipContainerView: NSView
    private let inputTextView: AgentInputTextView
    private let sendButton: AgentSendButton
    private let placeholderLabel: NSTextField
    private let statusLabel: NSTextField

    private var availableConnections: [Connection]
    private var selectedConnections: [Connection] = []
    private var pendingAtRange: NSRange?
    private var suppressNextReturnSend = false
    private var isConnectionMenuOpen = false

    private var inputTopToContainer: NSLayoutConstraint!
    private var inputTopToChips: NSLayoutConstraint!
    private var chipScrollHeightConstraint: NSLayoutConstraint!

    var userMessage: String {
        inputTextView.textView.string
    }

    var text: String {
        get { userMessage }
        set {
            inputTextView.textView.string = newValue
            inputTextView.recalculateHeight()
            placeholderLabel.isHidden = !newValue.isEmpty || !selectedConnections.isEmpty
            if !isStreaming {
                sendButton.isEnabled = !newValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            }
        }
    }

    var isStreaming: Bool = false {
        didSet {
            sendButton.mode = isStreaming ? .stop : .send
            sendButton.isEnabled = isStreaming || !userMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
    }

    init(connections: [Connection] = []) {
        self.availableConnections = connections
        containerView = NSView()
        chipScrollView = NSScrollView()
        chipContainerView = NSView()
        inputTextView = AgentInputTextView()
        sendButton = AgentSendButton()
        placeholderLabel = NSTextField(labelWithString: "Analyze data, build charts, explore trends...")
        statusLabel = NSTextField(labelWithString: "")

        super.init(frame: .zero)

        setupContainer()
        setupChipContainer()
        setupPlaceholder()
        setupInputTextView()
        setupStatusLabel()
        setupSendButton()
        setupConstraints()

        inputTextView.onTextChanged = { [weak self] in
            guard let self else { return }
            let msg = self.userMessage
            self.placeholderLabel.isHidden = !msg.isEmpty || !self.selectedConnections.isEmpty
            if !self.isStreaming {
                self.sendButton.isEnabled = !msg.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            }
            self.handleAtDetection()
        }

        let handleSend: () -> Void = { [weak self] in
            guard let self else { return }
            if self.isStreaming {
                self.onStop()
                return
            }
            let message = self.userMessage
            guard !message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
            self.onSend(message)
            self.text = ""
            self.clearSelectedConnections()
        }

        sendButton.action = handleSend
        inputTextView.onReturn = { [weak self] in
            guard let self else { return }
            if self.isConnectionMenuOpen || self.pendingAtRange != nil {
                return
            }
            if self.suppressNextReturnSend {
                self.suppressNextReturnSend = false
                return
            }
            handleSend()
        }

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

    func focusInput() {
        window?.makeFirstResponder(inputTextView.textView)
    }

    func setStatusMessage(_ message: String?) {
        if let message, !message.isEmpty {
            statusLabel.stringValue = message
            statusLabel.isHidden = false
        } else {
            statusLabel.isHidden = true
        }
    }

    // MARK: - Setup

    private func setupContainer() {
        containerView.wantsLayer = true
        containerView.layer?.cornerRadius = 14
        containerView.layer?.cornerCurve = .continuous
        containerView.layer?.borderWidth = 0.5
        containerView.layer?.shadowColor = NSColor.black.withAlphaComponent(0.10).cgColor
        containerView.layer?.shadowOpacity = 1.0
        containerView.layer?.shadowRadius = 1
        containerView.layer?.shadowOffset = CGSize(width: 0, height: 1)
        containerView.setContentHuggingPriority(.defaultLow, for: .horizontal)
        containerView.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        containerView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(containerView)
        updateContainerAppearance()
    }

    private func setupChipContainer() {
        chipScrollView.drawsBackground = false
        chipScrollView.contentView.drawsBackground = false
        chipScrollView.borderType = .noBorder
        chipScrollView.hasHorizontalScroller = false
        chipScrollView.hasVerticalScroller = false
        chipScrollView.horizontalScrollElasticity = .allowed
        chipScrollView.verticalScrollElasticity = .none
        chipScrollView.translatesAutoresizingMaskIntoConstraints = false
        chipScrollView.isHidden = true

        chipContainerView.translatesAutoresizingMaskIntoConstraints = true
        chipScrollView.documentView = chipContainerView
        containerView.addSubview(chipScrollView)
    }

    private func setupPlaceholder() {
        placeholderLabel.font = .preferredFont(forTextStyle: .title3)
        placeholderLabel.textColor = .placeholderTextColor
        placeholderLabel.backgroundColor = .clear
        placeholderLabel.isBordered = false
        placeholderLabel.isBezeled = false
        placeholderLabel.isEditable = false
        placeholderLabel.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(placeholderLabel)
    }

    private func setupInputTextView() {
        inputTextView.setContentHuggingPriority(.defaultLow, for: .horizontal)
        inputTextView.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        inputTextView.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(inputTextView)
    }

    private func setupStatusLabel() {
        statusLabel.font = .systemFont(ofSize: 11)
        statusLabel.textColor = .secondaryLabelColor
        statusLabel.backgroundColor = .clear
        statusLabel.isBordered = false
        statusLabel.isBezeled = false
        statusLabel.isEditable = false
        statusLabel.lineBreakMode = .byTruncatingTail
        statusLabel.isHidden = true
        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(statusLabel)
    }

    private func setupSendButton() {
        sendButton.isEnabled = false
        sendButton.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(sendButton)
    }

    private func setupConstraints() {
        inputTopToContainer = inputTextView.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 16)
        inputTopToChips = inputTextView.topAnchor.constraint(equalTo: chipScrollView.bottomAnchor, constant: 8)
        chipScrollHeightConstraint = chipScrollView.heightAnchor.constraint(equalToConstant: 0)

        NSLayoutConstraint.activate([
            containerView.topAnchor.constraint(equalTo: topAnchor),
            containerView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 4),
            containerView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -4),
            containerView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -4),

            chipScrollView.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 5),
            chipScrollView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 12),
            chipScrollView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -12),
            chipScrollHeightConstraint,

            inputTopToContainer,

            inputTextView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 16),
            inputTextView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -16),

            placeholderLabel.topAnchor.constraint(equalTo: inputTextView.topAnchor),
            placeholderLabel.leadingAnchor.constraint(equalTo: inputTextView.leadingAnchor),

            sendButton.topAnchor.constraint(equalTo: inputTextView.bottomAnchor, constant: 10),
            sendButton.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -10),
            sendButton.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -10),

            statusLabel.centerYAnchor.constraint(equalTo: sendButton.centerYAnchor),
            statusLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 16),
            statusLabel.trailingAnchor.constraint(lessThanOrEqualTo: sendButton.leadingAnchor, constant: -8),
        ])
    }

    // MARK: - @ Connection Menu

    private func handleAtDetection() {
        guard !availableConnections.isEmpty else { return }
        let tv = inputTextView.textView
        let selectedRange = tv.selectedRange()
        guard selectedRange.length == 0, selectedRange.location > 0 else { return }

        let nsText = tv.string as NSString
        let atRange = NSRange(location: selectedRange.location - 1, length: 1)
        guard NSMaxRange(atRange) <= nsText.length, nsText.substring(with: atRange) == "@" else { return }
        if let pendingAtRange, NSEqualRanges(pendingAtRange, atRange) {
            return
        }
        pendingAtRange = atRange
        showConnectionMenu()
    }

    private func showConnectionMenu() {
        let menu = NSMenu()
        menu.autoenablesItems = false
        menu.font = .systemFont(ofSize: 13)

        for connection in availableConnections {
            let isSelected = selectedConnections.contains(where: { $0.keychainId == connection.keychainId })
            let item = NSMenuItem(title: connection.name, action: #selector(connectionMenuItemClicked(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = connection.keychainId
            item.state = isSelected ? .on : .off
            if let icon = NSImage(named: connection.databaseType.icon) {
                item.image = icon
                item.image?.size = NSSize(width: 16, height: 16)
            }
            menu.addItem(item)
        }

        containerView.layoutSubtreeIfNeeded()
        menu.update()

        let gap: CGFloat = 6
        let menuHeight = menu.size.height
        let menuPointAbove = NSPoint(
            x: inputTextView.frame.minX,
            y: inputTextView.frame.maxY + gap + menuHeight
        )
        let menuPointBelow = NSPoint(
            x: inputTextView.frame.minX,
            y: max(0, inputTextView.frame.minY - gap)
        )

        var menuPoint = menuPointAbove
        if let window {
            let anchorInWindow = containerView.convert(
                NSPoint(x: inputTextView.frame.minX, y: inputTextView.frame.maxY),
                to: nil
            )
            let anchorInScreen = window.convertPoint(toScreen: anchorInWindow)
            let visibleScreenFrame = window.screen?.visibleFrame ?? NSScreen.main?.visibleFrame
            let spaceAbove = (visibleScreenFrame?.maxY ?? .greatestFiniteMagnitude) - anchorInScreen.y
            if spaceAbove < menuHeight + gap {
                menuPoint = menuPointBelow
            }
        }

        isConnectionMenuOpen = true
        suppressNextReturnSend = true
        _ = menu.popUp(positioning: nil, at: menuPoint, in: containerView)
        pendingAtRange = nil
        isConnectionMenuOpen = false
        Task { @MainActor [weak self] in
            await Task.yield()
            self?.suppressNextReturnSend = false
        }
        window?.makeFirstResponder(inputTextView.textView)
    }

    @objc private func connectionMenuItemClicked(_ sender: NSMenuItem) {
        guard let keychainId = sender.representedObject as? String,
              let connection = availableConnections.first(where: { $0.keychainId == keychainId }) else { return }

        let wasSelected = selectedConnections.contains(where: { $0.keychainId == keychainId })
        if wasSelected {
            selectedConnections.removeAll { $0.keychainId == keychainId }
        } else {
            selectedConnections.append(connection)
        }

        let tv = inputTextView.textView

        if let pendingAtRange {
            let nsText = tv.string as NSString
            if NSMaxRange(pendingAtRange) <= nsText.length,
               nsText.substring(with: pendingAtRange) == "@" {
                if wasSelected {
                    // Deselected — just remove the "@"
                    tv.textStorage?.replaceCharacters(in: pendingAtRange, with: "")
                    tv.setSelectedRange(NSRange(location: pendingAtRange.location, length: 0))
                } else {
                    // Selected — replace "@" with styled connection tag
                    let tag = buildConnectionTag(for: connection)
                    tv.textStorage?.replaceCharacters(in: pendingAtRange, with: tag)
                    tv.setSelectedRange(NSRange(location: pendingAtRange.location + tag.length, length: 0))
                    tv.typingAttributes = [
                        .font: NSFont.preferredFont(forTextStyle: .title3),
                        .foregroundColor: NSColor.labelColor,
                    ]
                }
            }
        }
        pendingAtRange = nil

        handleConnectionSelectionDidChange()
    }

    private func buildConnectionTag(for connection: Connection) -> NSAttributedString {
        let textFont = NSFont.preferredFont(forTextStyle: .title3)
        let attrs: [NSAttributedString.Key: Any] = [
            .font: textFont,
            .foregroundColor: NSColor.secondaryLabelColor,
        ]

        let tag = NSMutableAttributedString()
        if let icon = NSImage(named: connection.databaseType.icon) {
            let attachment = NSTextAttachment()
            attachment.image = icon
            let iconSize: CGFloat = 13
            let yOffset = (textFont.capHeight - iconSize) / 2
            attachment.bounds = CGRect(x: 0, y: yOffset, width: iconSize, height: iconSize)
            let iconStr = NSMutableAttributedString(attachment: attachment)
            iconStr.addAttributes(attrs, range: NSRange(location: 0, length: iconStr.length))
            tag.append(iconStr)
            tag.append(NSAttributedString(string: " ", attributes: attrs))
        }
        tag.append(NSAttributedString(string: connection.name, attributes: attrs))
        tag.append(NSAttributedString(string: " ", attributes: [
            .font: textFont,
            .foregroundColor: NSColor.labelColor,
        ]))
        return tag
    }

    private func clearSelectedConnections() {
        selectedConnections.removeAll()
        rebuildChips()
        inputTextView.recalculateHeight()
        placeholderLabel.isHidden = !userMessage.isEmpty
    }

    // MARK: - Chip Management

    private func handleConnectionSelectionDidChange() {
        onConnectionsChanged?(selectedConnections)
        rebuildChips()
        inputTextView.recalculateHeight()

        let currentUserText = userMessage
        placeholderLabel.isHidden = !currentUserText.isEmpty || !selectedConnections.isEmpty
        if !isStreaming {
            sendButton.isEnabled = !currentUserText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
    }

    private func removeSelectedConnection(withKeychainID keychainID: String) {
        let previousCount = selectedConnections.count
        selectedConnections.removeAll { $0.keychainId == keychainID }
        guard selectedConnections.count != previousCount else { return }
        handleConnectionSelectionDidChange()
    }

    private func rebuildChips() {
        chipContainerView.subviews.forEach { $0.removeFromSuperview() }
        let cornerButtonOverflow: CGFloat = 7

        guard !selectedConnections.isEmpty else {
            chipScrollView.isHidden = true
            chipScrollHeightConstraint.constant = 0
            chipContainerView.frame = .zero
            inputTopToChips.isActive = false
            inputTopToContainer.isActive = true
            return
        }

        chipScrollView.isHidden = false
        inputTopToContainer.isActive = false
        inputTopToChips.isActive = true

        var leadingAnchorRef = chipContainerView.leadingAnchor
        var lastChip: NSView?

        for conn in selectedConnections {
            let chip = makeConnectionChip(for: conn)
            chip.translatesAutoresizingMaskIntoConstraints = false
            chipContainerView.addSubview(chip)

            NSLayoutConstraint.activate([
                chip.topAnchor.constraint(equalTo: chipContainerView.topAnchor, constant: cornerButtonOverflow),
                chip.bottomAnchor.constraint(equalTo: chipContainerView.bottomAnchor),
                chip.leadingAnchor.constraint(equalTo: leadingAnchorRef, constant: lastChip == nil ? 0 : 10),
            ])

            leadingAnchorRef = chip.trailingAnchor
            lastChip = chip
        }

        if let last = lastChip {
            last.trailingAnchor.constraint(equalTo: chipContainerView.trailingAnchor, constant: -cornerButtonOverflow).isActive = true
        }

        chipContainerView.layoutSubtreeIfNeeded()
        let contentSize = chipContainerView.fittingSize
        let width = max(1, ceil(contentSize.width))
        let height = max(1, ceil(contentSize.height))

        chipContainerView.frame = NSRect(x: 0, y: 0, width: width, height: height)
        chipScrollHeightConstraint.constant = height
        chipScrollView.contentView.scroll(to: .zero)
        chipScrollView.reflectScrolledClipView(chipScrollView.contentView)
    }

    private func makeConnectionChip(for connection: Connection) -> NSView {
        let chip = AgentConnectionChipView(connection: connection)
        chip.setContentHuggingPriority(.required, for: .horizontal)
        chip.setContentCompressionResistancePriority(.required, for: .horizontal)
        chip.onRemove = { [weak self] in
            self?.removeSelectedConnection(withKeychainID: connection.keychainId)
        }
        return chip
    }

    // MARK: - Appearance

    private func updateContainerAppearance() {
        NSApp.effectiveAppearance.performAsCurrentDrawingAppearance {
            let isDark = NSAppearance.currentDrawing().isDarkMode
            containerView.layer?.borderColor = isDark
                ? NSColor.white.withAlphaComponent(0.08).cgColor
                : NSColor.black.withAlphaComponent(0.06).cgColor
            containerView.layer?.backgroundColor = isDark
                ? NSColor(white: 0.1, alpha: 1).cgColor
                : NSColor.white.cgColor
        }
    }

    @objc private func handleAppearanceChange() {
        updateContainerAppearance()
        sendButton.updateAppearance()
        rebuildChips()
    }
}

private final class AgentConnectionChipView: NSView {

    var onRemove: () -> Void = {}

    private let closeButton: NSButton
    private var trackingArea: NSTrackingArea?
    private var isHovering = false

    override init(frame: NSRect) {
        fatalError("init(frame:) is not supported")
    }

    init(connection: Connection) {
        let closeImage = NSImage(systemSymbolName: "xmark", accessibilityDescription: "Clear Connection")?
            .withSymbolConfiguration(NSImage.SymbolConfiguration(pointSize: 8, weight: .bold))
        closeButton = NSButton(image: closeImage ?? NSImage(), target: nil, action: nil)

        super.init(frame: .zero)

        setContentHuggingPriority(.required, for: .horizontal)
        setContentCompressionResistancePriority(.required, for: .horizontal)
        setContentHuggingPriority(.required, for: .vertical)
        setContentCompressionResistancePriority(.required, for: .vertical)

        wantsLayer = true
        layer?.cornerRadius = 8
        layer?.cornerCurve = .continuous
        layer?.masksToBounds = false

        let iconView = NSImageView()
        if let icon = NSImage(named: connection.databaseType.icon) {
            icon.size = NSSize(width: 16, height: 16)
            iconView.image = icon
        }
        iconView.imageAlignment = .alignCenter
        iconView.imageScaling = .scaleProportionallyDown
        iconView.translatesAutoresizingMaskIntoConstraints = false

        let nameLabel = NSTextField(labelWithString: connection.name)
        nameLabel.font = .systemFont(ofSize: 12, weight: .medium)
        nameLabel.textColor = .labelColor
        nameLabel.setContentHuggingPriority(.required, for: .horizontal)
        nameLabel.setContentCompressionResistancePriority(.required, for: .horizontal)
        nameLabel.translatesAutoresizingMaskIntoConstraints = false

        let subtitleLabel = NSTextField(labelWithString: connection.databaseType.rawValue.capitalized)
        subtitleLabel.font = .systemFont(ofSize: 10)
        subtitleLabel.textColor = .secondaryLabelColor
        subtitleLabel.setContentHuggingPriority(.required, for: .horizontal)
        subtitleLabel.setContentCompressionResistancePriority(.required, for: .horizontal)
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false

        let textStack = NSStackView(views: [nameLabel, subtitleLabel])
        textStack.orientation = .vertical
        textStack.alignment = .leading
        textStack.spacing = 0
        textStack.translatesAutoresizingMaskIntoConstraints = false

        closeButton.target = self
        closeButton.action = #selector(closeButtonClicked)
        closeButton.isBordered = false
        closeButton.focusRingType = .none
        closeButton.imagePosition = .imageOnly
        closeButton.translatesAutoresizingMaskIntoConstraints = false
        closeButton.toolTip = "Clear connection"
        closeButton.wantsLayer = true
        closeButton.layer?.cornerRadius = 7
        closeButton.layer?.masksToBounds = true
        closeButton.layer?.cornerCurve = .circular
        closeButton.isHidden = true

        addSubview(iconView)
        addSubview(textStack)
        addSubview(closeButton)

        NSLayoutConstraint.activate([
            iconView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
            iconView.centerYAnchor.constraint(equalTo: textStack.centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 16),
            iconView.heightAnchor.constraint(equalToConstant: 16),

            textStack.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: 6),
            textStack.topAnchor.constraint(equalTo: topAnchor, constant: 5),
            textStack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -5),
            textStack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -22),

            closeButton.centerXAnchor.constraint(equalTo: trailingAnchor, constant: -4),
            closeButton.centerYAnchor.constraint(equalTo: topAnchor, constant: 4),
            closeButton.widthAnchor.constraint(equalToConstant: 17),
            closeButton.heightAnchor.constraint(equalToConstant: 15),
        ])

        updateAppearance()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let trackingArea { removeTrackingArea(trackingArea) }
        let area = NSTrackingArea(
            rect: .zero,
            options: [.mouseEnteredAndExited, .activeInActiveApp, .inVisibleRect],
            owner: self
        )
        addTrackingArea(area)
        trackingArea = area
        refreshHoverState()
    }

    override func mouseEntered(with event: NSEvent) {
        setHovering(true)
    }

    override func mouseExited(with event: NSEvent) {
        setHovering(false)
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        updateAppearance()
    }

    @objc private func closeButtonClicked() {
        onRemove()
    }

    private func setHovering(_ hovering: Bool) {
        guard hovering != isHovering else { return }
        isHovering = hovering
        closeButton.isHidden = !hovering
    }

    private func refreshHoverState() {
        guard let window else {
            setHovering(false)
            return
        }
        let mouse = convert(window.mouseLocationOutsideOfEventStream, from: nil)
        setHovering(bounds.contains(mouse))
    }

    private func updateAppearance() {
        NSApp.effectiveAppearance.performAsCurrentDrawingAppearance {
            let isDark = NSAppearance.currentDrawing().isDarkMode
            layer?.backgroundColor = isDark
                ? NSColor.white.withAlphaComponent(0.08).cgColor
                : NSColor.black.withAlphaComponent(0.03).cgColor
            closeButton.layer?.backgroundColor = isDark
                ? NSColor(white: 0.35, alpha: 1).cgColor
                : NSColor(white: 0.78, alpha: 1).cgColor
            closeButton.contentTintColor = isDark
                ? NSColor(white: 0.85, alpha: 1)
                : NSColor(white: 0.4, alpha: 1)
        }
    }
}

// MARK: - Plain Paste Text View

private final class PlainPasteTextView: NSTextView {
    override func paste(_ sender: Any?) {
        pasteAsPlainText(sender)
    }
}

// MARK: - Input Text View

private final class AgentInputTextView: NSView, NSTextViewDelegate {

    let textView: NSTextView
    var onTextChanged: (() -> Void)?
    var onReturn: (() -> Void)?

    private var heightConstraint: NSLayoutConstraint!
    private var lastKnownHeight: CGFloat = 0

    override init(frame: NSRect) {
        let textStorage = NSTextStorage()
        let layoutManager = NSLayoutManager()
        textStorage.addLayoutManager(layoutManager)

        let textContainer = NSTextContainer(containerSize: NSSize(width: 0, height: CGFloat.greatestFiniteMagnitude))
        textContainer.widthTracksTextView = true
        textContainer.lineFragmentPadding = 0
        textContainer.lineBreakMode = .byCharWrapping
        layoutManager.addTextContainer(textContainer)

        textView = PlainPasteTextView(frame: .zero, textContainer: textContainer)
        textView.isRichText = true
        textView.allowsUndo = true
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.isAutomaticSpellingCorrectionEnabled = false
        textView.isAutomaticLinkDetectionEnabled = false
        textView.font = .preferredFont(forTextStyle: .title3)
        textView.textColor = .labelColor
        textView.backgroundColor = .clear
        textView.drawsBackground = false
        textView.textContainerInset = .zero
        textView.isVerticallyResizable = false
        textView.isHorizontallyResizable = false
        textView.setContentHuggingPriority(.defaultLow, for: .horizontal)
        textView.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        textView.typingAttributes = [
            .font: NSFont.preferredFont(forTextStyle: .title3),
            .foregroundColor: NSColor.labelColor,
        ]

        super.init(frame: frame)

        setContentHuggingPriority(.defaultLow, for: .horizontal)
        setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        textView.delegate = self

        textView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(textView)

        heightConstraint = heightAnchor.constraint(equalToConstant: 34)

        NSLayoutConstraint.activate([
            textView.topAnchor.constraint(equalTo: topAnchor),
            textView.leadingAnchor.constraint(equalTo: leadingAnchor),
            textView.trailingAnchor.constraint(equalTo: trailingAnchor),
            textView.bottomAnchor.constraint(equalTo: bottomAnchor),
            heightConstraint,
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    override func scrollWheel(with event: NSEvent) {
        nextResponder?.scrollWheel(with: event)
    }

    override func layout() {
        super.layout()

        if let textContainer = textView.textContainer {
            let containerWidth = max(0, bounds.width)
            if abs(textContainer.containerSize.width - containerWidth) > 1 {
                textContainer.containerSize = NSSize(width: containerWidth, height: CGFloat.greatestFiniteMagnitude)
            }
        }

        recalculateHeight()
    }

    func recalculateHeight() {
        guard let layoutManager = textView.layoutManager, let textContainer = textView.textContainer else { return }
        layoutManager.ensureLayout(for: textContainer)
        let usedRect = layoutManager.usedRect(for: textContainer)
        let newHeight = max(34, min(160, ceil(usedRect.height + 2)))

        guard abs(newHeight - lastKnownHeight) > 0.5 else { return }
        lastKnownHeight = newHeight
        heightConstraint.constant = newHeight
        textView.frame = NSRect(x: 0, y: 0, width: bounds.width, height: newHeight)
    }

    // MARK: - NSTextViewDelegate

    func textDidChange(_ notification: Notification) {
        recalculateHeight()
        onTextChanged?()
    }

    func textView(_ textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
        if commandSelector == #selector(NSResponder.insertNewline(_:)) {
            let event = NSApp.currentEvent
            let shiftPressed = event?.modifierFlags.contains(.shift) == true
            if shiftPressed {
                textView.insertNewlineIgnoringFieldEditor(nil)
                return true
            }
            onReturn?()
            return true
        }

        return false
    }
}

// MARK: - Send Button

private final class AgentSendButton: NSView {

    enum Mode { case send, stop }

    var action: () -> Void = {}

    var isEnabled: Bool = false {
        didSet { updateAppearance() }
    }

    var mode: Mode = .send {
        didSet { updateIcon() }
    }

    private let iconView: NSImageView
    private var trackingArea: NSTrackingArea?
    private var isHovering = false

    private static let sendConfig = NSImage.SymbolConfiguration(pointSize: 13, weight: .bold)
    private static let stopConfig = NSImage.SymbolConfiguration(pointSize: 11, weight: .bold)

    private static let primaryButtonColor = NSColor(name: nil) { appearance in
        if appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua {
            return NSColor(red: 0xE5 / 255.0, green: 0x7E / 255.0, blue: 0x52 / 255.0, alpha: 1.0)
        }
        return NSColor(red: 0xB9 / 255.0, green: 0x55 / 255.0, blue: 0x31 / 255.0, alpha: 1.0)
    }

    override init(frame: NSRect) {
        let image = NSImage(systemSymbolName: "arrow.up", accessibilityDescription: "Send")?.withSymbolConfiguration(Self.sendConfig)
        iconView = NSImageView(image: image ?? NSImage())

        super.init(frame: frame)

        wantsLayer = true

        iconView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(iconView)

        NSLayoutConstraint.activate([
            widthAnchor.constraint(equalToConstant: 30),
            heightAnchor.constraint(equalToConstant: 30),
            iconView.centerXAnchor.constraint(equalTo: centerXAnchor),
            iconView.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])

        updateAppearance()
    }

    private func updateIcon() {
        let (symbol, label, config) = switch mode {
        case .send: ("arrow.up", "Send", Self.sendConfig)
        case .stop: ("stop.fill", "Stop", Self.stopConfig)
        }
        iconView.image = NSImage(systemSymbolName: symbol, accessibilityDescription: label)?
            .withSymbolConfiguration(config) ?? NSImage()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    override func layout() {
        super.layout()
        layer?.cornerRadius = bounds.height / 2
    }

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
        refreshHoverState()
    }

    override func mouseEntered(with event: NSEvent) {
        if isEnabled || mode == .stop {
            isHovering = true
            updateAppearance()
        }
    }

    override func mouseExited(with event: NSEvent) {
        isHovering = false
        updateAppearance()
    }

    override func mouseDown(with event: NSEvent) {
        guard isEnabled || mode == .stop else { return }
        action()
    }

    private func refreshHoverState() {
        guard let window else {
            isHovering = false
            updateAppearance()
            return
        }
        let mouse = convert(window.mouseLocationOutsideOfEventStream, from: nil)
        let should = bounds.contains(mouse) && isEnabled
        guard should != isHovering else { return }
        isHovering = should
        updateAppearance()
    }

    func updateAppearance() {
        NSApp.effectiveAppearance.performAsCurrentDrawingAppearance {
            let isDark = NSAppearance.currentDrawing().isDarkMode
            let showActive = isEnabled || mode == .stop
            if showActive {
                layer?.backgroundColor = Self.primaryButtonColor.cgColor
                layer?.opacity = isHovering ? 0.8 : 1.0
                iconView.contentTintColor = NSColor.textBackgroundColor
            } else {
                layer?.backgroundColor = isDark
                    ? NSColor.white.withAlphaComponent(0.1).cgColor
                    : NSColor.black.withAlphaComponent(0.04).cgColor
                layer?.opacity = 1.0
                iconView.contentTintColor = .secondaryLabelColor
            }
        }
    }
}
