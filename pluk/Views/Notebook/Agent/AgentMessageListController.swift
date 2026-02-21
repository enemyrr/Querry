import AppKit

final class AgentMessageListController: NSViewController {

    private let chatController: AgentChatController

    private var scrollView: NSScrollView!
    private var stackView: NSStackView!
    private var streamingRow: AgentMessageRowView?
    private var renderedMessageIds: [UUID] = []
    private weak var lastAssistantRow: AgentMessageRowView?

    init(chatController: AgentChatController) {
        self.chatController = chatController
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    override func loadView() {
        let root = NSView()
        self.view = root
        setupScrollView()
        observeMessages()
        observeStreaming()
        observeToolCalls()
    }

    // MARK: - Setup

    private func setupScrollView() {
        stackView = NSStackView()
        stackView.orientation = .vertical
        stackView.alignment = .leading
        stackView.spacing = 8
        stackView.edgeInsets = NSEdgeInsets(top: 12, left: 0, bottom: 12, right: 0)
        stackView.setContentHuggingPriority(.defaultLow, for: .horizontal)
        stackView.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        stackView.translatesAutoresizingMaskIntoConstraints = false

        let documentView = FlippedView()
        documentView.setContentHuggingPriority(.defaultLow, for: .horizontal)
        documentView.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        documentView.translatesAutoresizingMaskIntoConstraints = false
        documentView.addSubview(stackView)

        let clipView = NSClipView()
        clipView.drawsBackground = false
        clipView.documentView = documentView

        scrollView = NSScrollView()
        scrollView.contentView = clipView
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.drawsBackground = false
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scrollView)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            stackView.topAnchor.constraint(equalTo: documentView.topAnchor),
            stackView.leadingAnchor.constraint(equalTo: documentView.leadingAnchor, constant: 12),
            stackView.trailingAnchor.constraint(equalTo: documentView.trailingAnchor, constant: -12),
            stackView.bottomAnchor.constraint(equalTo: documentView.bottomAnchor),

            documentView.widthAnchor.constraint(equalTo: scrollView.widthAnchor),
        ])
    }

    // MARK: - Observation

    private func observeMessages() {
        withObservationTracking {
            _ = self.chatController.messages.count
            _ = self.chatController.isStreaming
        } onChange: { [weak self] in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.syncMessageRows()
                self.observeMessages()
            }
        }
    }

    private func observeStreaming() {
        withObservationTracking {
            _ = self.chatController.streamingContent
        } onChange: { [weak self] in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.updateStreamingRow()
                self.observeStreaming()
            }
        }
    }

    private func observeToolCalls() {
        withObservationTracking {
            _ = self.chatController.activeToolCalls
        } onChange: { [weak self] in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.streamingRow?.updateToolCalls(self.chatController.activeToolCalls)
                self.observeToolCalls()
            }
        }
    }

    // MARK: - Row Management

    private func syncMessageRows() {
        let messages = chatController.messages
        let currentIds = messages.map(\.id)

        let needsFullRebuild = currentIds.count < renderedMessageIds.count
            || (!currentIds.isEmpty && !renderedMessageIds.isEmpty && currentIds.first != renderedMessageIds.first)

        if needsFullRebuild {
            removeStreamingRow()
            for v in stackView.arrangedSubviews {
                stackView.removeArrangedSubview(v)
                v.removeFromSuperview()
            }
            renderedMessageIds = []
            lastAssistantRow = nil

            for message in messages {
                let row = makeRow(for: message)
                if message.role == .assistant {
                    lastAssistantRow?.setActionBarAlwaysVisible(false)
                    lastAssistantRow = row
                }
                addRow(row)
                renderedMessageIds.append(message.id)
            }
            lastAssistantRow?.setActionBarAlwaysVisible(true)
        } else {
            let newMessages = messages.dropFirst(renderedMessageIds.count)
            for message in newMessages {
                if message.role == .assistant, let existingRow = streamingRow {
                    lastAssistantRow?.setActionBarAlwaysVisible(false)
                    existingRow.update(content: message.content)
                    existingRow.markFinalized(createdAt: message.createdAt, feedback: message.feedback)
                    wireCallbacks(on: existingRow, message: message)
                    existingRow.setActionBarAlwaysVisible(true)
                    lastAssistantRow = existingRow
                    streamingRow = nil
                } else {
                    if message.role == .assistant {
                        lastAssistantRow?.setActionBarAlwaysVisible(false)
                    }
                    let row = makeRow(for: message)
                    if message.role == .assistant {
                        row.setActionBarAlwaysVisible(true)
                        lastAssistantRow = row
                    }
                    addRow(row, animated: true)
                }
                renderedMessageIds.append(message.id)
            }
        }

        if chatController.isStreaming && streamingRow == nil {
            let row = AgentMessageRowView(role: .assistant, content: chatController.streamingContent, isStreaming: true)
            addRow(row, animated: true)
            streamingRow = row
        } else if !chatController.isStreaming {
            removeStreamingRow()
        }

        scrollToBottom()
    }

    private func removeStreamingRow() {
        guard let row = streamingRow else { return }
        stackView.removeArrangedSubview(row)
        row.removeFromSuperview()
        streamingRow = nil
    }

    private func updateStreamingRow() {
        streamingRow?.update(content: chatController.streamingContent)
        scrollToBottom()
    }

    // MARK: - Row Factory

    private func makeRow(for message: AgentMessage) -> AgentMessageRowView {
        let row = AgentMessageRowView(
            role: message.role,
            content: message.content,
            createdAt: message.createdAt,
            feedback: message.feedback
        )
        wireCallbacks(on: row, message: message)
        return row
    }

    private func wireCallbacks(on row: AgentMessageRowView, message: AgentMessage) {
        row.onRetry = { [weak self] in
            self?.chatController.retry(from: message.id)
        }
        row.onFeedbackChanged = { [weak self] feedback in
            self?.chatController.setFeedback(feedback, for: message.id)
        }
    }

    // MARK: - Helpers

    private func addRow(_ row: AgentMessageRowView, animated: Bool = false) {
        row.setContentHuggingPriority(.defaultLow, for: .horizontal)
        row.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        row.translatesAutoresizingMaskIntoConstraints = false
        stackView.addArrangedSubview(row)
        NSLayoutConstraint.activate([
            row.leadingAnchor.constraint(equalTo: stackView.leadingAnchor),
            row.trailingAnchor.constraint(equalTo: stackView.trailingAnchor),
        ])

        if animated {
            row.wantsLayer = true
            row.alphaValue = 0
            row.layer?.transform = CATransform3DMakeTranslation(0, 20, 0)

            stackView.layoutSubtreeIfNeeded()

            NSAnimationContext.runAnimationGroup { ctx in
                ctx.duration = 0.3
                ctx.timingFunction = CAMediaTimingFunction(name: .easeOut)
                row.animator().alphaValue = 1
                row.layer?.transform = CATransform3DIdentity
            }
        }
    }

    private func scrollToBottom() {
        guard let documentView = scrollView.documentView else { return }
        documentView.layoutSubtreeIfNeeded()
        let contentHeight = documentView.frame.height
        let visibleHeight = scrollView.contentView.bounds.height
        if contentHeight > visibleHeight {
            let bottomPoint = NSPoint(x: 0, y: contentHeight - visibleHeight)
            scrollView.contentView.scroll(to: bottomPoint)
            scrollView.reflectScrolledClipView(scrollView.contentView)
        }
    }
}

private final class FlippedView: NSView {
    override var isFlipped: Bool { true }
}
