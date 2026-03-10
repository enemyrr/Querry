import AppKit

final class NotebookEmptyStateController: NSViewController, NSTextFieldDelegate {

    private let dataController: NotebookDataController
    private var inputField: NSTextField!
    private var sendButton: EmptyStateSendButton!
    private var inputContainer: NSView!

    private var selectedConnections: [Connection] = []
    private var pendingAtDetection = false
    private var inputRowView: NSView!
    private var actionBarView: NSView!
    private var connectionButton: EmptyStateConnectionButton!

    init(dataController: NotebookDataController) {
        self.dataController = dataController
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    override func loadView() {
        let root = NSView()
        root.wantsLayer = true
        self.view = root

        let containerStack = NSStackView()
        containerStack.orientation = .vertical
        containerStack.alignment = .centerX
        containerStack.spacing = 32
        containerStack.translatesAutoresizingMaskIntoConstraints = false
        root.addSubview(containerStack)

        let titleRow = NSStackView()
        titleRow.orientation = .horizontal
        titleRow.alignment = .lastBaseline
        titleRow.spacing = 8

        let title = NSTextField(labelWithString: "What would you like to build?")
        title.font = .systemFont(ofSize: 22, weight: .semibold)
        title.textColor = .labelColor

        let betaPill = NSView()
        betaPill.wantsLayer = true
        betaPill.layer?.cornerRadius = 4
        betaPill.layer?.cornerCurve = .continuous
        betaPill.layer?.borderWidth = 1
        betaPill.translatesAutoresizingMaskIntoConstraints = false
        NSApp.effectiveAppearance.performAsCurrentDrawingAppearance {
            let isDark = NSAppearance.currentDrawing().isDarkMode
            betaPill.layer?.backgroundColor = isDark
                ? NSColor.primaryButton.withAlphaComponent(0.12).cgColor
                : NSColor.primaryButton.withAlphaComponent(0.08).cgColor
            betaPill.layer?.borderColor = isDark
                ? NSColor.primaryButton.withAlphaComponent(0.25).cgColor
                : NSColor.primaryButton.withAlphaComponent(0.2).cgColor
        }

        let betaLabel = NSTextField(labelWithString: "BETA")
        betaLabel.font = .systemFont(ofSize: 9, weight: .bold)
        betaLabel.textColor = .primaryButton
        betaLabel.alignment = .center
        betaLabel.translatesAutoresizingMaskIntoConstraints = false
        betaPill.addSubview(betaLabel)

        NSLayoutConstraint.activate([
            betaLabel.leadingAnchor.constraint(equalTo: betaPill.leadingAnchor, constant: 4),
            betaLabel.trailingAnchor.constraint(equalTo: betaPill.trailingAnchor, constant: -4),
            betaLabel.topAnchor.constraint(equalTo: betaPill.topAnchor, constant: 4),
            betaLabel.bottomAnchor.constraint(equalTo: betaPill.bottomAnchor, constant: -4),
        ])

        titleRow.addArrangedSubview(title)
        titleRow.addArrangedSubview(betaPill)
        containerStack.addArrangedSubview(titleRow)

        let inputRow = makeInputRow()
        inputRowView = inputRow
        containerStack.addArrangedSubview(inputRow)

        let actionBar = NotebookActionBarView(dataController: dataController)
        actionBar.translatesAutoresizingMaskIntoConstraints = false
        actionBarView = actionBar
        containerStack.addArrangedSubview(actionBar)

        let fillWidth = containerStack.widthAnchor.constraint(equalTo: root.widthAnchor, constant: -48)
        fillWidth.priority = .defaultLow

        NSLayoutConstraint.activate([
            containerStack.centerXAnchor.constraint(equalTo: root.centerXAnchor),
            containerStack.centerYAnchor.constraint(equalTo: root.centerYAnchor, constant: -40),
            containerStack.widthAnchor.constraint(lessThanOrEqualToConstant: 600),
            containerStack.leadingAnchor.constraint(greaterThanOrEqualTo: root.leadingAnchor, constant: 24),
            containerStack.trailingAnchor.constraint(lessThanOrEqualTo: root.trailingAnchor, constant: -24),
            fillWidth,
        ])

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAppearanceChange),
            name: .appAppearanceDidChange,
            object: nil
        )
    }

    override func viewDidAppear() {
        super.viewDidAppear()
        view.window?.makeFirstResponder(inputField)
        selectFirstConnectionIfNeeded()
    }

    private func selectFirstConnectionIfNeeded() {
        guard selectedConnections.isEmpty,
              let first = dataController.connections.first else { return }
        selectedConnections = [first]
        updateConnectionButton()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: - Input Row

    private func makeInputRow() -> NSView {
        let container = NSView()
        container.wantsLayer = true
        container.layer?.cornerRadius = 18
        container.layer?.cornerCurve = .continuous
        container.shadow = {
            let s = NSShadow()
            s.shadowColor = NSColor.black.withAlphaComponent(0.08)
            s.shadowBlurRadius = 8
            s.shadowOffset = NSSize(width: 0, height: -2)
            return s
        }()
        container.translatesAutoresizingMaskIntoConstraints = false
        inputContainer = container
        updateContainerAppearance()

        inputField = NSTextField()
        inputField.placeholderString = "Ask a data question..."
        inputField.font = .systemFont(ofSize: 15)
        inputField.isBordered = false
        inputField.isBezeled = false
        inputField.drawsBackground = false
        inputField.focusRingType = .none
        inputField.lineBreakMode = .byTruncatingTail
        inputField.cell?.wraps = false
        inputField.cell?.isScrollable = true
        inputField.translatesAutoresizingMaskIntoConstraints = false
        inputField.delegate = self
        inputField.target = self
        inputField.action = #selector(handleSend)
        container.addSubview(inputField)

        let connButton = EmptyStateConnectionButton()
        connButton.translatesAutoresizingMaskIntoConstraints = false
        connButton.target = self
        connButton.action = #selector(connectionButtonTapped)
        container.addSubview(connButton)
        connectionButton = connButton

        let button = EmptyStateSendButton()
        button.translatesAutoresizingMaskIntoConstraints = false
        button.target = self
        button.action = #selector(handleSend)
        container.addSubview(button)
        sendButton = button

        NSLayoutConstraint.activate([
            container.heightAnchor.constraint(equalToConstant: 56),

            inputField.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 20),
            inputField.trailingAnchor.constraint(equalTo: connButton.leadingAnchor, constant: -8),
            inputField.centerYAnchor.constraint(equalTo: container.centerYAnchor),

            connButton.trailingAnchor.constraint(equalTo: button.leadingAnchor, constant: -4),
            connButton.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            connButton.heightAnchor.constraint(equalToConstant: 26),

            button.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -12),
            button.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            button.widthAnchor.constraint(equalToConstant: 32),
            button.heightAnchor.constraint(equalToConstant: 32),

            container.widthAnchor.constraint(greaterThanOrEqualToConstant: 360),
        ])

        return container
    }

    func controlTextDidChange(_ obj: Notification) {
        refreshSendButton()
        handleAtDetection()
    }

    private func refreshSendButton() {
        let hasText = !inputField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        sendButton.isActive = hasText || !selectedConnections.isEmpty
    }

    // MARK: - @ Connection Menu

    private func handleAtDetection() {
        guard !dataController.connections.isEmpty else { return }
        let text = inputField.stringValue
        guard let editor = inputField.currentEditor() else { return }

        let cursorLocation = editor.selectedRange.location
        guard cursorLocation > 0 else { return }

        let nsText = text as NSString
        let charBeforeCursor = nsText.substring(with: NSRange(location: cursorLocation - 1, length: 1))
        guard charBeforeCursor == "@" else { return }
        guard !pendingAtDetection else { return }
        pendingAtDetection = true
        showConnectionMenu(atRange: NSRange(location: cursorLocation - 1, length: 1))
    }

    private func showConnectionMenu(atRange: NSRange) {
        var text = inputField.stringValue
        let nsText = text as NSString
        if NSMaxRange(atRange) <= nsText.length,
           nsText.substring(with: atRange) == "@" {
            text = nsText.replacingCharacters(in: atRange, with: "")
            inputField.stringValue = text
        }
        pendingAtDetection = false

        showConnectionPicker(relativeTo: connectionButton)
    }

    @objc private func connectionButtonTapped() {
        guard !dataController.connections.isEmpty else { return }
        showConnectionPicker(relativeTo: connectionButton)
    }

    private func showConnectionPicker(relativeTo positioningView: NSView) {
        let menu = NSMenu()
        menu.autoenablesItems = false
        menu.font = .systemFont(ofSize: 13)

        for connection in dataController.connections {
            let isSelected = selectedConnections.contains(where: { $0.keychainId == connection.keychainId })
            let item = NSMenuItem()
            item.title = connection.name
            item.target = self
            item.action = #selector(connectionPickerItemClicked(_:))
            item.representedObject = connection.keychainId
            item.state = isSelected ? .on : .off
            if let icon = NSImage(named: connection.databaseType.icon)?.copy() as? NSImage {
                icon.size = NSSize(width: 16, height: 16)
                item.image = icon
            }
            menu.addItem(item)
        }

        inputContainer.layoutSubtreeIfNeeded()
        menu.update()

        let gap: CGFloat = 6
        let menuHeight = menu.size.height
        let menuPoint = NSPoint(
            x: positioningView.frame.minX,
            y: positioningView.frame.maxY + gap + menuHeight
        )

        _ = menu.popUp(positioning: nil, at: menuPoint, in: inputContainer)
        view.window?.makeFirstResponder(inputField)
    }

    @objc private func connectionPickerItemClicked(_ sender: NSMenuItem) {
        guard let keychainId = sender.representedObject as? String,
              let connection = dataController.connections.first(where: { $0.keychainId == keychainId }) else { return }

        if selectedConnections.first?.keychainId == keychainId {
            selectedConnections.removeAll()
        } else {
            selectedConnections = [connection]
        }

        updateConnectionButton()
        refreshSendButton()
    }

    @objc private func handleSend() {
        let text = inputField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        if !selectedConnections.isEmpty {
            dataController.pendingAgentConnections = selectedConnections
        }
        dataController.pendingAgentMessage = text
        dataController.isRightSidebarVisible = true

        inputRowView.isHidden = true

        inputField.stringValue = ""
        selectedConnections.removeAll()
        updateConnectionButton()
        sendButton.isActive = false
    }

    private func updateConnectionButton() {
        connectionButton.update(with: selectedConnections)
    }

    // MARK: - Appearance

    private func updateContainerAppearance() {
        NSApp.effectiveAppearance.performAsCurrentDrawingAppearance {
            let isDark = NSAppearance.currentDrawing().isDarkMode
            inputContainer.layer?.backgroundColor = isDark
                ? NSColor.white.withAlphaComponent(0.06).cgColor
                : NSColor.white.cgColor
            inputContainer.layer?.borderWidth = 1
            inputContainer.layer?.borderColor = isDark
                ? NSColor.white.withAlphaComponent(0.12).cgColor
                : NSColor.white.cgColor
        }
    }

    @objc private func handleAppearanceChange() {
        updateContainerAppearance()
    }
}

