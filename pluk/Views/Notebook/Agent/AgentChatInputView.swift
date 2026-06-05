import AppKit

final class AgentChatInputView: NSView {

    var onSend: (String) -> Void = { _ in }
    var onStop: () -> Void = {}
    var onConnectionsChanged: (([Connection]) -> Void)?

    private let containerView: NSView
    private let inputTextView: AgentInputTextView
    private let sendButton: AgentSendButton
    private let connectionButton: AgentChatConnectionButton
    private let placeholderLabel: NSTextField
    private let statusLabel: NSTextField

    private var availableConnections: [Connection]
    private var selectedConnections: [Connection] = []
    private var pendingAtRange: NSRange?
    private var suppressNextReturnSend = false
    private var isConnectionMenuOpen = false

    var userMessage: String {
        inputTextView.textView.string
    }

    var text: String {
        get { userMessage }
        set {
            inputTextView.textView.string = newValue
            inputTextView.recalculateHeight()
            placeholderLabel.isHidden = !newValue.isEmpty
            updateSendButtonState()
        }
    }

    var isStreaming: Bool = false {
        didSet {
            updateSendButtonState()
        }
    }

    init(connections: [Connection] = []) {
        self.availableConnections = connections
        containerView = NSView()
        inputTextView = AgentInputTextView()
        sendButton = AgentSendButton()
        connectionButton = AgentChatConnectionButton()
        placeholderLabel = NSTextField(labelWithString: "Ask data question...")
        statusLabel = NSTextField(labelWithString: "")

        super.init(frame: .zero)

        setupContainer()
        setupPlaceholder()
        setupInputTextView()
        setupStatusLabel()
        setupConnectionButton()
        setupSendButton()
        setupConstraints()

        inputTextView.onTextChanged = { [weak self] in
            guard let self else { return }
            let msg = self.userMessage
            self.placeholderLabel.isHidden = !msg.isEmpty
            self.updateSendButtonState()
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

    func setSelectedConnections(_ connections: [Connection]) {
        selectedConnections = connections
        connectionButton.update(with: selectedConnections)
        onConnectionsChanged?(selectedConnections)
    }

    func updateAvailableConnections(_ connections: [Connection]) {
        availableConnections = connections

        let availableKeychainIds = Set(connections.map(\.keychainId))
        selectedConnections.removeAll { !availableKeychainIds.contains($0.keychainId) }

        if selectedConnections.isEmpty, let first = connections.first {
            selectedConnections = [first]
        }

        connectionButton.update(with: selectedConnections)
        onConnectionsChanged?(selectedConnections)
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
        containerView.shadow = {
            let s = NSShadow()
            s.shadowColor = NSColor.black.withAlphaComponent(0.10)
            s.shadowBlurRadius = 1
            s.shadowOffset = .zero
            return s
        }()
        containerView.setContentHuggingPriority(.defaultLow, for: .horizontal)
        containerView.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        containerView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(containerView)
        updateContainerAppearance()
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

    private func setupConnectionButton() {
        connectionButton.translatesAutoresizingMaskIntoConstraints = false
        connectionButton.target = self
        connectionButton.action = #selector(connectionButtonTapped)
        containerView.addSubview(connectionButton)
    }

    private func setupSendButton() {
        sendButton.isEnabled = false
        sendButton.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(sendButton)
    }

    private func setupConstraints() {
        NSLayoutConstraint.activate([
            containerView.topAnchor.constraint(equalTo: topAnchor),
            containerView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 4),
            containerView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -4),
            containerView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -4),

            inputTextView.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 14),
            inputTextView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 14),
            inputTextView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -14),

            placeholderLabel.topAnchor.constraint(equalTo: inputTextView.topAnchor),
            placeholderLabel.leadingAnchor.constraint(equalTo: inputTextView.leadingAnchor),

            connectionButton.trailingAnchor.constraint(equalTo: sendButton.leadingAnchor, constant: -4),
            connectionButton.centerYAnchor.constraint(equalTo: sendButton.centerYAnchor),
            connectionButton.heightAnchor.constraint(equalToConstant: 26),

