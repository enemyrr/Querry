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

@Observable class DocumentListModel {
    let instance: ConnectionInstance
    let selectedTab: DatabaseTab
    
    var lastFetchTimestamp: Date = Date()
    
    // Pagination state
    private(set) var currentPage: Int = 1
    @ObservationIgnored private(set) var itemsPerPage: Int = 25
    private(set) var totalItems: Int = 0
    
    // UI States
    var action: ActionBar = ActionBar.main
    
    // Computed property for total pages
    var totalPages: Int {
        return max(1, Int(ceil(Double(totalItems) / Double(itemsPerPage))))
    }
    
    private(set) var formattedDocuments: [FormattedDocument] = []
    private(set) var isLoading = false
    private(set) var error: Error?
    var filterText = "" // Add this
    var actionBarUpdateTrigger = UUID()
    
    struct PendingDocumentAction {
        let documentId: String
        let action: DocumentAction
        var updateData: Document?
    }
    
    var pendingActions: [PendingDocumentAction] = []
    private(set) var isProcessingBatch = false
    
    init(instance: ConnectionInstance, selectedTab: DatabaseTab) {
        self.instance = instance
        self.selectedTab = selectedTab
    }
    
    // MARK: - Documents
    func loadDocuments(filter: Document = [:]) async {
        // Start loading indicator
        await MainActor.run {
            isLoading = true
        }
        
        defer {
            // Ensure loading indicator is turned off on main thread
            Task { @MainActor in
                isLoading = false
            }
        }
        
        do {
            // Perform database operations on background thread
            let count = try await instance.getDocumentCount(for: selectedTab.name)
            let skip = (currentPage - 1) * itemsPerPage
            
            let queryBuilder = try instance.findQueryBuilder(from: selectedTab.name, filter: filter)
                .skip(skip)
                .limit(itemsPerPage)
            
            // Create and populate the documents array
            var documents: [Document] = []
            for try await document in queryBuilder {
                documents.append(document)
            }
            
            // Format documents (can remain on background thread)
            let formatted = await formatDocuments(documents)
            
            // Create a copy of documents to safely pass to the MainActor
            let documentsCopy = documents
            
            
            // Update UI state on main thread
            await MainActor.run {
                self.totalItems = count
                self.formattedDocuments = formatted
                self.lastFetchTimestamp = Date()
                instance.storeDocumentsForTab(tab: selectedTab, documents: documentsCopy)
            }
        } catch {
            // Handle error on main thread
            await MainActor.run {
                self.error = error
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
    
    // MARK: - Pagination
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

    
    func updatePendingActionsState() {
        actionBarUpdateTrigger = UUID()
    }
    
    func updateFilteredDocuments() {}
    
    // MARK: - Document Action Methods
    func addPendingAction(documentId: String, action: DocumentAction, updateData: Document? = nil) {
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
    
    func updatePendingActionData(for documentId: String, updateData: Document) {
        // Use DispatchQueue.main.async to avoid publishing changes during view updates
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            // Find the index of the existing pending action for this document
            if let index = self.pendingActions.firstIndex(where: { $0.documentId == documentId }) {
                self.pendingActions[index].updateData = updateData
            }
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
                
                removePendingActions(for: action.documentId)
            } catch {
                failedActions.append(action)
                self.error = error
            }
        }
        
        for action in updateActions {
              do {
                  // Parse the document ID
                  guard let objectId = ObjectId(action.documentId) else {
                      failedActions.append(action)
                      continue
                  }
                  
                  // Check if we have update data
                  guard let updateData = action.updateData else {
                      failedActions.append(action)
                      continue
                  }
                  
                  
                  // Perform update
                  try await instance.updateDocument(
                    fromCollection: selectedTab.name,
                    withId: objectId,
                    withData: updateData
                  )
              } catch {
                  failedActions.append(action)
                  self.error = error
              }
          }
        
        // Reload documents to reflect changes
        await loadDocuments()
        
        await MainActor.run {
            self.pendingActions.removeAll()
        }
    }
}
