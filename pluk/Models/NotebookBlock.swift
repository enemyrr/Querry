import SwiftData
import Foundation

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
    var isHiddenInDashboard: Bool = false

    init(notebookId: UUID, blockType: NotebookBlockType, sortOrder: Int) {
        self.notebookId = notebookId
        self.blockType = blockType
        self.sortOrder = sortOrder
    }

    var textContent: String {
        get { blockType == .text ? configJSON : "" }
        set {
            guard blockType == .text else { return }
            configJSON = newValue
            updatedAt = Date()
        }
    }
}
