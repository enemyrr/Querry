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
            thinking.topAnchor.constraint(equalTo: topAnchor, constant: 4),
            thinking.bottomAnchor.constraint(lessThanOrEqualTo: bottomAnchor, constant: -4),
        ])
        thinkingView = thinking
    }

    private func hideLoading() {
        guard let thinking = thinkingView else { return }
        thinking.removeFromSuperview()
        thinkingView = nil
        primaryContentView.isHidden = false
    }

    func updateToolCalls(_ calls: [AgentChatController.ToolCallStatus]) {
        thinkingView?.updateToolCalls(calls)
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
        guard role == .user else { return }
        guard let attributedText = textView.textStorage else { return }
        guard let textContainer = textView.textContainer else { return }

        let maxWidth = max(0, bounds.width * 0.80 - 24)
        guard maxWidth > 0 else {
            textViewWidthConstraint?.constant = 1
            textViewHeightConstraint?.constant = 1
            return
        }

        let unconstrainedRect = attributedText.boundingRect(
            with: NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading]
        )
        let clampedWidth = max(1, min(maxWidth, ceil(unconstrainedRect.width)))

        let constrainedRect = attributedText.boundingRect(
            with: NSSize(width: clampedWidth, height: CGFloat.greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading]
        )

        textContainer.containerSize = NSSize(width: clampedWidth, height: CGFloat.greatestFiniteMagnitude)
        textViewWidthConstraint?.constant = clampedWidth
        textViewHeightConstraint?.constant = max(1, ceil(constrainedRect.height))
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
        textView.textContainer?.lineBreakMode = .byWordWrapping
        textView.textContainer?.widthTracksTextView = false
        textView.isVerticallyResizable = false
        textView.isHorizontallyResizable = false
        textView.setContentHuggingPriority(.defaultLow, for: .horizontal)
        textView.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        textView.translatesAutoresizingMaskIntoConstraints = false

        let heightConstraint = textView.heightAnchor.constraint(equalToConstant: 0)
        heightConstraint.priority = .defaultHigh
        heightConstraint.isActive = true
        textViewHeightConstraint = heightConstraint

        let widthConstraint = textView.widthAnchor.constraint(equalToConstant: 0)
        widthConstraint.priority = .defaultHigh
        widthConstraint.isActive = true
        textViewWidthConstraint = widthConstraint

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

// MARK: - Thinking Status View

private final class ThinkingStatusView: NSView {

    private let mainStack: NSStackView
    private let thinkingIcon: NSImageView
    private let thinkingLabel: NSTextField
    private var toolCallRows: [ToolCallRowView] = []

    override init(frame: NSRect) {
        thinkingIcon = NSImageView()
        thinkingIcon.image = NSImage(systemSymbolName: "lightbulb.max", accessibilityDescription: nil)
        thinkingIcon.contentTintColor = .tertiaryLabelColor
        thinkingIcon.symbolConfiguration = .init(pointSize: 13, weight: .medium)
        thinkingIcon.translatesAutoresizingMaskIntoConstraints = false

        thinkingLabel = NSTextField(labelWithString: "Thinking")
        thinkingLabel.font = .systemFont(ofSize: 13, weight: .medium)
        thinkingLabel.textColor = .secondaryLabelColor

        let thinkingRow = NSStackView(views: [thinkingIcon, thinkingLabel])
        thinkingRow.orientation = .horizontal
        thinkingRow.spacing = 6
        thinkingRow.alignment = .centerY

        mainStack = NSStackView(views: [thinkingRow])
        mainStack.orientation = .vertical
        mainStack.alignment = .leading
        mainStack.spacing = 6

        super.init(frame: frame)

        mainStack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(mainStack)

        NSLayoutConstraint.activate([
            mainStack.topAnchor.constraint(equalTo: topAnchor),
            mainStack.leadingAnchor.constraint(equalTo: leadingAnchor),
            mainStack.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor),
            mainStack.bottomAnchor.constraint(equalTo: bottomAnchor),
            thinkingIcon.widthAnchor.constraint(equalToConstant: 16),
            thinkingIcon.heightAnchor.constraint(equalToConstant: 16),
        ])

