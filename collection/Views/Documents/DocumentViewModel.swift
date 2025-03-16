//
//  DocumentViewModel.swift
//  Collection
//
//  Created by Fauzaan on 2/19/25.
//

import Foundation
import MongoKitten
import AIProxy
import SwiftUI

@MainActor
class DocumentViewModel: ObservableObject {
    let instance: ConnectionInstance
    let selectedTab: DatabaseTab
    
    // Pagination state
    @Published private(set) var currentPage: Int = 1
    @Published private(set) var itemsPerPage: Int = 25
    @Published private(set) var totalItems: Int = 0
    
    // UI States
    @Published var action: ActionBar = ActionBar.search
    
    // Computed property for total pages
    var totalPages: Int {
        return max(1, Int(ceil(Double(totalItems) / Double(itemsPerPage))))
    }
    
    @Published private(set) var formattedDocuments: [FormattedDocument] = []
    @Published private(set) var isLoading = false
    @Published private(set) var error: Error?
    @Published var filterText = "" // Add this
    @Published var actionBarUpdateTrigger = UUID()
    
    // Action tracking
    enum DocumentAction: String, CaseIterable {
        case delete
        case update
        // Add more actions in the future as needed
    }
    
    struct PendingDocumentAction {
        let documentId: String
        let action: DocumentAction
        var updateData: [String: Any]? // For update actions
    }
    
    @Published private(set) var pendingActions: [PendingDocumentAction] = []
    @Published private(set) var isProcessingBatch = false
    
    // AI-related properties (accessible to SearchQueryViewModel)
    @Published var isAILoading: Bool = false
    
    init(instance: ConnectionInstance, selectedTab: DatabaseTab) {
        self.instance = instance
        self.selectedTab = selectedTab
    }
    
    func loadDocuments(filter: Document = [:]) async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            // First get the total count for pagination
            totalItems = try await instance.getDocumentCount(for: selectedTab.name)
            
            // Calculate skip based on current page
            let skip = (currentPage - 1) * itemsPerPage
            
            // Get query builder with filter (if provided) and apply pagination
            let queryBuilder = try instance.findQueryBuilder(from: selectedTab.name, filter: filter)
                .skip(skip)
                .limit(itemsPerPage)
            
            var loadedDocuments: [Document] = []
            
            for try await document in queryBuilder {
                loadedDocuments.append(document)
            }
            
            let formatted = await formatDocuments(loadedDocuments)
            self.formattedDocuments = formatted
            instance.cacheDouments(tab: selectedTab, documents: loadedDocuments)
        } catch {
            self.error = error
        }
    }
    
    func nextPage() {
        if currentPage < totalPages {
            currentPage += 1
            updatePendingActionsState()
            Task {
                await loadDocuments()
            }
        }
    }
    
    func previousPage() {
        if currentPage > 1 {
            currentPage -= 1
            updatePendingActionsState()
            Task {
                await loadDocuments()
            }
        }
    }
    
    func goToPage(_ page: Int) {
        if page >= 1 && page <= totalPages {
            currentPage = page
            Task {
                await loadDocuments()
            }
        }
    }
    
    private func formatDocuments(_ documents: [Document]) async -> [FormattedDocument] {
        let chunkSize = 50
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
        let id = (document["_id"] as? ObjectId)?.hexString ?? UUID().uuidString
        let fields = document.keys.sorted().map { key in
            formatField(key: key, value: document[key])
        }
        
        return FormattedDocument(id: id, fields: fields, rawDocument: document)
    }
    
    private func formatField(key: String, value: Primitive?) -> FormattedDocument.FormattedField {
        let formatted = Document().formatValue(value)
        
        var nestedFields: [FormattedDocument.FormattedField]?
        if let doc = value as? Document {
            nestedFields = doc.keys.sorted().map { key in
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
    
    func updatePendingActionsState() {
        actionBarUpdateTrigger = UUID()
    }
    
    func updateFilteredDocuments() {}
    
    // MARK: - Document Action Methods
    func addPendingAction(documentId: String, action: DocumentAction, updateData: [String: Any]? = nil) {
        // Use DispatchQueue.main.async to avoid publishing changes during view updates
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            // Remove any existing actions for this document first
            self.removePendingActionsInternal(for: documentId)
            
            // Add the new action
            let pendingAction = PendingDocumentAction(
                documentId: documentId,
                action: action,
                updateData: updateData
            )
            self.pendingActions.append(pendingAction)
        }
    }
    
    func removePendingActions(for documentId: String) {
        // Use DispatchQueue.main.async to avoid publishing changes during view updates
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.removePendingActionsInternal(for: documentId)
        }
    }
    
    // Internal helper method to avoid code duplication
    private func removePendingActionsInternal(for documentId: String) {
        pendingActions.removeAll { $0.documentId == documentId }
        updatePendingActionsState()
    }
    
    func hasPendingAction(documentId: String, action: DocumentAction? = nil) -> Bool {
        if let action = action {
            return pendingActions.contains { $0.documentId == documentId && $0.action == action }
        } else {
            return pendingActions.contains { $0.documentId == documentId }
        }
    }
    
    func clearAllPendingActions() {
        // Use DispatchQueue.main.async to avoid publishing changes during view updates
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.pendingActions.removeAll()
        }
    }
    
    func pendingActionsCount(for action: DocumentAction? = nil) -> Int {
        if let action = action {
            return pendingActions.filter { $0.action == action }.count
        } else {
            return pendingActions.count
        }
    }
    
    func commitPendingActions() async {
        guard !pendingActions.isEmpty else { return }
        
        isProcessingBatch = true
        defer { isProcessingBatch = false }
        
        var failedActions: [PendingDocumentAction] = []
        
        // Group actions by type for batch processing
        let deleteActions = pendingActions.filter { $0.action == .delete }
        let updateActions = pendingActions.filter { $0.action == .update }
        
        // Process deletions
        for action in deleteActions {
            do {
                // Parse the document ID (assuming it's an ObjectId)
                guard let objectId = ObjectId(action.documentId) else {
                    failedActions.append(action)
                    continue
                }
                
                // Perform deletion
                try await instance.deleteDocumentBy(
                    fromCollection: selectedTab.name,
                    withId: objectId
                )
            } catch {
                failedActions.append(action)
                self.error = error
            }
        }
        
        // Process updates (placeholder for future implementation)
        for action in updateActions {
            // Implement update logic when needed
            // This is a placeholder for future functionality
            failedActions.append(action)
        }
        
        // Keep only the failed actions
        pendingActions = failedActions
        
        // Reload documents to reflect changes
        await loadDocuments()
    }
}
