import AppKit

final class AgentMessageListController: NSViewController {

    private let chatController: AgentChatController

    private var scrollView: NSScrollView!
    private var stackView: NSStackView!
    private var streamingRow: AgentMessageRowView?
    private var renderedMessageIds: [UUID] = []

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
    }

    // MARK: - Setup

    private func setupScrollView() {
        stackView = NSStackView()
        stackView.orientation = .vertical
        stackView.alignment = .leading
        stackView.spacing = 8
        stackView.edgeInsets = NSEdgeInsets(top: 12, left: 0, bottom: 12, right: 0)
        stackView.translatesAutoresizingMaskIntoConstraints = false

        let documentView = FlippedView()
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

    // MARK: - Row Management

    private func syncMessageRows() {
        let messages = chatController.messages
        let currentIds = messages.map(\.id)

        if currentIds.count < renderedMessageIds.count || (currentIds.count > 0 && renderedMessageIds.count > 0 && currentIds.first != renderedMessageIds.first) {
            // Chat switched or messages removed — full rebuild
            if let row = streamingRow {
                stackView.removeArrangedSubview(row)
                row.removeFromSuperview()
                streamingRow = nil
            }
            for v in stackView.arrangedSubviews {
                stackView.removeArrangedSubview(v)
                v.removeFromSuperview()
            }
            renderedMessageIds = []

            for message in messages {
                let row = AgentMessageRowView(role: message.role, content: message.content)
                addRow(row)
                renderedMessageIds.append(message.id)
            }
        } else {
            // Append only new messages
            let newMessages = messages.dropFirst(renderedMessageIds.count)
            for message in newMessages {
                if message.role == .assistant, let existingRow = streamingRow {
                    // Reuse the streaming row as the finalized row (no flash)
                    existingRow.update(content: message.content)
                    streamingRow = nil
                } else {
                    let row = AgentMessageRowView(role: message.role, content: message.content)
                    addRow(row, animated: true)
                }
                renderedMessageIds.append(message.id)
            }
        }

        if chatController.isStreaming && streamingRow == nil {
            let row = AgentMessageRowView(role: .assistant, content: chatController.streamingContent)
            addRow(row, animated: true)
            streamingRow = row
        } else if !chatController.isStreaming, let row = streamingRow {
            // Streaming ended with empty response — remove the row
            stackView.removeArrangedSubview(row)
            row.removeFromSuperview()
            streamingRow = nil
        }

        scrollToBottom()
    }

    private func updateStreamingRow() {
        streamingRow?.update(content: chatController.streamingContent)
        scrollToBottom()
    }

    private func addRow(_ row: AgentMessageRowView, animated: Bool = false) {
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
