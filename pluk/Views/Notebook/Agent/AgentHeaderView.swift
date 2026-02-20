import AppKit

final class AgentHeaderView: NSView {

    var onNewChat: () -> Void = {}
    var onCompose: () -> Void = {}
    var onClose: () -> Void = {}

    private let newChatButton: AgentHeaderTextButton
    private let composeButton: AgentHeaderIconButton
    private let closeButton: AgentHeaderIconButton

    override init(frame: NSRect) {
        newChatButton = AgentHeaderTextButton(label: "New AI Chat")
        composeButton = AgentHeaderIconButton(symbolName: "square.and.pencil", pointSize: 13, weight: .medium, yOffset: -1)
        closeButton = AgentHeaderIconButton(symbolName: "xmark", pointSize: 11, weight: .medium)

        super.init(frame: frame)

        newChatButton.action = { [weak self] in self?.onNewChat() }
        composeButton.action = { [weak self] in self?.onCompose() }
        closeButton.action = { [weak self] in self?.onClose() }

        setupLayout()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    var dropdownButtonBounds: NSRect {
        newChatButton.frame
    }

    func updateTitle(_ text: String) {
        newChatButton.updateLabel(text)
    }

    private func setupLayout() {
        translatesAutoresizingMaskIntoConstraints = false

        let rightStack = NSStackView(views: [composeButton, closeButton])
        rightStack.orientation = .horizontal
        rightStack.spacing = 4

        newChatButton.translatesAutoresizingMaskIntoConstraints = false
        rightStack.translatesAutoresizingMaskIntoConstraints = false

        addSubview(newChatButton)
        addSubview(rightStack)

        NSLayoutConstraint.activate([
            newChatButton.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 4),
            newChatButton.centerYAnchor.constraint(equalTo: centerYAnchor),

            rightStack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -10),
            rightStack.centerYAnchor.constraint(equalTo: centerYAnchor),

            heightAnchor.constraint(equalToConstant: 12 + 26 + 10),
        ])
    }
}

// MARK: - Icon Button

private final class AgentHeaderIconButton: NSView {

    var action: () -> Void = {}

    private let iconView: NSImageView
    private var trackingArea: NSTrackingArea?
    private var isHovering = false

    init(symbolName: String, pointSize: CGFloat, weight: NSFont.Weight, yOffset: CGFloat = 0) {
        let config = NSImage.SymbolConfiguration(pointSize: pointSize, weight: weight)
        let image = NSImage(systemSymbolName: symbolName, accessibilityDescription: nil)?.withSymbolConfiguration(config)

        iconView = NSImageView(image: image ?? NSImage())
        iconView.contentTintColor = .secondaryLabelColor

        super.init(frame: .zero)

        wantsLayer = true
        layer?.cornerRadius = 6

        iconView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(iconView)

        NSLayoutConstraint.activate([
            widthAnchor.constraint(equalToConstant: 26),
            heightAnchor.constraint(equalToConstant: 26),
            iconView.centerXAnchor.constraint(equalTo: centerXAnchor),
            iconView.centerYAnchor.constraint(equalTo: centerYAnchor, constant: yOffset),
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
        applyIconHover(true)
    }

    override func mouseExited(with event: NSEvent) {
        isHovering = false
        applyIconHover(false)
    }

    override func mouseDown(with event: NSEvent) {
        action()
    }

    private func refreshHoverState() {
        guard let window else {
            isHovering = false
            applyIconHover(false)
            return
        }
        let mouse = convert(window.mouseLocationOutsideOfEventStream, from: nil)
        let should = bounds.contains(mouse)
        guard should != isHovering else { return }
        isHovering = should
        applyIconHover(isHovering)
    }

    private func applyIconHover(_ on: Bool) {
        guard let layer else { return }
        if on {
            let isDark = NSApp.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            layer.backgroundColor = isDark
                ? NSColor.white.withAlphaComponent(0.08).cgColor
                : NSColor.black.withAlphaComponent(0.06).cgColor
        } else {
            layer.backgroundColor = nil
        }
    }

    @objc private func handleAppearanceChange() {
        applyIconHover(isHovering)
    }
}

// MARK: - Text Dropdown Button

fileprivate final class AgentHeaderTextButton: NSView {

    var action: () -> Void = {}

    private let label: NSTextField
    private let chevron: NSImageView
    private var trackingArea: NSTrackingArea?
    private var isHovering = false

    init(label text: String) {
        label = NSTextField(labelWithString: text)
        label.font = .systemFont(ofSize: NSFont.systemFontSize, weight: .medium)
        label.textColor = .secondaryLabelColor

        let config = NSImage.SymbolConfiguration(pointSize: 9, weight: .semibold)
        let image = NSImage(systemSymbolName: "chevron.down", accessibilityDescription: nil)?.withSymbolConfiguration(config)
        chevron = NSImageView(image: image ?? NSImage())
        chevron.contentTintColor = .secondaryLabelColor

        super.init(frame: .zero)

        wantsLayer = true
        layer?.cornerRadius = 6

        let stack = NSStackView(views: [label, chevron])
        stack.orientation = .horizontal
        stack.spacing = 4
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: topAnchor, constant: 4),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -4),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 6),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -6),
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
        applyHoverBackground(true)
    }

    override func mouseExited(with event: NSEvent) {
        isHovering = false
        applyHoverBackground(false)
    }

    override func mouseDown(with event: NSEvent) {
        action()
    }

    private func refreshHoverState() {
        guard let window else {
            isHovering = false
            applyHoverBackground(false)
            return
        }
        let mouse = convert(window.mouseLocationOutsideOfEventStream, from: nil)
        let should = bounds.contains(mouse)
        guard should != isHovering else { return }
        isHovering = should
        applyHoverBackground(isHovering)
    }

    @objc private func handleAppearanceChange() {
        applyHoverBackground(isHovering)
    }

    func updateLabel(_ text: String) {
        label.stringValue = text
    }
}