// MARK: - Send Button

private final class EmptyStateSendButton: NSControl {

    var isActive = false {
        didSet { updateAppearance() }
    }

    private let iconView: NSImageView
    private var trackingArea: NSTrackingArea?
    private var isHovering = false

    override init(frame: NSRect) {
        let image = NSImage(
            systemSymbolName: "arrow.up",
            accessibilityDescription: "Send"
        )?.withSymbolConfiguration(.init(pointSize: 14, weight: .bold))
        iconView = NSImageView(image: image ?? NSImage())

        super.init(frame: frame)
        wantsLayer = true
        layer?.cornerRadius = 16

        iconView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(iconView)

        NSLayoutConstraint.activate([
            iconView.centerXAnchor.constraint(equalTo: centerXAnchor),
            iconView.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])

        updateAppearance()

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
        updateAppearance()
    }

    override func mouseExited(with event: NSEvent) {
        isHovering = false
        updateAppearance()
    }

    override func mouseDown(with event: NSEvent) {
        sendAction(action, to: target)
    }

    private func refreshHoverState() {
        guard let window else {
            isHovering = false
            updateAppearance()
            return
        }
        let mouse = convert(window.mouseLocationOutsideOfEventStream, from: nil)
        let should = bounds.contains(mouse)
        guard should != isHovering else { return }
        isHovering = should
        updateAppearance()
    }

