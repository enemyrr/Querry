//
//  DocumentRowViewModel.swift
//  Collection
//
//  Created by Fauzaan on 3/9/25.
//

import SwiftUI
import Observation
import MongoKitten
import UInt128

// MARK: - DocumentRowViewModel
@Observable class DocumentRowViewModel {
    let document: MongoKitten.Document.FormattedDocument
    let documentListViewModel: DocumentListModel
    
    var updatedDocument: Document
    
    // UI state
    @ObservationIgnored private var isExpanded = false
    @ObservationIgnored private var isLoading = false
    @ObservationIgnored private var errorMessage: String?
    var isDeleted = false
    
    init(document: MongoKitten.Document.FormattedDocument, documentListViewModel: DocumentListModel) {
        self.document = document
        self.documentListViewModel = documentListViewModel
        self.updatedDocument = document.rawDocument
    }
    
    // MARK: - Hover actions

    func togglePendingAction(_ action: DocumentAction?) {
        // Check current state from the source of truth
        let currentAction = getPendingAction()
        
        if currentAction == action {
            // Remove the action if it's the same (toggle off)
            documentListViewModel.removePendingActions(for: document.id)
        } else {
            // Set the new action
            documentListViewModel.addPendingAction(documentId: document.id, action: action ?? .update)
        }
    }
    

    
    var showCopyFeedback = false
    
    func getPendingAction() -> DocumentAction? {
        if documentListViewModel.hasPendingAction(documentId: document.id, action: .delete) {
            return .delete
        } else if documentListViewModel.hasPendingAction(documentId: document.id, action: .update) {
            return .update
        }
        
        return nil
    }
    
    
    func copyDocumentJSON() {
        let jsonString = document.rawDocument.jsonString
        
        // Copy to pasteboard
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(jsonString, forType: .string)
        
        showCopyFeedback = true
        Task {
            try? await Task.sleep(for: .seconds(1.5))
            showCopyFeedback = false
        }
    }
    
    private func getOriginalType(for key: String) -> Primitive? {
        if let field = document.fields.first(where: { $0.key == key }) {
            return field.rawValue
        }
        return nil
    }
    
    // MARK: - Document Edit
    var editingDocumentJSON: String = ""
    
    func getEditingJSON() -> String {
        return document.rawDocument.jsonString
    }
    
    func updateEditingDocumentJSON(_ updateData: String) {
        documentListViewModel.updatePendingActionData(for: document.id, updateData: updateData)
  }
}


public enum DocumentAction: String, CaseIterable {
    case delete
    case update
}

public struct PendingDocumentAction {
    let documentId: String
    let action: DocumentAction
    var updateData: String?
}
