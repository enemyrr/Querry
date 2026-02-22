import Foundation
import SwiftData
import AIProxy

@Observable
@MainActor
final class AgentChatController {

    private(set) var messages: [AgentMessage] = []
    private(set) var chats: [AgentChat] = []
    private(set) var currentChat: AgentChat?
    private(set) var isStreaming = false
    private(set) var streamingParts: [StreamingPart] = []
    private(set) var error: String?

    var selectedConnections: [Connection] = []

    private let notebookId: UUID
    private let modelContainer: ModelContainer
    private weak var notebookDataController: NotebookDataController?
    let engine = NotebookAgentEngine()
    private var streamingTask: Task<Void, Never>?
    private var thinkingPartStartTime: Date?

    init(notebookId: UUID, modelContainer: ModelContainer, notebookDataController: NotebookDataController) {
        self.notebookId = notebookId
        self.modelContainer = modelContainer
        self.notebookDataController = notebookDataController
    }

    func load() {
        let context = modelContainer.mainContext
        let id = notebookId
        let chatDescriptor = FetchDescriptor<AgentChat>(
            predicate: #Predicate { $0.notebookId == id },
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        chats = (try? context.fetch(chatDescriptor)) ?? []

        if let latest = chats.first {
            let chatId = latest.id
            let messageDescriptor = FetchDescriptor<AgentMessage>(
                predicate: #Predicate { $0.chatId == chatId }
            )
            let messageCount = (try? context.fetchCount(messageDescriptor)) ?? 0
            if messageCount == 0 {
                selectChat(latest)
            } else {
                createNewChat()
            }
        } else {
            createNewChat()
        }
    }

    func createNewChat() {
        streamingTask?.cancel()
        streamingTask = nil
        streamingParts = []
        isStreaming = false

        let chat = AgentChat(notebookId: notebookId)
        modelContainer.mainContext.insert(chat)
        save()
        chats.insert(chat, at: 0)
        selectChat(chat)
    }

    func selectChat(_ chat: AgentChat) {
        currentChat = chat
        loadMessages(for: chat)
    }

    func deleteChat(_ chat: AgentChat) {
        let chatId = chat.id
        let messageDescriptor = FetchDescriptor<AgentMessage>(
            predicate: #Predicate { $0.chatId == chatId }
        )
        if let messages = try? modelContainer.mainContext.fetch(messageDescriptor) {
            for msg in messages {
                modelContainer.mainContext.delete(msg)
            }
        }
        modelContainer.mainContext.delete(chat)
        save()
        chats.removeAll { $0.id == chatId }

        if currentChat?.id == chatId {
            if let next = chats.first {
                selectChat(next)
            } else {
                createNewChat()
            }
        }
    }

    func send(text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let chat = currentChat, !isStreaming else { return }

        if messages.isEmpty {
            chat.title = String(trimmed.prefix(60))
            chat.updatedAt = Date()
            save()
        }

        let userMessage = AgentMessage(chatId: chat.id, role: .user, content: text)
        modelContainer.mainContext.insert(userMessage)
        save()
        messages.append(userMessage)

        isStreaming = true
        streamingTask = Task { await performAgentLoop(chat: chat) }
    }

    func cancelStreaming() {
        streamingTask?.cancel()
        streamingTask = nil
        let finalContent = buildFinalContent()
        if !finalContent.isEmpty, let chat = currentChat {
            let msg = AgentMessage(chatId: chat.id, role: .assistant, content: finalContent)
            modelContainer.mainContext.insert(msg)
            save()
            messages.append(msg)
        }
        streamingParts = []
        isStreaming = false
    }

    func retry(from messageId: UUID) {
        guard !isStreaming else { return }
        guard let chat = currentChat else { return }
        guard let index = messages.firstIndex(where: { $0.id == messageId }) else { return }

        let toDelete = Array(messages[index...])
        for msg in toDelete {
            modelContainer.mainContext.delete(msg)
        }
        messages.removeSubrange(index...)
        save()

        isStreaming = true
        streamingTask = Task { await performAgentLoop(chat: chat) }
    }

    func setFeedback(_ feedback: AgentMessageFeedback?, for messageId: UUID) {
        guard let msg = messages.first(where: { $0.id == messageId }) else { return }
        msg.feedback = feedback
        save()
    }

    // MARK: - Agent Loop

    private static func toolDisplayName(for name: String, complete: Bool = false) -> (String, String) {
        switch name {
        case "list_tables":
            return (complete ? "Fetched tables" : "Fetching tables", "tablecells")
        case "get_table_schema":
            return (complete ? "Read data schema" : "Reading data schema", "square.stack.3d.up")
        case "create_chart_block":
            return (complete ? "Created chart" : "Creating chart", "chart.bar")
        case "create_text_block":
            return (complete ? "Created text block" : "Creating text block", "text.alignleft")
        default:
            let text = name.replacing("_", with: " ").capitalized
            return (text, "gearshape")
        }
    }

    private func performAgentLoop(chat: AgentChat) async {
        streamingParts = []
        error = nil
        engine.clearPendingCreations()

        let input = buildResponsesInput()
        var previousResponseId: String?
        var accumulatedAssistantText = ""

        do {
            var currentInput = input

            for _ in 0..<8 {
                guard !Task.isCancelled else { break }

                var thinkingStartTime: Date?

                let round = try await engine.performRound(
                    input: currentInput,
                    previousResponseId: previousResponseId,
                    connections: selectedConnections
                ) { [weak self] token in
                    guard let self else { return }
                    self.appendOrUpdateText(token)
                } onReasoning: { [weak self] delta in
                    guard let self else { return }
                    if thinkingStartTime == nil {
                        thinkingStartTime = Date()
                    }
                    self.appendOrUpdateThinking(delta)
                }

                previousResponseId = round.responseId ?? previousResponseId

                if let summary = round.reasoningSummary, !summary.isEmpty {
                    let duration = thinkingStartTime.map { max(1, Int(Date().timeIntervalSince($0))) }
                    if let duration {
                        accumulatedAssistantText += "<thinking duration=\"\(duration)\">\n\(summary)\n</thinking>\n\n"
                    } else {
                        accumulatedAssistantText += "<thinking>\n\(summary)\n</thinking>\n\n"
                    }
                }

                if round.toolCalls.isEmpty {
                    accumulatedAssistantText += round.streamedText
                    break
                }

                if !round.streamedText.isEmpty {
                    accumulatedAssistantText += round.streamedText
                }

                var toolOutputItems: [OpenAIResponse.Input.InputItem] = []

                for toolCall in round.toolCalls {
                    guard !Task.isCancelled else { break }

                    let (activeText, iconName) = Self.toolDisplayName(for: toolCall.name)
                    appendToolCall(id: toolCall.id, name: toolCall.name, displayText: activeText, iconName: iconName)
                    try? await Task.sleep(for: .milliseconds(50))

                    let result = await engine.executeToolCall(toolCall, connections: selectedConnections)

                    for creation in engine.pendingBlockCreations {
                        handleBlockCreation(creation)
                    }
                    engine.clearPendingCreations()

                    let (completeText, _) = Self.toolDisplayName(for: toolCall.name, complete: true)
                    markToolCallComplete(id: toolCall.id, displayText: completeText)
                    accumulatedAssistantText += "<tool_call name=\"\(toolCall.name)\">\(completeText)</tool_call>\n"
                    try? await Task.sleep(for: .milliseconds(50))

                    toolOutputItems.append(.functionCallOutput(callID: toolCall.id, output: result))
                }

                currentInput = .items(toolOutputItems)
            }
        } catch {
            if !Task.isCancelled {
                self.error = error.localizedDescription
            }
        }

        guard !Task.isCancelled else {
            isStreaming = false
            streamingParts = []
            return
        }

        if !accumulatedAssistantText.isEmpty {
            let assistantMessage = AgentMessage(chatId: chat.id, role: .assistant, content: accumulatedAssistantText)
            modelContainer.mainContext.insert(assistantMessage)
            save()
            messages.append(assistantMessage)
        }

        streamingParts = []
        isStreaming = false
    }

    // MARK: - Streaming Parts Helpers

    private func appendOrUpdateText(_ token: String) {
        thinkingPartStartTime = nil
        if case .text(let existing) = streamingParts.last {
            streamingParts[streamingParts.count - 1] = .text(existing + token)
        } else {
            streamingParts.append(.text(token))
        }
    }

    private func appendOrUpdateThinking(_ delta: String) {
        if case .thinking(let existing) = streamingParts.last {
            streamingParts[streamingParts.count - 1] = .thinking(existing + delta)
        } else {
            if thinkingPartStartTime == nil {
                thinkingPartStartTime = Date()
            }
            streamingParts.append(.thinking(delta))
        }
    }

    private func appendToolCall(id: String, name: String, displayText: String, iconName: String?) {
        thinkingPartStartTime = nil
        streamingParts.append(.toolCall(
            id: id,
            name: name,
            displayText: displayText,
            iconName: iconName,
            isComplete: false
        ))
    }

    private func markToolCallComplete(id: String, displayText: String) {
        guard let idx = streamingParts.lastIndex(where: {
            if case .toolCall(let tcId, _, _, _, _) = $0 { return tcId == id }
            return false
        }) else { return }
        if case .toolCall(let tcId, let name, _, let icon, _) = streamingParts[idx] {
            streamingParts[idx] = .toolCall(id: tcId, name: name, displayText: displayText, iconName: icon, isComplete: true)
        }
    }

    private func buildFinalContent() -> String {
        var result = ""
        for part in streamingParts {
            switch part {
            case .thinking(let text):
                let duration = thinkingPartStartTime.map { max(1, Int(Date().timeIntervalSince($0))) }
                if let duration {
                    result += "<thinking duration=\"\(duration)\">\n\(text)\n</thinking>\n\n"
                } else {
                    result += "<thinking>\n\(text)\n</thinking>\n\n"
                }
            case .text(let text):
                result += text
            case .toolCall(_, let name, let displayText, _, _):
                result += "<tool_call name=\"\(name)\">\(displayText)</tool_call>\n"
            }
        }
        return result
    }

    // MARK: - Block Creation

    private func handleBlockCreation(_ request: BlockCreationRequest) {
        guard let dataController = notebookDataController else { return }

        switch request.kind {
        case .chart:
            dataController.addChartBlock()
            if let block = dataController.blocks.last, let config = request.config {
                block.title = request.title
                block.saveChartConfig(config)
                dataController.updateBlock(block)
            }
        case .text:
            dataController.addTextBlock()
            if let block = dataController.blocks.last {
                block.textContent = request.textContent ?? ""
                dataController.updateBlock(block)
            }
        }
    }

    // MARK: - Message Building (Responses API)

    private func buildResponsesInput() -> OpenAIResponse.Input {
        var items: [OpenAIResponse.Input.InputItem] = []
        for msg in messages {
            switch msg.role {
            case .user:
                items.append(.message(role: .user, content: .text(msg.content)))
            case .assistant:
                let strippedContent = stripThinkingBlocks(from: msg.content)
                if !strippedContent.isEmpty {
                    items.append(.message(role: .assistant, content: .text(strippedContent)))
                }
            }
        }
        return .items(items)
    }

    private func stripThinkingBlocks(from text: String) -> String {
        var result = text
        if let thinkingRegex = try? Regex("<thinking[^>]*>[\\s\\S]*?</thinking>\\n*") {
            result = result.replacing(thinkingRegex, with: "")
        }
        if let toolCallRegex = try? Regex("<tool_call[^>]*>[^<]*</tool_call>\\n*") {
            result = result.replacing(toolCallRegex, with: "")
        }
        return result
    }

    // MARK: - Persistence

    private func loadMessages(for chat: AgentChat) {
        let chatId = chat.id
        let descriptor = FetchDescriptor<AgentMessage>(
            predicate: #Predicate { $0.chatId == chatId },
            sortBy: [SortDescriptor(\.createdAt)]
        )
        messages = (try? modelContainer.mainContext.fetch(descriptor)) ?? []
    }

    private func save() {
        try? modelContainer.mainContext.save()
    }
}
