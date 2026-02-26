import SwiftData
import SwiftUI

enum NotebookViewMode: String {
    case notebook
    case dashboard
}

@Observable
@MainActor
final class NotebookDataController {

    let notebookId: UUID
    let modelContainer: ModelContainer

    private(set) var notebook: Notebook?
    private(set) var connections: [Connection] = []
    private(set) var blocks: [NotebookBlock] = []
    var isRightSidebarVisible = false
    var viewMode: NotebookViewMode = .notebook
    var isScrolled = false

    private var chartViewModels: [UUID: ChartBlockViewModel] = [:]

    var hasBlocks: Bool { !blocks.isEmpty }

    var isPublished: Bool {
        get { notebook?.isPublished ?? false }
        set {
            notebook?.isPublished = newValue
            notebook?.updatedAt = Date()
            save()
        }
    }

    var isDashboardPublished: Bool {
        viewMode == .dashboard && isPublished
    }

    var dashboardBlocks: [NotebookBlock] {
        blocks.filter { !$0.isHiddenInDashboard }
    }

    func publishDashboard() {
        isPublished = true
        isRightSidebarVisible = false
    }

    func unpublishDashboard() {
        isPublished = false
    }

    func toggleBlockDashboardVisibility(_ block: NotebookBlock) {
        block.isHiddenInDashboard.toggle()
        block.updatedAt = Date()
        save()
    }

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

        let blockDescriptor = FetchDescriptor<NotebookBlock>(
            predicate: #Predicate { $0.notebookId == id },
            sortBy: [SortDescriptor(\.sortOrder)]
        )
        blocks = (try? context.fetch(blockDescriptor)) ?? []
    }

    func addChartBlock() {
        addBlock(type: .chart)
    }

    func insertChartBlock(at index: Int) {
        insertBlock(type: .chart, at: index)
    }

    func addTextBlock() {
        addBlock(type: .text)
    }

    func insertTextBlock(at index: Int) {
        insertBlock(type: .text, at: index)
    }

    private func addBlock(type: NotebookBlockType) {
        guard let notebook else { return }
        let nextOrder = (blocks.map(\.sortOrder).max() ?? -1) + 1
        let block = NotebookBlock(notebookId: notebook.id, blockType: type, sortOrder: nextOrder)
        modelContainer.mainContext.insert(block)
        blocks.append(block)
        save()
    }

    private func insertBlock(type: NotebookBlockType, at index: Int) {
        guard let notebook else { return }
        let block = NotebookBlock(notebookId: notebook.id, blockType: type, sortOrder: index)
        modelContainer.mainContext.insert(block)
        blocks.insert(block, at: index)
        reindexSortOrders()
        save()
    }

    func chartViewModel(for block: NotebookBlock) -> ChartBlockViewModel {
        if let existing = chartViewModels[block.id] {
            return existing
        }
        let vm = ChartBlockViewModel(block: block, dataController: self)
        chartViewModels[block.id] = vm
        return vm
    }

    func deleteBlock(_ block: NotebookBlock) {
        chartViewModels.removeValue(forKey: block.id)
        modelContainer.mainContext.delete(block)
        blocks.removeAll { $0.id == block.id }
        reindexSortOrders()
        save()
    }

    func duplicateBlock(_ block: NotebookBlock) {
        guard let index = blocks.firstIndex(where: { $0.id == block.id }) else { return }
        guard let notebook else { return }
        let newBlock = NotebookBlock(notebookId: notebook.id, blockType: block.blockType, sortOrder: index + 1)
        newBlock.configJSON = block.configJSON
        newBlock.blockHeight = block.blockHeight
        modelContainer.mainContext.insert(newBlock)
        blocks.insert(newBlock, at: index + 1)
        reindexSortOrders()
        save()
    }

    func moveBlockUp(_ block: NotebookBlock) {
        guard let index = blocks.firstIndex(where: { $0.id == block.id }), index > 0 else { return }
        blocks.swapAt(index, index - 1)
        reindexSortOrders()
        save()
    }

    func moveBlockDown(_ block: NotebookBlock) {
        guard let index = blocks.firstIndex(where: { $0.id == block.id }), index < blocks.count - 1 else { return }
        blocks.swapAt(index, index + 1)
        reindexSortOrders()
        save()
    }

    func moveBlock(from sourceIndex: Int, to destinationIndex: Int) {
        guard sourceIndex != destinationIndex,
              sourceIndex >= 0, sourceIndex < blocks.count,
              destinationIndex >= 0, destinationIndex <= blocks.count else { return }
        let block = blocks.remove(at: sourceIndex)
        let insertIndex = destinationIndex > sourceIndex ? destinationIndex - 1 : destinationIndex
        blocks.insert(block, at: min(insertIndex, blocks.count))
        reindexSortOrders()
        save()
    }

    func updateBlock(_ block: NotebookBlock) {
        block.updatedAt = Date()
        save()
    }

    private func reindexSortOrders() {
        for (i, block) in blocks.enumerated() {
            block.sortOrder = i
        }
    }

    private func save() {
        try? modelContainer.mainContext.save()
    }
}