    private func updateAppearance() {
        NSApp.effectiveAppearance.performAsCurrentDrawingAppearance {
            let isDark = NSAppearance.currentDrawing().isDarkMode
            if isActive {
                layer?.backgroundColor = NSColor.primaryButton.cgColor
                layer?.opacity = isHovering ? 0.8 : 1.0
                iconView.contentTintColor = .white
            } else {
                layer?.backgroundColor = isDark
                    ? NSColor.white.withAlphaComponent(isHovering ? 0.15 : 0.10).cgColor
                    : NSColor.black.withAlphaComponent(isHovering ? 0.10 : 0.06).cgColor
                layer?.opacity = 1.0
                iconView.contentTintColor = isDark
                    ? .white.withAlphaComponent(0.5)
                    : .black.withAlphaComponent(0.3)
            }
        }
    }

    @objc private func handleAppearanceChange() {
        updateAppearance()
    }
}

// MARK: - Connection Button

private final class EmptyStateConnectionButton: NSControl {

    private static let iconSize: CGFloat = 26
    private static let overlap: CGFloat = 8

    private let emptyLabel: NSTextField
    private let singleIconView: NSImageView
    private let singleNameLabel: NSTextField
    private let iconContainer: NSView
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

        iconContainer = NSView()
        iconContainer.translatesAutoresizingMaskIntoConstraints = false
        iconContainer.isHidden = true

