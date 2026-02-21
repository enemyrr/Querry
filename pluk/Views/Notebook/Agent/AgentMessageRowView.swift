import AppKit

final class AgentMessageRowView: NSView {

    var onRetry: (() -> Void)?
    var onFeedbackChanged: ((AgentMessageFeedback?) -> Void)?

    private let role: AgentMessageRole
    private let textView: NSTextView
    private var containerView: NSView?
    private var thinkingView: ThinkingStatusView?
    private var textViewHeightConstraint: NSLayoutConstraint?
    private var textViewWidthConstraint: NSLayoutConstraint?
    private var markdownContentView: MarkdownContentView?

    private var userActionBar: UserMessageActionBar?
    private var assistantActionBar: AssistantMessageActionBar?
    private var containerBottomConstraint: NSLayoutConstraint?
    private var mdBottomConstraint: NSLayoutConstraint?

    private var trackingArea: NSTrackingArea?
    private var isHovering = false
    private var isStreamingRow = false
    private var actionBarAlwaysVisible = false

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

    init(role: AgentMessageRole, content: String, createdAt: Date = Date(), feedback: AgentMessageFeedback? = nil, isStreaming: Bool = false) {
        self.role = role
        self.isStreamingRow = isStreaming
        self.textView = NSTextView()
        super.init(frame: .zero)
        wantsLayer = true
        setupLayout()

        if role == .assistant, let mdView = markdownContentView {
            if !content.isEmpty {
                mdView.update(content: content)
            }
        } else {
            applyAttributedContent(content)
        }

        if role == .assistant && content.isEmpty {
            showLoading()
        }

        if !isStreaming {
            setupActionBar(createdAt: createdAt, feedback: feedback)
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
        if role == .assistant, let mdView = markdownContentView {
            mdView.update(content: content)
        } else {
            applyAttributedContent(content)
        }
        invalidateIntrinsicContentSize()
        needsLayout = true
    }

    func markFinalized(createdAt: Date, feedback: AgentMessageFeedback?) {
        isStreamingRow = false
        setupActionBar(createdAt: createdAt, feedback: feedback)
    }

    func updateFeedback(_ feedback: AgentMessageFeedback?) {
        assistantActionBar?.setFeedback(feedback)
    }

    func setActionBarAlwaysVisible(_ visible: Bool) {
        actionBarAlwaysVisible = visible
        let bar: NSView? = role == .user ? userActionBar : assistantActionBar
        guard let bar else { return }
        if visible {
            bar.alphaValue = 1
        } else if !isHovering {
            bar.alphaValue = 0
        }
    }

    // MARK: - Action Bar

    private func setupActionBar(createdAt: Date, feedback: AgentMessageFeedback?) {
        switch role {
        case .user:
            let bar = UserMessageActionBar(timestamp: createdAt)
            bar.translatesAutoresizingMaskIntoConstraints = false
            bar.alphaValue = 0
            bar.onCopy = { [weak self] in
                guard let self else { return }
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(textView.string, forType: .string)
            }
            addSubview(bar)

            containerBottomConstraint?.constant = -(24 + 4)

            NSLayoutConstraint.activate([
                bar.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -6),
                bar.bottomAnchor.constraint(equalTo: bottomAnchor),
            ])

            userActionBar = bar

        case .assistant:
            let bar = AssistantMessageActionBar()
            bar.translatesAutoresizingMaskIntoConstraints = false
            bar.alphaValue = actionBarAlwaysVisible ? 1 : 0
            bar.setFeedback(feedback)
            bar.onThumbsUp = { [weak self] in
                guard let self else { return }
                self.onFeedbackChanged?(bar.resolvedFeedback)
            }
            bar.onThumbsDown = { [weak self] in
                guard let self else { return }
                self.onFeedbackChanged?(bar.resolvedFeedback)
            }
            bar.onCopyText = { [weak self] in
                guard let self, let mdView = self.markdownContentView else { return }
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(mdView.plainText, forType: .string)
            }
            bar.onRetry = { [weak self] in self?.onRetry?() }
            addSubview(bar)

            mdBottomConstraint?.constant = -(4 + 24 + 4)

            NSLayoutConstraint.activate([
                bar.leadingAnchor.constraint(equalTo: leadingAnchor),
                bar.bottomAnchor.constraint(equalTo: bottomAnchor),
            ])

            assistantActionBar = bar
        }
        updateTrackingAreas()
        refreshHoverState()
    }

