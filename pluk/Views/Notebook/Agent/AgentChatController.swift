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

    private let notebookId: UUID
    private let modelContainer: ModelContainer

    private static let partialKey = "v2|3fe1f505|AS4tm59nSGxScFCN"
    private static let serviceURL = "https://api.aiproxy.pro/4c1638f9/2f62a0df"
    private var streamingTask: Task<Void, Never>?

    init(notebookId: UUID, modelContainer: ModelContainer) {
        self.notebookId = notebookId
        self.modelContainer = modelContainer
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
        streamingTask = Task { await performStreaming(chat: chat) }
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
        streamingTask = Task { await performStreaming(chat: chat) }
    }

    func setFeedback(_ feedback: AgentMessageFeedback?, for messageId: UUID) {
        guard let msg = messages.first(where: { $0.id == messageId }) else { return }
        msg.feedback = feedback
        save()
    }

    private func loadMessages(for chat: AgentChat) {
        let chatId = chat.id
        let descriptor = FetchDescriptor<AgentMessage>(
            predicate: #Predicate { $0.chatId == chatId },
            sortBy: [SortDescriptor(\.createdAt)]
        )
        messages = (try? modelContainer.mainContext.fetch(descriptor)) ?? []
    }

    private func performStreaming(chat: AgentChat) async {
        streamingContent = ""
        error = nil

        let openAIMessages = buildOpenAIMessages()

        do {
            let openAIService = AIProxy.openAIService(
                partialKey: Self.partialKey,
                serviceURL: Self.serviceURL
            )
            let stream = try await openAIService.streamingChatCompletionRequest(
                body: .init(
                    model: "gpt-4.1-mini",
                    messages: openAIMessages,
                ),
                secondsToWait: 60,
            )
            for try await chunk in stream {
                guard !Task.isCancelled else { break }
                if let token = chunk.choices.first?.delta.content {
                    streamingContent += token
                }
            }
        } catch {
            if !Task.isCancelled {
                self.error = error.localizedDescription
            }
        }

        guard !Task.isCancelled else {
            isStreaming = false
            streamingContent = ""
            return
        }

        if !streamingContent.isEmpty {
            let assistantMessage = AgentMessage(chatId: chat.id, role: .assistant, content: streamingContent)
            modelContainer.mainContext.insert(assistantMessage)
            save()
            messages.append(assistantMessage)
        }

        streamingContent = ""
        isStreaming = false
    }

    private func buildOpenAIMessages() -> [OpenAIChatCompletionRequestBody.Message] {
        var result: [OpenAIChatCompletionRequestBody.Message] = [
            .system(content: .text("You are a helpful general-purpose AI assistant."))
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

    private func save() {
        try? modelContainer.mainContext.save()
    }
}
