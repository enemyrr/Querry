import SwiftData
import SwiftUI

@Observable
@MainActor
final class NotebookDataController {

    private let notebookId: UUID
    private let modelContainer: ModelContainer

    private(set) var notebook: Notebook?
    private(set) var connections: [Connection] = []

    var title: String {
        get { notebook?.title ?? "Untitled Notebook" }
        set {
            notebook?.title = newValue
            notebook?.updatedAt = Date()
            save()
        }
    }

    var descriptionText: String {
        get { notebook?.descriptionText ?? "" }
        set {
            notebook?.descriptionText = newValue
            notebook?.updatedAt = Date()
            save()
        }
    }

    var status: NotebookStatus {
        get { notebook?.status ?? .exploratory }
        set {
            notebook?.status = newValue
            notebook?.updatedAt = Date()
            save()
        }
    }

    init(notebookId: UUID, modelContainer: ModelContainer) {
        self.notebookId = notebookId
        self.modelContainer = modelContainer
    }

    func load() {
        let context = modelContainer.mainContext
        let id = notebookId

        let notebookDescriptor = FetchDescriptor<Notebook>(
            predicate: #Predicate { $0.id == id }
        )
        notebook = try? context.fetch(notebookDescriptor).first

        let connectionDescriptor = FetchDescriptor<Connection>(
            sortBy: [SortDescriptor(\.lastOpenedAt, order: .reverse)]
        )
        connections = (try? context.fetch(connectionDescriptor)) ?? []
    }

    private func save() {
        try? modelContainer.mainContext.save()
    }
}
