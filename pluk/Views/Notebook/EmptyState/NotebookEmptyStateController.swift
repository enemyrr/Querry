import AppKit

final class NotebookEmptyStateController: NSViewController {

    private let dataController: NotebookDataController
    private var chipsStackView: NSStackView?

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

        // Title
        let title = NSTextField(labelWithString: "What would you like to know?")
        title.font = .systemFont(ofSize: 22, weight: .semibold)
        title.textColor = .labelColor
        title.alignment = .center

        // Subtitle
        let subtitle = NSTextField(labelWithString: "Start by connecting a data source or adding a cell.")
        subtitle.font = .systemFont(ofSize: 13)
        subtitle.textColor = .secondaryLabelColor
        subtitle.alignment = .center

        let textStack = NSStackView(views: [title, subtitle])
        textStack.orientation = .vertical
        textStack.alignment = .centerX
        textStack.spacing = 12
        containerStack.addArrangedSubview(textStack)

        // Connection chips
        let chipsSection = makeConnectionChips()
        containerStack.addArrangedSubview(chipsSection)

        // Action bar
        let actionBar = NotebookActionBarView(dataController: dataController)
        actionBar.translatesAutoresizingMaskIntoConstraints = false
        containerStack.addArrangedSubview(actionBar)

        NSLayoutConstraint.activate([
            containerStack.centerXAnchor.constraint(equalTo: root.centerXAnchor),
            containerStack.centerYAnchor.constraint(equalTo: root.centerYAnchor, constant: -40),
            containerStack.widthAnchor.constraint(lessThanOrEqualToConstant: 520),
            containerStack.leadingAnchor.constraint(greaterThanOrEqualTo: root.leadingAnchor, constant: 24),
            containerStack.trailingAnchor.constraint(lessThanOrEqualTo: root.trailingAnchor, constant: -24),
        ])

        observeConnections()
    }

    // MARK: - Connection Chips

    private func makeConnectionChips() -> NSView {
        let wrapper = NSView()
        wrapper.translatesAutoresizingMaskIntoConstraints = false

        let header = NSTextField(labelWithString: "Connect your data")
        header.font = .systemFont(ofSize: 13, weight: .medium)
        header.textColor = .secondaryLabelColor
        header.translatesAutoresizingMaskIntoConstraints = false
        wrapper.addSubview(header)

        let scrollView = NSScrollView()
        scrollView.hasHorizontalScroller = false
        scrollView.hasVerticalScroller = false
        scrollView.drawsBackground = false
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        wrapper.addSubview(scrollView)

        let chipsStack = NSStackView()
        chipsStack.orientation = .horizontal
        chipsStack.spacing = 8
        chipsStack.translatesAutoresizingMaskIntoConstraints = false
        chipsStackView = chipsStack

        let documentView = NSView()
        documentView.translatesAutoresizingMaskIntoConstraints = false
        documentView.addSubview(chipsStack)
        scrollView.documentView = documentView

        NSLayoutConstraint.activate([
            chipsStack.topAnchor.constraint(equalTo: documentView.topAnchor),
            chipsStack.leadingAnchor.constraint(equalTo: documentView.leadingAnchor),
            chipsStack.trailingAnchor.constraint(equalTo: documentView.trailingAnchor),
            chipsStack.bottomAnchor.constraint(equalTo: documentView.bottomAnchor),
            documentView.heightAnchor.constraint(equalTo: scrollView.heightAnchor),

            header.topAnchor.constraint(equalTo: wrapper.topAnchor),
            header.leadingAnchor.constraint(equalTo: wrapper.leadingAnchor),

            scrollView.topAnchor.constraint(equalTo: header.bottomAnchor, constant: 8),
            scrollView.leadingAnchor.constraint(equalTo: wrapper.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: wrapper.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: wrapper.bottomAnchor),
            scrollView.heightAnchor.constraint(equalToConstant: 36),

            wrapper.widthAnchor.constraint(lessThanOrEqualToConstant: 480),
        ])

        rebuildChips()
        return wrapper
    }

    private func rebuildChips() {
        guard let stack = chipsStackView else { return }
        for view in stack.arrangedSubviews {
            stack.removeArrangedSubview(view)
            view.removeFromSuperview()
        }

        let connections = dataController.connections
        if connections.isEmpty {
            let empty = NSTextField(labelWithString: "No connections yet")
            empty.font = .systemFont(ofSize: 11)
            empty.textColor = .tertiaryLabelColor
            stack.addArrangedSubview(empty)
            return
        }

        for connection in connections {
            let chip = ConnectionChipView(name: connection.name, iconName: connection.databaseType.icon)
            chip.translatesAutoresizingMaskIntoConstraints = false
            stack.addArrangedSubview(chip)
        }
    }

    // MARK: - Observation

    private func observeConnections() {
        withObservationTracking {
            _ = self.dataController.connections
        } onChange: { [weak self] in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.rebuildChips()
                self.observeConnections()
            }
        }
    }
}

// MARK: - Connection Chip

private final class ConnectionChipView: NSView {

    private var trackingArea: NSTrackingArea?

    init(name: String, iconName: String) {
        super.init(frame: .zero)

        wantsLayer = true
        layer?.cornerRadius = 8
        updateBackground()

        let iconView = NSImageView()
        let icon = NSImage(named: iconName)
        icon?.size = NSSize(width: 16, height: 16)
        iconView.image = icon
        iconView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(iconView)

        let label = NSTextField(labelWithString: name)
        label.font = .systemFont(ofSize: 11)
        label.textColor = .labelColor
        label.lineBreakMode = .byTruncatingTail
        label.translatesAutoresizingMaskIntoConstraints = false
        addSubview(label)

        NSLayoutConstraint.activate([
            iconView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            iconView.centerYAnchor.constraint(equalTo: centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 16),
            iconView.heightAnchor.constraint(equalToConstant: 16),

            label.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: 6),
            label.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
            label.centerYAnchor.constraint(equalTo: centerYAnchor),

            heightAnchor.constraint(equalToConstant: 32),
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

    @objc private func handleAppearanceChange() {
        updateBackground()
    }

    private func updateBackground() {
        NSApp.effectiveAppearance.performAsCurrentDrawingAppearance {
            let isDark = NSAppearance.currentDrawing().isDarkMode
            layer?.backgroundColor = isDark
                ? NSColor.white.withAlphaComponent(0.06).cgColor
                : NSColor.black.withAlphaComponent(0.04).cgColor
        }
    }
}
