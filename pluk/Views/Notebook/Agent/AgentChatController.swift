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
    private var reasoningStartTime: Date?

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

        if let latest = chats.first {
            let chatId = latest.id
            let descriptor = FetchDescriptor<AgentMessage>(
                predicate: #Predicate { $0.chatId == chatId }
            )
            let count = (try? modelContainer.mainContext.fetchCount(descriptor)) ?? 0
            if count == 0 {
                selectChat(latest)
                return
            }
        }

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

    private func performAgentLoop(chat: AgentChat) async {
        streamingParts = []
        error = nil
        engine.clearPendingCreations()

        var input = buildResponseInput()
        var previousResponseId: String?
        var accumulatedAssistantText = ""

        do {
            var roundNumber = 0

            for _ in 0..<100 {
                guard !Task.isCancelled else { break }
                roundNumber += 1

                let round = try await engine.performRound(
                    input: input,
                    previousResponseId: previousResponseId,
                    connections: selectedConnections,
                    onToken: { [weak self] token in
                        guard let self else { return }
                        self.appendOrUpdateText(token)
                    },
                    onReasoning: { [weak self] text in
                        guard let self else { return }
                        self.appendOrUpdateThinking(text)
                    }
                )

                previousResponseId = round.responseId

                print("[AgentChat] round \(roundNumber) complete — reasoning: \(round.reasoningSummary?.count ?? 0) chars, text: \(round.streamedText.count) chars, toolCalls: \(round.toolCalls.count)")

                if let reasoning = round.reasoningSummary, !reasoning.isEmpty {
                    let duration = reasoningStartTime.map { max(1, Int(Date().timeIntervalSince($0))) } ?? 0
                    print("[AgentChat] saving thinking block (duration: \(duration)s)")
                    accumulatedAssistantText += "<thinking duration=\"\(duration)\">\n\(reasoning)\n</thinking>\n"
                    reasoningStartTime = nil
                }

                if round.toolCalls.isEmpty {
                    accumulatedAssistantText += round.streamedText
                    print("[AgentChat] no tool calls, ending loop")
                    break
                }

                if !round.streamedText.isEmpty {
                    accumulatedAssistantText += round.streamedText
                }

                // Execute tools and send results back via previousResponseId
                var toolOutputItems: [OpenAIResponse.Input.InputItem] = []

                for toolCall in round.toolCalls {
                    guard !Task.isCancelled else { break }

                    let activeInfo = ToolMetadata.displayInfo(for: toolCall.name, arguments: toolCall.arguments)
                    appendToolCall(id: toolCall.id, name: toolCall.name, displayText: activeInfo.text, iconName: activeInfo.icon, round: roundNumber)
                    try? await Task.sleep(for: .milliseconds(50))

                    let result = await engine.executeToolCall(toolCall, connections: selectedConnections)

                    for creation in engine.pendingBlockCreations {
                        handleBlockCreation(creation)
                    }
                    engine.clearPendingCreations()

                    let completeInfo = ToolMetadata.displayInfo(for: toolCall.name, arguments: toolCall.arguments)
                    markToolCallComplete(id: toolCall.id, displayText: completeInfo.text)
                    if !accumulatedAssistantText.isEmpty && !accumulatedAssistantText.hasSuffix("\n") {
                        accumulatedAssistantText += "\n"
                    }
                    accumulatedAssistantText += "<tool_call name=\"\(toolCall.name)\">\(completeInfo.text)</tool_call>\n"
                    try? await Task.sleep(for: .milliseconds(50))

                    toolOutputItems.append(.functionCallOutput(callID: toolCall.id, output: result))
                }

                input = .items(toolOutputItems)
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
            print("[AgentChat] saving assistant message (\(accumulatedAssistantText.count) chars)")
            print("[AgentChat] content preview:\n\(String(accumulatedAssistantText.prefix(500)))")
            let assistantMessage = AgentMessage(chatId: chat.id, role: .assistant, content: accumulatedAssistantText)
            modelContainer.mainContext.insert(assistantMessage)
            save()
            messages.append(assistantMessage)
        }

        print("[AgentChat] streaming finished, parts: \(streamingParts.count)")
        streamingParts = []
        isStreaming = false
    }

    // MARK: - Streaming Parts Helpers

    private func appendOrUpdateText(_ token: String) {
        if case .text(let existing) = streamingParts.last {
            streamingParts[streamingParts.count - 1] = .text(existing + token)
        } else {
            print("[AgentChat] +text part (total parts: \(streamingParts.count + 1))")
            streamingParts.append(.text(token))
        }
    }

    private func appendOrUpdateThinking(_ token: String) {
        if case .thinking(let existing) = streamingParts.last {
            streamingParts[streamingParts.count - 1] = .thinking(existing + token)
        } else {
            print("[AgentChat] +thinking part (total parts: \(streamingParts.count + 1))")
            reasoningStartTime = Date()
            streamingParts.append(.thinking(token))
        }
    }

    private func appendToolCall(id: String, name: String, displayText: String, iconName: String?, round: Int) {
        print("[AgentChat] +toolCall: \(name) id=\(id) round=\(round) displayText=\"\(displayText)\" (total parts: \(streamingParts.count + 1))")
        streamingParts.append(.toolCall(
            id: id,
            name: name,
            displayText: displayText,
            iconName: iconName,
            isComplete: false,
            round: round
        ))
    }

    private func markToolCallComplete(id: String, displayText: String) {
        guard let idx = streamingParts.lastIndex(where: {
            if case .toolCall(let tcId, _, _, _, _, _) = $0 { return tcId == id }
            return false
        }),
        case .toolCall(let tcId, let name, _, let icon, _, let round) = streamingParts[idx] else {
            print("[AgentChat] markToolCallComplete FAILED: id=\(id) not found")
            return
        }
        print("[AgentChat] toolCall complete: \(name) id=\(tcId) round=\(round) displayText=\"\(displayText)\"")
        streamingParts[idx] = .toolCall(id: tcId, name: name, displayText: displayText, iconName: icon, isComplete: true, round: round)
    }

    private func buildFinalContent() -> String {
        streamingParts.map { part in
            switch part {
            case .thinking(let text):
                let duration = reasoningStartTime.map { max(1, Int(Date().timeIntervalSince($0))) } ?? 0
                return "<thinking duration=\"\(duration)\">\n\(text)\n</thinking>\n"
            case .text(let text):
                return text
            case .toolCall(_, let name, let displayText, _, _, _):
                return "<tool_call name=\"\(name)\">\(displayText)</tool_call>\n"
            }
        }.joined()
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

    private func buildResponseInput() -> OpenAIResponse.Input {
        var items: [OpenAIResponse.Input.InputItem] = []
        for msg in messages {
            switch msg.role {
            case .user:
                items.append(.message(role: .user, content: .text(msg.content)))
            case .assistant:
                let strippedContent = stripSerializedTags(from: msg.content)
                if !strippedContent.isEmpty {
                    items.append(.message(role: .assistant, content: .text(strippedContent)))
                }
            }
        }
        return .items(items)
    }

    private static let toolCallTagRegex = try! Regex("<tool_call[^>]*>[^<]*</tool_call>\\n*")
    private static let thinkingTagRegex = try! Regex("<thinking[^>]*>[\\s\\S]*?</thinking>\\n*")

    private func stripSerializedTags(from text: String) -> String {
        text.replacing(Self.toolCallTagRegex, with: "")
            .replacing(Self.thinkingTagRegex, with: "")
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