            sendButton.topAnchor.constraint(equalTo: inputTextView.bottomAnchor, constant: 10),
            sendButton.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -8),
            sendButton.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -8),

            statusLabel.centerYAnchor.constraint(equalTo: sendButton.centerYAnchor),
            statusLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 16),
            statusLabel.trailingAnchor.constraint(lessThanOrEqualTo: connectionButton.leadingAnchor, constant: -8),
        ])
    }

    // MARK: - Connection Selection

    @objc private func connectionButtonTapped() {
        guard !availableConnections.isEmpty else { return }
        showConnectionPicker(relativeTo: connectionButton)
    }

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

        let tv2 = inputTextView.textView
        let nsText2 = tv2.string as NSString
        if NSMaxRange(atRange) <= nsText2.length,
           nsText2.substring(with: atRange) == "@" {
            tv2.textStorage?.replaceCharacters(in: atRange, with: "")
            tv2.setSelectedRange(NSRange(location: atRange.location, length: 0))
        }

        showConnectionPicker(relativeTo: connectionButton)
    }

    private func showConnectionPicker(relativeTo positioningView: NSView) {
        let menu = NSMenu()
        menu.autoenablesItems = false
        menu.font = .systemFont(ofSize: 13)

        for connection in availableConnections {
            let isSelected = selectedConnections.contains(where: { $0.keychainId == connection.keychainId })
            let item = NSMenuItem(title: connection.name, action: #selector(connectionPickerItemClicked(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = connection.keychainId
            item.state = isSelected ? .on : .off
            if let icon = NSImage(named: connection.databaseType.icon)?.copy() as? NSImage {
                icon.size = NSSize(width: 16, height: 16)
                item.image = icon
            }
            menu.addItem(item)
        }

        containerView.layoutSubtreeIfNeeded()
        menu.update()

        let gap: CGFloat = 6
        let menuHeight = menu.size.height
        let menuPoint = NSPoint(
            x: positioningView.frame.minX,
            y: positioningView.frame.maxY + gap + menuHeight
        )

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

    @objc private func connectionPickerItemClicked(_ sender: NSMenuItem) {
        guard let keychainId = sender.representedObject as? String,
              let connection = availableConnections.first(where: { $0.keychainId == keychainId }) else { return }

        if selectedConnections.first?.keychainId == keychainId {
            selectedConnections.removeAll()
        } else {
            selectedConnections = [connection]
        }

        connectionButton.update(with: selectedConnections)
        onConnectionsChanged?(selectedConnections)
    }

    // MARK: - Appearance

    private func updateContainerAppearance() {
        NSApp.effectiveAppearance.performAsCurrentDrawingAppearance {
            let isDark = NSAppearance.currentDrawing().isDarkMode
            containerView.layer?.backgroundColor = isDark
                ? NSColor.black.withAlphaComponent(0.25).cgColor
                : NSColor.white.cgColor
        }
    }

    @objc private func handleAppearanceChange() {
        updateContainerAppearance()
        sendButton.updateAppearance()
    }

    private func updateSendButtonState() {
        sendButton.mode = isStreaming ? .stop : .send
        if isStreaming {
            sendButton.isEnabled = true
            return
        }
        let hasMessage = !userMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        sendButton.isEnabled = hasMessage
    }
}

// MARK: - Connection Button

private final class AgentChatConnectionButton: NSControl {

    private let emptyLabel: NSTextField
    private let singleIconView: NSImageView
    private let singleNameLabel: NSTextField
    private var widthConstraint: NSLayoutConstraint!
    private var emptyLabelWidth: CGFloat = 0
    private var trackingArea: NSTrackingArea?
    private var isHovering = false
    private var hasConnections = false

    override init(frame: NSRect) {
        emptyLabel = NSTextField(labelWithString: "Connection")
        emptyLabel.font = .systemFont(ofSize: 13)
        emptyLabel.textColor = .tertiaryLabelColor
        emptyLabel.translatesAutoresizingMaskIntoConstraints = false

        singleIconView = NSImageView()
        singleIconView.imageAlignment = .alignCenter
        singleIconView.imageScaling = .scaleProportionallyDown
        singleIconView.translatesAutoresizingMaskIntoConstraints = false
        singleIconView.isHidden = true

        singleNameLabel = NSTextField(labelWithString: "")
        singleNameLabel.font = .systemFont(ofSize: 13)
        singleNameLabel.lineBreakMode = .byTruncatingTail
        singleNameLabel.maximumNumberOfLines = 1
        singleNameLabel.translatesAutoresizingMaskIntoConstraints = false
        singleNameLabel.isHidden = true

        super.init(frame: frame)

        wantsLayer = true

        addSubview(emptyLabel)
        addSubview(singleIconView)
        addSubview(singleNameLabel)

        emptyLabelWidth = emptyLabel.fittingSize.width
        widthConstraint = widthAnchor.constraint(equalToConstant: 6 + emptyLabelWidth)
        setContentCompressionResistancePriority(.required, for: .horizontal)

        NSLayoutConstraint.activate([
            widthConstraint,

            emptyLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 6),
            emptyLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
            emptyLabel.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor),

            singleIconView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 4),
            singleIconView.centerYAnchor.constraint(equalTo: centerYAnchor),
            singleIconView.widthAnchor.constraint(equalToConstant: 14),
            singleIconView.heightAnchor.constraint(equalToConstant: 14),

            singleNameLabel.leadingAnchor.constraint(equalTo: singleIconView.trailingAnchor, constant: 4),
            singleNameLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
            singleNameLabel.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -4),
        ])

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

    func update(with connections: [Connection]) {
        hasConnections = !connections.isEmpty

        guard let conn = connections.first else {
            emptyLabel.isHidden = false
            singleIconView.isHidden = true
            singleNameLabel.isHidden = true
            widthConstraint.constant = 6 + emptyLabelWidth
            needsDisplay = true
            return
        }

        emptyLabel.isHidden = true
        singleIconView.isHidden = false
        singleNameLabel.isHidden = false

        singleIconView.image = NSImage(named: conn.databaseType.icon)
        singleNameLabel.stringValue = conn.name
        singleNameLabel.textColor = .labelColor

        let nameWidth = min(singleNameLabel.fittingSize.width, 120)
        widthConstraint.constant = 4 + 14 + 4 + nameWidth + 4
        needsDisplay = true
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
        isHovering = true
        needsDisplay = true
    }

    override func mouseExited(with event: NSEvent) {
        isHovering = false
        needsDisplay = true
    }

    override func mouseDown(with event: NSEvent) {
        sendAction(action, to: target)
    }

    private func refreshHoverState() {
        guard let window else {
            isHovering = false
            needsDisplay = true
            return
        }
        let mouse = convert(window.mouseLocationOutsideOfEventStream, from: nil)
        let should = bounds.contains(mouse)
        guard should != isHovering else { return }
        isHovering = should
        needsDisplay = true
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        if isHovering {
            let isDark = NSApp.effectiveAppearance.isDarkMode
            let color: NSColor = isDark
                ? .white.withAlphaComponent(0.08)
                : .black.withAlphaComponent(0.05)
            color.setFill()
            NSBezierPath(roundedRect: bounds, xRadius: 6, yRadius: 6).fill()
        }
    }

    @objc private func handleAppearanceChange() {
        needsDisplay = true
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
        textView.font = .systemFont(ofSize: 14)
        textView.textColor = .labelColor
        textView.backgroundColor = .clear
        textView.drawsBackground = false
        textView.textContainerInset = .zero
        textView.isVerticallyResizable = false
        textView.isHorizontallyResizable = false
        textView.setContentHuggingPriority(.defaultLow, for: .horizontal)
        textView.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        textView.typingAttributes = [
            .font: NSFont.systemFont(ofSize: 14),
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