    // MARK: - Hover

    private var actionBar: NSView? {
        role == .user ? userActionBar : assistantActionBar
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        guard actionBar != nil else { return }
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
        guard !isStreamingRow, !actionBarAlwaysVisible else { return }
        isHovering = true
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.15
            actionBar?.animator().alphaValue = 1
        }
    }

    override func mouseExited(with event: NSEvent) {
        guard !actionBarAlwaysVisible else { return }
        isHovering = false
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.15
            actionBar?.animator().alphaValue = 0
        }
    }

    private func refreshHoverState() {
        guard let window else {
            if !actionBarAlwaysVisible { actionBar?.alphaValue = 0 }
            return
        }
        guard !actionBarAlwaysVisible else {
            actionBar?.alphaValue = 1
            return
        }
        let mouse = convert(window.mouseLocationOutsideOfEventStream, from: nil)
        let should = bounds.contains(mouse) && !isStreamingRow
        guard should != isHovering else { return }
        isHovering = should
        actionBar?.alphaValue = isHovering ? 1 : 0
    }

    // MARK: - Loading

    private var primaryContentView: NSView {
        (role == .assistant ? markdownContentView : nil) ?? textView
    }

    private func showLoading() {
        primaryContentView.isHidden = true
        let thinking = ThinkingStatusView()
        thinking.translatesAutoresizingMaskIntoConstraints = false
        addSubview(thinking)
        NSLayoutConstraint.activate([
            thinking.leadingAnchor.constraint(equalTo: leadingAnchor),
            thinking.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor),
            thinking.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])
        thinkingView = thinking
    }

    private func hideLoading() {
        guard let thinking = thinkingView else { return }
        thinking.removeFromSuperview()
        thinkingView = nil
        primaryContentView.isHidden = false
    }

    func updateToolStatus(_ status: String?) {
        thinkingView?.updateToolStatus(status)
    }

    // MARK: - Content

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
        guard let layoutManager = textView.layoutManager,
              let textContainer = textView.textContainer else { return }

        let maxWidth: CGFloat
        if role == .user {
            maxWidth = max(0, bounds.width * 0.80 - 24)
        } else {
            maxWidth = textContainer.size.width
        }

        textContainer.containerSize = NSSize(width: maxWidth, height: .greatestFiniteMagnitude)
        layoutManager.ensureLayout(for: textContainer)
        let usedRect = layoutManager.usedRect(for: textContainer)
        textViewHeightConstraint?.constant = max(1, ceil(usedRect.height))
        let clampedWidth = min(maxWidth, ceil(usedRect.width))
        textViewWidthConstraint?.constant = clampedWidth
    }

    // MARK: - Layout Setup

    private func setupLayout() {
        setContentHuggingPriority(.defaultLow, for: .horizontal)
        setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        textView.isEditable = false
        textView.isSelectable = true
        textView.drawsBackground = false
        textView.isRichText = false
        textView.textContainerInset = .zero
        textView.textContainer?.lineFragmentPadding = 0
        textView.textContainer?.lineBreakMode = .byCharWrapping
        textView.textContainer?.widthTracksTextView = true
        textView.isVerticallyResizable = false
        textView.isHorizontallyResizable = false
        textView.setContentHuggingPriority(.defaultLow, for: .horizontal)
        textView.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        textView.translatesAutoresizingMaskIntoConstraints = false

        let heightConstraint = textView.heightAnchor.constraint(equalToConstant: 0)
        heightConstraint.priority = .defaultHigh
        heightConstraint.isActive = true
        textViewHeightConstraint = heightConstraint

        switch role {
        case .user:
            let container = NSView()
            container.wantsLayer = true
            container.layer?.cornerRadius = 14
            container.setContentHuggingPriority(.defaultHigh, for: .horizontal)
            container.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
            container.translatesAutoresizingMaskIntoConstraints = false
            addSubview(container)
            container.addSubview(textView)
            self.containerView = container
            updateUserBubbleColor()

            let bottomC = container.bottomAnchor.constraint(equalTo: bottomAnchor)
            containerBottomConstraint = bottomC

            NSLayoutConstraint.activate([
                textView.topAnchor.constraint(equalTo: container.topAnchor, constant: 8),
                textView.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -8),
                textView.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 12),
                textView.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -12),

                container.topAnchor.constraint(equalTo: topAnchor),
                bottomC,
                container.trailingAnchor.constraint(equalTo: trailingAnchor),
                container.widthAnchor.constraint(lessThanOrEqualTo: widthAnchor, multiplier: 0.80),
            ])

        case .assistant:
            let mdView = MarkdownContentView()
            mdView.setContentHuggingPriority(.defaultLow, for: .horizontal)
            mdView.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
            mdView.translatesAutoresizingMaskIntoConstraints = false
            addSubview(mdView)
            markdownContentView = mdView

            let bottomC = mdView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -4)
            mdBottomConstraint = bottomC

            NSLayoutConstraint.activate([
                mdView.topAnchor.constraint(equalTo: topAnchor, constant: 4),
                bottomC,
                mdView.leadingAnchor.constraint(equalTo: leadingAnchor),
                mdView.trailingAnchor.constraint(equalTo: trailingAnchor),
            ])
        }
    }

    override func layout() {
        super.layout()
        if role == .user {
            let maxTextWidth = bounds.width * 0.80 - 24
            textView.textContainer?.size.width = max(0, maxTextWidth)
            recalculateTextSize()
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

// MARK: - Thinking Status View

private final class ThinkingStatusView: NSView {

    private let spinner: NSProgressIndicator
    private let thinkingLabel: NSTextField
    private let toolStatusLabel: NSTextField

    override init(frame: NSRect) {
        spinner = NSProgressIndicator()
        spinner.style = .spinning
        spinner.controlSize = .small
        spinner.isIndeterminate = true
        spinner.translatesAutoresizingMaskIntoConstraints = false

        thinkingLabel = NSTextField(labelWithString: "Thinking...")
        thinkingLabel.font = .systemFont(ofSize: 13, weight: .medium)
        thinkingLabel.textColor = .secondaryLabelColor
        thinkingLabel.translatesAutoresizingMaskIntoConstraints = false

        toolStatusLabel = NSTextField(labelWithString: "")
        toolStatusLabel.font = .systemFont(ofSize: 11)
        toolStatusLabel.textColor = .tertiaryLabelColor
        toolStatusLabel.lineBreakMode = .byTruncatingTail
        toolStatusLabel.isHidden = true
        toolStatusLabel.translatesAutoresizingMaskIntoConstraints = false

        super.init(frame: frame)

        let topRow = NSStackView(views: [spinner, thinkingLabel])
        topRow.orientation = .horizontal
        topRow.spacing = 6
        topRow.alignment = .centerY
        topRow.translatesAutoresizingMaskIntoConstraints = false

        let stack = NSStackView(views: [topRow, toolStatusLabel])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 2
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: topAnchor),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor),
            spinner.widthAnchor.constraint(equalToConstant: 16),
            spinner.heightAnchor.constraint(equalToConstant: 16),
        ])

        spinner.startAnimation(nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    func updateToolStatus(_ status: String?) {
        if let status, !status.isEmpty {
            toolStatusLabel.stringValue = status
            toolStatusLabel.isHidden = false
        } else {
            toolStatusLabel.isHidden = true
        }
    }
}
