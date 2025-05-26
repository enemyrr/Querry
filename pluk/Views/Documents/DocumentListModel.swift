//
//  DocumentListModel.swift
//  Collection
//
//  Created by Fauzaan on 2/19/25.
//

import Foundation
import MongoKitten
import AIProxy
import SwiftUI

@Observable
class DocumentListModel {
    let instance: ConnectionInstance
    private let databaseService: DatabaseService?
    private let paginationManager: PaginationManager
    
    init(instance: ConnectionInstance, databaseService: DatabaseService?) {
        self.instance = instance
        self.databaseService = databaseService
        self.paginationManager = PaginationManager()
    }
    
    var lastFetchTimestamp: Date = Date()
    
    // UI States
    var action: ActionBar = ActionBar.main
    var formattedDocuments: [FormattedDocument] = []
    var isLoading = true
    var error: Error?
    var filterText = ""
    var showFilterEditor: Bool = false
    var actionBarUpdateTrigger = UUID()
    var loadingKeyValue: String?
    var intialLoadComplete: Bool = false
    var isLoadingAnimation: Bool = false
    
    // MARK: - Pagination Properties
    var currentPage: Int { paginationManager.currentPage }
    var totalPages: Int { paginationManager.totalPages }
    var totalItems: Int { paginationManager.totalItems }
    
    // MARK: - Document Management
    func loadDocuments(filter: Document = [:]) async {
        guard let databaseService = databaseService, let selectedTab = instance.selectedTab else {
            if databaseService == nil {
                error = MongoError.databaseNotInitialized
            } else {
                error = MongoError.collectionNotFound
            }
            return
        }
        
        await MainActor.run {
            self.error = nil
            self.intialLoadComplete = true
            self.isLoading = true
            self.isLoadingAnimation = true
        }
        
        do {
            // First get count with a lightweight query
            let count = try await databaseService.getDocumentCount(for: selectedTab.name)
            
            // Then load the actual documents
            let documents = try await databaseService.findDocuments(
                in: selectedTab.name,
                filter: filter,
                skip: paginationManager.skip,
                limit: paginationManager.limit
            )
            
            // Process documents in a background task to avoid blocking
            let formatted = await formatDocuments(documents)
            
            await MainActor.run {
                paginationManager.updateTotalItems(count)
                self.formattedDocuments = formatted
                self.lastFetchTimestamp = Date()
                self.isLoading = false
                
                // Instead of immediately setting isLoading to false,
                Task {
                    try? await Task.sleep(for: .seconds(1))
                    self.isLoadingAnimation = false
                }
            }
        } catch {
            print(error)
            await MainActor.run {
                self.error = error
                self.isLoading = false
            }
        }
    }
    
    // MARK: - Document Formatting
    private func formatDocuments(_ documents: [Document]) async -> [FormattedDocument] {
        let chunkSize = 10
        var formattedDocs: [FormattedDocument] = []
        
        for chunk in stride(from: 0, to: documents.count, by: chunkSize) {
            let end = min(chunk + chunkSize, documents.count)
            let documentChunk = Array(documents[chunk..<end])
            
            let formattedChunk = documentChunk.map { document in
                formatDocument(document)
            }
            
            formattedDocs.append(contentsOf: formattedChunk)
            await Task.yield()
        }
        
        return formattedDocs
    }
    
    private func formatDocument(_ document: Document) -> FormattedDocument {
        guard let id = document["_id"] as? ObjectId else {
            return FormattedDocument(id: "", fields: [], rawDocument: document)
        }
        
        let fields = document.keys.map { key in
            formatField(key: key, value: document[key])
        }
        
        return FormattedDocument(id: id.hexString, fields: fields, rawDocument: document)
    }
    
    private func formatField(key: String, value: Primitive?) -> FormattedDocument.FormattedField {
        let formatted = Document().formatValue(value)
        
        var nestedFields: [FormattedDocument.FormattedField]?
        if let doc = value as? Document {
            nestedFields = doc.keys.map { key in
                formatField(key: key, value: doc[key])
            }
        }
        
        return FormattedDocument.FormattedField(
            key: key,
            formattedValue: formatted,
            rawValue: value ?? "nil",
            nestedFields: nestedFields
        )
    }
    
    // MARK: - Pagination Methods
    func nextPage() {
        if paginationManager.nextPage() {
            updatePendingActionsState()
            Task {
                await loadDocuments()
            }
        }
    }
    
    func previousPage() {
        if paginationManager.previousPage() {
            updatePendingActionsState()
            Task {
                await loadDocuments()
            }
        }
    }
    
    func goToPage(_ page: Int) {
        if paginationManager.goToPage(page) {
            Task { await loadDocuments() }
        }
    }
    
    // MARK: - Pending Actions Management
    private(set) var pendingActions: [PendingDocumentAction] = []
    private(set) var isProcessingBatch = false
    
    func updatePendingActionsState() {
        actionBarUpdateTrigger = UUID()
    }
    
    func addPendingAction(documentId: String, action: DocumentAction) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.removePendingActionsInternal(for: documentId)
            let pendingAction = PendingDocumentAction(documentId: documentId, action: action)
            self.pendingActions.append(pendingAction)
        }
    }
    
    func removePendingActions(for documentId: String) {
        DispatchQueue.main.async { [weak self] in
            self?.removePendingActionsInternal(for: documentId)
        }
    }
    
    private func removePendingActionsInternal(for documentId: String) {
        pendingActions.removeAll { $0.documentId == documentId }
        updatePendingActionsState()
    }
    
    func updatePendingActionData(for documentId: String, updateData: String) {
        if let index = pendingActions.firstIndex(where: { $0.documentId == documentId }) {
            pendingActions[index].updateData = updateData
        }
    }
    
    func hasPendingAction(documentId: String, action: DocumentAction? = nil) -> Bool {
        if let action = action {
            return pendingActions.contains { $0.documentId == documentId && $0.action == action }
        } else {
            return pendingActions.contains { $0.documentId == documentId }
        }
    }
    
    func pendingActionsCount(for action: DocumentAction? = nil) -> Int {
        if let action = action {
            return pendingActions.filter { $0.action == action }.count
        } else {
            return pendingActions.count
        }
    }
    
    // MARK: - Commit Actions
    func commitPendingActions() async {
        guard !pendingActions.isEmpty, let databaseService = databaseService else { return }
        guard let databaseName = instance.selectedTab?.name else { return }
        
        isProcessingBatch = true
        defer { isProcessingBatch = false }
        
        var failedActions: [PendingDocumentAction] = []
        
        let deleteActions = pendingActions.filter { $0.action == .delete }
        let updateActions = pendingActions.filter { $0.action == .update }
        
        // Process deletions
        for action in deleteActions {
            do {
                guard let objectId = ObjectId(action.documentId) else {
                    failedActions.append(action)
                    continue
                }
                
                try await databaseService.deleteDocument(
                    from: databaseName,
                    withId: objectId
                )
                
                removePendingActions(for: action.documentId)
            } catch {
                failedActions.append(action)
                self.error = error
            }
        }
        
        // Process updates
        for action in updateActions {
            do {
                guard let objectId = ObjectId(action.documentId),
                      let updateData = action.updateData,
                      let document = try? Document(fromJSON: updateData) else {
                    failedActions.append(action)
                    continue
                }
                
                try await databaseService.updateDocument(
                    in: databaseName,
                    withId: objectId,
                    withData: document
                )
            } catch {
                failedActions.append(action)
                self.error = error
            }
        }
        
        await loadDocuments()
        
        await MainActor.run {
            self.pendingActions.removeAll()
        }
    }
}
