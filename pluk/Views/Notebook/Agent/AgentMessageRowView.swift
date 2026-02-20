import AppKit

final class AgentMessageRowView: NSView {

    private let role: AgentMessageRole
    private let label: NSTextField
    private var containerView: NSView?
    private var loadingView: TypingIndicatorView?

    private static let userBubbleColor = NSColor(name: nil) { appearance in
        if appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua {
            return NSColor(red: 0xE5 / 255.0, green: 0x7E / 255.0, blue: 0x52 / 255.0, alpha: 1.0)
        }
        return NSColor(red: 0xB9 / 255.0, green: 0x55 / 255.0, blue: 0x31 / 255.0, alpha: 1.0)
    }

    init(role: AgentMessageRole, content: String) {
        self.role = role
        self.label = NSTextField(wrappingLabelWithString: content)
        super.init(frame: .zero)
        setupLayout()

        if role == .assistant && content.isEmpty {
            showLoading()
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

    func update(content: String) {
        if !content.isEmpty {
            hideLoading()
        }
        label.stringValue = content
        invalidateIntrinsicContentSize()
        needsLayout = true
    }

    private func showLoading() {
        label.isHidden = true
        let indicator = TypingIndicatorView()
        indicator.translatesAutoresizingMaskIntoConstraints = false
        addSubview(indicator)
        NSLayoutConstraint.activate([
            indicator.leadingAnchor.constraint(equalTo: leadingAnchor),
            indicator.centerYAnchor.constraint(equalTo: centerYAnchor),
            indicator.heightAnchor.constraint(equalToConstant: 24),
        ])
        loadingView = indicator
        indicator.startAnimating()
    }

    private func hideLoading() {
        guard let indicator = loadingView else { return }
        indicator.stopAnimating()
        indicator.removeFromSuperview()
        loadingView = nil
        label.isHidden = false
    }

    private func setupLayout() {
        label.font = .systemFont(ofSize: NSFont.systemFontSize)
        label.isEditable = false
        label.isSelectable = true
        label.isBordered = false
        label.isBezeled = false
        label.drawsBackground = false
        label.lineBreakMode = .byWordWrapping
        label.maximumNumberOfLines = 0
        label.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        label.translatesAutoresizingMaskIntoConstraints = false

        switch role {
        case .user:
            label.textColor = .white

            let container = NSView()
            container.wantsLayer = true
            container.layer?.cornerRadius = 14
            container.translatesAutoresizingMaskIntoConstraints = false
            addSubview(container)
            container.addSubview(label)
            self.containerView = container
            updateUserBubbleColor()

            NSLayoutConstraint.activate([
                label.topAnchor.constraint(equalTo: container.topAnchor, constant: 8),
                label.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -8),
                label.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 12),
                label.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -12),

                container.topAnchor.constraint(equalTo: topAnchor),
                container.bottomAnchor.constraint(equalTo: bottomAnchor),
                container.trailingAnchor.constraint(equalTo: trailingAnchor),
                container.widthAnchor.constraint(lessThanOrEqualTo: widthAnchor, multiplier: 0.80),
            ])

        case .assistant:
            label.textColor = .labelColor
            addSubview(label)

            NSLayoutConstraint.activate([
                label.topAnchor.constraint(equalTo: topAnchor, constant: 4),
                label.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -4),
                label.leadingAnchor.constraint(equalTo: leadingAnchor),
                label.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor),
            ])
        }
    }

    private func updateUserBubbleColor() {
        guard role == .user else { return }
        NSApp.effectiveAppearance.performAsCurrentDrawingAppearance {
            containerView?.layer?.backgroundColor = Self.userBubbleColor.cgColor
        }
    }

    @objc private func handleAppearanceChange() {
        updateUserBubbleColor()
    }
}

// MARK: - Typing Indicator (animated dots)

private final class TypingIndicatorView: NSView {

    private let dots: [NSView] = (0..<3).map { _ in
        let dot = NSView()
        dot.wantsLayer = true
        dot.layer?.cornerRadius = 3.5
        dot.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            dot.widthAnchor.constraint(equalToConstant: 7),
            dot.heightAnchor.constraint(equalToConstant: 7),
        ])
        return dot
    }

    private var animationTimer: Timer?

    override init(frame: NSRect) {
        super.init(frame: frame)

        let stack = NSStackView(views: dots)
        stack.orientation = .horizontal
        stack.spacing = 4
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor),
            stack.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])

        updateDotColors()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    func startAnimating() {
        var tick = 0
        animationTimer = Timer.scheduledTimer(withTimeInterval: 0.4, repeats: true) { [weak self] _ in
            guard let self else { return }
            let activeDot = tick % 3
            for (i, dot) in self.dots.enumerated() {
                NSAnimationContext.runAnimationGroup { ctx in
                    ctx.duration = 0.3
                    dot.animator().alphaValue = i == activeDot ? 1.0 : 0.3
                }
            }
            tick += 1
        }
        animationTimer?.fire()
    }

    func stopAnimating() {
        animationTimer?.invalidate()
        animationTimer = nil
    }

    private func updateDotColors() {
        NSApp.effectiveAppearance.performAsCurrentDrawingAppearance {
            let color: NSColor = .secondaryLabelColor
            for dot in dots {
                dot.layer?.backgroundColor = color.cgColor
            }
        }
    }
}