        super.init(frame: frame)

        wantsLayer = true

        addSubview(emptyLabel)
        addSubview(singleIconView)
        addSubview(singleNameLabel)
        addSubview(iconContainer)

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

            iconContainer.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 3),
            iconContainer.centerYAnchor.constraint(equalTo: centerYAnchor),
            iconContainer.heightAnchor.constraint(equalToConstant: Self.iconSize),
        ])

        updateAppearance()

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

    private var iconContainerWidthConstraint: NSLayoutConstraint?

    func update(with connections: [Connection]) {
        hasConnections = !connections.isEmpty
        iconContainer.subviews.forEach { $0.removeFromSuperview() }
        iconContainerWidthConstraint?.isActive = false
        iconContainerWidthConstraint = nil

        // Empty state
        guard !connections.isEmpty else {
            emptyLabel.isHidden = false
            singleIconView.isHidden = true
            singleNameLabel.isHidden = true
            iconContainer.isHidden = true
            widthConstraint.constant = 6 + emptyLabelWidth
            updateAppearance()
            return
        }

        emptyLabel.isHidden = true

        // Single connection — show icon + name
        if connections.count == 1, let conn = connections.first {
            singleIconView.isHidden = false
            singleNameLabel.isHidden = false
            iconContainer.isHidden = true

            singleIconView.image = NSImage(named: conn.databaseType.icon)
            singleNameLabel.stringValue = conn.name
            singleNameLabel.textColor = .labelColor

            let nameWidth = min(singleNameLabel.fittingSize.width, 120)
            widthConstraint.constant = 4 + 14 + 4 + nameWidth + 4
            updateAppearance()
            return
        }

        // Multiple connections — overlapping icon circles
        singleIconView.isHidden = true
        singleNameLabel.isHidden = true
        iconContainer.isHidden = false

        let iconSize = Self.iconSize
        let step = iconSize - Self.overlap

        for (index, conn) in connections.enumerated() {
            let circle = NSView()
            circle.wantsLayer = true
            circle.layer?.cornerRadius = iconSize / 2
            circle.layer?.masksToBounds = true
            circle.layer?.borderWidth = 1.5
            NSApp.effectiveAppearance.performAsCurrentDrawingAppearance {
                let isDark = NSAppearance.currentDrawing().isDarkMode
                circle.layer?.borderColor = isDark
                    ? NSColor(white: 0.15, alpha: 1).cgColor
                    : NSColor.white.cgColor
                circle.layer?.backgroundColor = isDark
                    ? NSColor(white: 0.2, alpha: 1).cgColor
                    : NSColor(white: 0.95, alpha: 1).cgColor
            }
            circle.translatesAutoresizingMaskIntoConstraints = false

            let imgView = NSImageView()
            imgView.image = NSImage(named: conn.databaseType.icon)
            imgView.imageAlignment = .alignCenter
            imgView.imageScaling = .scaleProportionallyDown
            imgView.translatesAutoresizingMaskIntoConstraints = false
            circle.addSubview(imgView)

            iconContainer.addSubview(circle)

            NSLayoutConstraint.activate([
                circle.leadingAnchor.constraint(equalTo: iconContainer.leadingAnchor, constant: CGFloat(index) * step),
                circle.centerYAnchor.constraint(equalTo: iconContainer.centerYAnchor),
                circle.widthAnchor.constraint(equalToConstant: iconSize),
                circle.heightAnchor.constraint(equalToConstant: iconSize),

                imgView.centerXAnchor.constraint(equalTo: circle.centerXAnchor),
                imgView.centerYAnchor.constraint(equalTo: circle.centerYAnchor),
            ])
        }

        let iconsWidth = iconSize + CGFloat(connections.count - 1) * step
        let wc = iconContainer.widthAnchor.constraint(equalToConstant: iconsWidth)
        wc.isActive = true
        iconContainerWidthConstraint = wc

        widthConstraint.constant = 3 + iconsWidth + 3

        updateAppearance()
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
        updateAppearance()
    }

    override func mouseExited(with event: NSEvent) {
        isHovering = false
        updateAppearance()
    }

    override func mouseDown(with event: NSEvent) {
        sendAction(action, to: target)
    }

    private func refreshHoverState() {
        guard let window else {
            isHovering = false
            updateAppearance()
            return
        }
        let mouse = convert(window.mouseLocationOutsideOfEventStream, from: nil)
        let should = bounds.contains(mouse)
        guard should != isHovering else { return }
        isHovering = should
        updateAppearance()
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

    private func updateAppearance() {
        needsDisplay = true
    }

    @objc private func handleAppearanceChange() {
        updateAppearance()
    }
}
