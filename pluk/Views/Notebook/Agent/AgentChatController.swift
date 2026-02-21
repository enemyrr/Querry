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
    private(set) var streamingContent = ""
    private(set) var error: String?
    private(set) var toolStatusMessage: String?

    var selectedConnections: [Connection] = []

    private let notebookId: UUID
    private let modelContainer: ModelContainer
    private weak var notebookDataController: NotebookDataController?
    let engine = NotebookAgentEngine()
    private var streamingTask: Task<Void, Never>?

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
        streamingContent = ""
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
        if !streamingContent.isEmpty, let chat = currentChat {
            let msg = AgentMessage(chatId: chat.id, role: .assistant, content: streamingContent)
            modelContainer.mainContext.insert(msg)
            save()
            messages.append(msg)
        }
        streamingContent = ""
        toolStatusMessage = nil
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
        streamingContent = ""
        error = nil
        engine.clearPendingCreations()

        var conversationHistory = buildOpenAIMessages()
        var accumulatedAssistantText = ""

        do {
            for _ in 0..<8 {
                guard !Task.isCancelled else { break }

                let round = try await engine.performRound(
                    messages: conversationHistory,
                    connections: selectedConnections
                ) { [weak self] token in
                    self?.streamingContent += token
                }

                if round.toolCalls.isEmpty {
                    accumulatedAssistantText += round.streamedText
                    break
                }

                // Build assistant message with tool calls for context
                let assistantToolCalls = round.toolCalls.map { tc in
                    OpenAIChatCompletionRequestBody.Message.ToolCall(
                        id: tc.id,
                        function: .init(name: tc.name, arguments: tc.arguments)
                    )
                }
                conversationHistory.append(.assistant(
                    content: round.streamedText.isEmpty ? nil : .text(round.streamedText),
                    toolCalls: assistantToolCalls
                ))

                // Execute tool calls
                for toolCall in round.toolCalls {
                    guard !Task.isCancelled else { break }
                    toolStatusMessage = "Running \(toolCall.name)..."

                    let result = await engine.executeToolCall(toolCall, connections: selectedConnections)

                    // Handle any block creations
                    for creation in engine.pendingBlockCreations {
                        handleBlockCreation(creation)
                    }
                    engine.clearPendingCreations()

                    conversationHistory.append(.tool(
                        content: .text(result),
                        toolCallID: toolCall.id
                    ))
                }

                // Accumulate any text from tool-call rounds for fallback persistence
                if !round.streamedText.isEmpty {
                    accumulatedAssistantText += round.streamedText
                }

                // Reset streaming content for next round
                streamingContent = ""
            }
        } catch {
            if !Task.isCancelled {
                self.error = error.localizedDescription
            }
        }

        guard !Task.isCancelled else {
            isStreaming = false
            streamingContent = ""
            toolStatusMessage = nil
            return
        }

        if !accumulatedAssistantText.isEmpty {
            let assistantMessage = AgentMessage(chatId: chat.id, role: .assistant, content: accumulatedAssistantText)
            modelContainer.mainContext.insert(assistantMessage)
            save()
            messages.append(assistantMessage)
        }

        streamingContent = ""
        toolStatusMessage = nil
        isStreaming = false
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

    // MARK: - Message Building

    private func buildOpenAIMessages() -> [OpenAIChatCompletionRequestBody.Message] {
        let systemPrompt = engine.buildSystemPrompt(connections: selectedConnections)
        var result: [OpenAIChatCompletionRequestBody.Message] = [
            .system(content: .text(systemPrompt))
        ]
        for msg in messages {
            switch msg.role {
            case .user:
                result.append(.user(content: .text(msg.content)))
            case .assistant:
                result.append(.assistant(content: .text(msg.content), toolCalls: nil))
            }
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
