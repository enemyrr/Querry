import SwiftData
import Foundation

enum NotebookBlockType: String, Codable {
    case chart
}

@Model
final class NotebookBlock {
    var id: UUID = UUID()
    var notebookId: UUID = UUID()
    var blockType: NotebookBlockType = NotebookBlockType.chart
    var sortOrder: Int = 0
    var createdAt: Date = Date()
    var updatedAt: Date = Date()
    var title: String = ""
    var blockHeight: Double = 380
    var configJSON: String = ""

    init(notebookId: UUID, blockType: NotebookBlockType, sortOrder: Int) {
        self.notebookId = notebookId
        self.blockType = blockType
        self.sortOrder = sortOrder
    }
}
