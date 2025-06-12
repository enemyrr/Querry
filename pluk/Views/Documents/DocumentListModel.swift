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
    let databaseDriver: any DatabaseDriver
    var connectedDatabase: any DatabaseWrapper
    private let paginationManager: PaginationManager

    init(instance: ConnectionInstance, databaseDriver: any DatabaseDriver, connectedDatabase: any DatabaseWrapper) {
        self.instance = instance
        self.databaseDriver = databaseDriver
        self.paginationManager = PaginationManager()
        self.connectedDatabase = connectedDatabase
    }
    
    var lastFetchTimestamp: Date = Date()
    
    // UI States
//    var action: ActionBar = ActionBar.main
    var formattedDocuments: Any = []
    var rowDocuments: PostgreSQLQueryResult?;
    var isLoading = true
    var error: Error?
    var filterText = ""
    var showFilterEditor: Bool = false
    var actionBarUpdateTrigger = UUID()
    var loadingKeyValue: String?
    var intialLoadComplete: Bool = false
    var isLoadingAnimation: Bool = false
    
    // MARK: - Document Management
    func loadDocuments(filter: String = "") async {
        guard let selectedTab = instance.selectedTab else {
            error = MongoError.collectionNotFound
            return
        }
        
        await MainActor.run {
            self.error = nil
            self.intialLoadComplete = true
            self.isLoading = true
            self.isLoadingAnimation = true
        }
        
        do {
            let documents = try await databaseDriver.findDocuments(
                in: selectedTab.name,
                filter: ["rawQuery": filter],
                skip: paginationManager.skip,
                limit: paginationManager.limit
            ) as? PostgreSQLQueryResult
            
            await MainActor.run {
                self.paginationManager.updateTotalItems(documents?.totalCount ?? 0)
                self.rowDocuments = documents
                self.lastFetchTimestamp = Date()
                self.isLoading = false
                
                Task { @MainActor in
                    try? await Task.sleep(for: .milliseconds(800))
                    self.isLoadingAnimation = false
                }
            }
        } catch {
            print(error)
            await MainActor.run {
                self.error = error
                self.isLoading = false
                self.isLoadingAnimation = false
            }
        }
    }
    
    // MARK: - Pagination Methods
    func nextPage(filter: Document? = [:]) {
        if paginationManager.nextPage() {
            updatePendingActionsState()
            Task {
                if let filter = filter {
//                    await loadDocuments(filter: filter)
                } else {
                    await loadDocuments()
                }
            }
        }
    }
    
    func previousPage(filter: Document? = [:]) {
        if paginationManager.previousPage() {
            updatePendingActionsState()
            Task {
                if let filter = filter {
//                    await loadDocuments(filter: filter)
                } else {
                    await loadDocuments()
                }
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
//        guard !pendingActions.isEmpty, let databaseService = databaseService else { return }
//        guard let databaseName = instance.selectedTab?.name else { return }
//        
//        isProcessingBatch = true
//        defer { isProcessingBatch = false }
//        
//        var failedActions: [PendingDocumentAction] = []
//        
//        let deleteActions = pendingActions.filter { $0.action == .delete }
//        let updateActions = pendingActions.filter { $0.action == .update }
//        
//        // Process deletions
//        for action in deleteActions {
//            do {
//                guard let objectId = ObjectId(action.documentId) else {
//                    failedActions.append(action)
//                    continue
//                }
//                
//                try await databaseService.deleteDocument(
//                    from: databaseName,
//                    withId: objectId
//                )
//                
//                removePendingActions(for: action.documentId)
//            } catch {
//                failedActions.append(action)
//                self.error = error
//            }
//        }
//        
//        // Process updates
//        for action in updateActions {
//            do {
//                guard let objectId = ObjectId(action.documentId),
//                      let updateData = action.updateData,
//                      let document = try? Document(fromJSON: updateData) else {
//                    failedActions.append(action)
//                    continue
//                }
//                
//                try await databaseService.updateDocument(
//                    in: databaseName,
//                    withId: objectId,
//                    withData: document
//                )
//            } catch {
//                failedActions.append(action)
//                self.error = error
//            }
//        }
//        
//        await loadDocuments()
//        
//        await MainActor.run {
//            self.pendingActions.removeAll()
//        }
    }
}