        startThinkingPulse()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    func updateToolCalls(_ calls: [AgentChatController.ToolCallStatus]) {
        // Collapse when calls cleared
        if calls.isEmpty && !toolCallRows.isEmpty {
            collapseToolCalls()
            return
        }

        // Add new rows for new tool calls
        while toolCallRows.count < calls.count {
            let call = calls[toolCallRows.count]
            let row = ToolCallRowView(displayText: call.displayText)
            row.translatesAutoresizingMaskIntoConstraints = false
            mainStack.addArrangedSubview(row)
            toolCallRows.append(row)

            row.alphaValue = 0
            NSAnimationContext.runAnimationGroup { ctx in
                ctx.duration = 0.2
                row.animator().alphaValue = 1
            }
        }

        // Update completion state on existing rows
        for (i, call) in calls.enumerated() where i < toolCallRows.count {
            if call.isComplete {
                toolCallRows[i].markComplete()
            }
        }
    }

    private func collapseToolCalls() {
        let rows = toolCallRows
        toolCallRows.removeAll()

        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.25
            for row in rows {
                row.animator().alphaValue = 0
            }
        } completionHandler: { [weak self] in
            guard let self else { return }
            for row in rows {
                self.mainStack.removeArrangedSubview(row)
                row.removeFromSuperview()
            }
        }
    }

    private func startThinkingPulse() {
        thinkingIcon.wantsLayer = true
        let pulse = CABasicAnimation(keyPath: "opacity")
        pulse.fromValue = 1.0
        pulse.toValue = 0.3
        pulse.duration = 1.2
        pulse.autoreverses = true
        pulse.repeatCount = .infinity
        pulse.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        thinkingIcon.layer?.add(pulse, forKey: "pulse")
    }
}

// MARK: - Tool Call Row View

private final class ToolCallRowView: NSView {

    private let spinner: NSProgressIndicator
    private let checkCircle: NSView
    private let checkIcon: NSImageView
    private let label: NSTextField

    init(displayText: String) {
        spinner = NSProgressIndicator()
        spinner.style = .spinning
        spinner.controlSize = .mini
        spinner.isIndeterminate = true

        checkCircle = NSView()
        checkCircle.wantsLayer = true
        checkCircle.layer?.cornerRadius = 5.5
        checkCircle.layer?.backgroundColor = NSColor.tertiaryLabelColor.cgColor
        checkCircle.isHidden = true

        checkIcon = NSImageView()
        checkIcon.image = NSImage(systemSymbolName: "checkmark", accessibilityDescription: nil)
        checkIcon.contentTintColor = .white
        checkIcon.symbolConfiguration = .init(pointSize: 6, weight: .bold)
        checkIcon.translatesAutoresizingMaskIntoConstraints = false

        label = NSTextField(labelWithString: displayText)
        label.font = .systemFont(ofSize: 13)
        label.textColor = .secondaryLabelColor
        label.lineBreakMode = .byTruncatingTail

        super.init(frame: .zero)

        checkCircle.addSubview(checkIcon)

        let iconContainer = NSView()
        iconContainer.translatesAutoresizingMaskIntoConstraints = false
        spinner.translatesAutoresizingMaskIntoConstraints = false
        checkCircle.translatesAutoresizingMaskIntoConstraints = false
        iconContainer.addSubview(spinner)
        iconContainer.addSubview(checkCircle)

        let row = NSStackView(views: [iconContainer, label])
        row.orientation = .horizontal
        row.spacing = 6
        row.alignment = .centerY
        row.translatesAutoresizingMaskIntoConstraints = false
        addSubview(row)

        NSLayoutConstraint.activate([
            iconContainer.widthAnchor.constraint(equalToConstant: 16),
            iconContainer.heightAnchor.constraint(equalToConstant: 16),
            spinner.centerXAnchor.constraint(equalTo: iconContainer.centerXAnchor),
            spinner.centerYAnchor.constraint(equalTo: iconContainer.centerYAnchor),
            checkCircle.widthAnchor.constraint(equalToConstant: 11),
            checkCircle.heightAnchor.constraint(equalToConstant: 11),
            checkCircle.centerXAnchor.constraint(equalTo: iconContainer.centerXAnchor),
            checkCircle.centerYAnchor.constraint(equalTo: iconContainer.centerYAnchor),
            checkIcon.centerXAnchor.constraint(equalTo: checkCircle.centerXAnchor),
            checkIcon.centerYAnchor.constraint(equalTo: checkCircle.centerYAnchor),
            row.topAnchor.constraint(equalTo: topAnchor),
            row.leadingAnchor.constraint(equalTo: leadingAnchor),
            row.trailingAnchor.constraint(equalTo: trailingAnchor),
            row.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])

        spinner.startAnimation(nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    func markComplete() {
        guard !spinner.isHidden else { return }
        spinner.stopAnimation(nil)
        spinner.isHidden = true
        checkCircle.isHidden = false
    }
}
