import AppKit

final class AgentChatInputView: NSView {

    var onSend: (String) -> Void = { _ in }
    var onStop: () -> Void = {}

    private let containerView: NSView
    private let inputTextView: AgentInputTextView
    private let sendButton: AgentSendButton
    private let placeholderLabel: NSTextField

    var text: String {
        get { inputTextView.textView.string }
        set {
            inputTextView.textView.string = newValue
            inputTextView.recalculateHeight()
            placeholderLabel.isHidden = !newValue.isEmpty
            if !isStreaming {
                sendButton.isEnabled = !newValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            }
        }
    }

    var isStreaming: Bool = false {
        didSet {
            sendButton.mode = isStreaming ? .stop : .send
            sendButton.isEnabled = isStreaming || !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
    }

    override init(frame: NSRect) {
        containerView = NSView()
        inputTextView = AgentInputTextView()
        sendButton = AgentSendButton()
        placeholderLabel = NSTextField(labelWithString: "Ask data question...")

        super.init(frame: frame)

        setupContainer()
        setupPlaceholder()
        setupInputTextView()
        setupSendButton()
        setupConstraints()

        inputTextView.onTextChanged = { [weak self] text in
            guard let self else { return }
            self.placeholderLabel.isHidden = !text.isEmpty
            if !self.isStreaming {
                self.sendButton.isEnabled = !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            }
        }

        let handleSend: () -> Void = { [weak self] in
            guard let self else { return }
            if self.isStreaming {
                self.onStop()
                return
            }
            let message = self.inputTextView.textView.string
            guard !message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
            self.onSend(message)
            self.text = ""
        }

        sendButton.action = handleSend
        inputTextView.onReturn = handleSend

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
        inputTextView.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(inputTextView)
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

            inputTextView.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 16),
            inputTextView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 16),
            inputTextView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -16),

            placeholderLabel.topAnchor.constraint(equalTo: inputTextView.topAnchor, constant: 0),
            placeholderLabel.leadingAnchor.constraint(equalTo: inputTextView.leadingAnchor),

            sendButton.topAnchor.constraint(equalTo: inputTextView.bottomAnchor, constant: 10),
            sendButton.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -10),
            sendButton.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -10),
        ])
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
    }
}

private final class AgentInputTextView: NSView, NSTextViewDelegate {

    let textView: NSTextView
    var onTextChanged: ((String) -> Void)?
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
        layoutManager.addTextContainer(textContainer)

        textView = NSTextView(frame: .zero, textContainer: textContainer)
        textView.isRichText = false
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

        super.init(frame: frame)

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
        onTextChanged?(textView.string)
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
