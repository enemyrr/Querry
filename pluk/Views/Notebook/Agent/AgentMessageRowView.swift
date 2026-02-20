import AppKit

final class AgentMessageRowView: NSView {

    private let role: AgentMessageRole
    private let textView: NSTextView
    private var containerView: NSView?
    private var loadingView: TypingIndicatorView?
    private var textViewHeightConstraint: NSLayoutConstraint?
    private var textViewWidthConstraint: NSLayoutConstraint?

    private static let userBubbleColor = NSColor(name: nil) { appearance in
        if appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua {
            return NSColor(red: 0xE5 / 255.0, green: 0x7E / 255.0, blue: 0x52 / 255.0, alpha: 1.0)
        }
        return NSColor(red: 0xB9 / 255.0, green: 0x55 / 255.0, blue: 0x31 / 255.0, alpha: 1.0)
    }

    private static let paragraphStyle: NSParagraphStyle = {
        let style = NSMutableParagraphStyle()
        style.lineSpacing = 4
        return style
    }()

    init(role: AgentMessageRole, content: String) {
        self.role = role
        self.textView = NSTextView()
        super.init(frame: .zero)
        setupLayout()
        applyAttributedContent(content)

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
        applyAttributedContent(content)
    }

    private func showLoading() {
        textView.isHidden = true
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
        textView.isHidden = false
    }

    private func applyAttributedContent(_ text: String) {
        let color: NSColor = role == .user ? .white : .labelColor
        let attributed = NSAttributedString(
            string: text,
            attributes: [
                .font: NSFont.systemFont(ofSize: NSFont.systemFontSize),
                .foregroundColor: color,
                .paragraphStyle: Self.paragraphStyle,
            ]
        )
        textView.textStorage?.setAttributedString(attributed)
        invalidateIntrinsicContentSize()
        recalculateTextSize()
    }

    private func recalculateTextSize() {
        guard let textStorage = textView.textStorage,
              let textContainer = textView.textContainer else { return }

        let maxWidth: CGFloat
        if role == .user {
            maxWidth = max(0, bounds.width * 0.80 - 24)
        } else {
            maxWidth = textContainer.size.width
        }

        let boundingRect = textStorage.boundingRect(
            with: NSSize(width: maxWidth, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading]
        )
        textViewHeightConstraint?.constant = ceil(boundingRect.height)
        textViewWidthConstraint?.constant = ceil(boundingRect.width)
    }

    private func setupLayout() {
        textView.isEditable = false
        textView.isSelectable = true
        textView.drawsBackground = false
        textView.isRichText = false
        textView.textContainerInset = .zero
        textView.textContainer?.lineFragmentPadding = 0
        textView.isVerticallyResizable = false
        textView.isHorizontallyResizable = false
        textView.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        textView.translatesAutoresizingMaskIntoConstraints = false

        let heightConstraint = textView.heightAnchor.constraint(equalToConstant: 0)
        heightConstraint.priority = .defaultHigh
        heightConstraint.isActive = true
        textViewHeightConstraint = heightConstraint

        switch role {
        case .user:
            let widthConstraint = textView.widthAnchor.constraint(equalToConstant: 0)
            widthConstraint.priority = .defaultHigh
            widthConstraint.isActive = true
            textViewWidthConstraint = widthConstraint
            let container = NSView()
            container.wantsLayer = true
            container.layer?.cornerRadius = 14
            container.translatesAutoresizingMaskIntoConstraints = false
            addSubview(container)
            container.addSubview(textView)
            self.containerView = container
            updateUserBubbleColor()

            NSLayoutConstraint.activate([
                textView.topAnchor.constraint(equalTo: container.topAnchor, constant: 8),
                textView.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -8),
                textView.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 12),
                textView.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -12),

                container.topAnchor.constraint(equalTo: topAnchor),
                container.bottomAnchor.constraint(equalTo: bottomAnchor),
                container.trailingAnchor.constraint(equalTo: trailingAnchor),
                container.widthAnchor.constraint(lessThanOrEqualTo: widthAnchor, multiplier: 0.80),
            ])

        case .assistant:
            addSubview(textView)

            NSLayoutConstraint.activate([
                textView.topAnchor.constraint(equalTo: topAnchor, constant: 4),
                textView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -4),
                textView.leadingAnchor.constraint(equalTo: leadingAnchor),
                textView.trailingAnchor.constraint(equalTo: trailingAnchor),
            ])
        }
    }

    override func layout() {
        super.layout()
        if role == .user {
            let maxTextWidth = bounds.width * 0.80 - 24
            textView.textContainer?.size.width = max(0, maxTextWidth)
        }
        recalculateTextSize()
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
