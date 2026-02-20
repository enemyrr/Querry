import SwiftData
import Foundation

enum AgentMessageRole: String, Codable {
    case user
    case assistant
}

@Model
final class AgentMessage {
    var id: UUID = UUID()
    var chatId: UUID = UUID()
    var role: AgentMessageRole = AgentMessageRole.user
    var content: String = ""
    var createdAt: Date = Date()

    init(chatId: UUID, role: AgentMessageRole, content: String) {
        self.chatId = chatId
        self.role = role
        self.content = content
    }
}
