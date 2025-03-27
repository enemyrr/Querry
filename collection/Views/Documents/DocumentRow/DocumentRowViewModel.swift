//
//  DocumentRowViewModel.swift
//  Collection
//
//  Created by Fauzaan on 3/9/25.
//

import SwiftUI
import Observation
import MongoKitten

// MARK: - DocumentRowViewModel
@Observable class DocumentRowViewModel {
    let document: FormattedDocument
    let documentListViewModel: DocumentListModel
    
    var updatedDocument: Document

    // UI state
    @ObservationIgnored private var isExpanded = false
    @ObservationIgnored private var isLoading = false
    @ObservationIgnored private var errorMessage: String?
    var isDeleted = false
    
    init(document: FormattedDocument, documentListViewModel: DocumentListModel) {
        self.document = document
        self.documentListViewModel = documentListViewModel
        self.updatedDocument = document.rawDocument
    }
    
    // MARK: - User Actions
    
    func togglePendingAction(_ action: DocumentAction?) {
           // Check current state from the source of truth
           let currentAction = getPendingAction()
           
           if currentAction == action {
               // Remove the action if it's the same (toggle off)
               documentListViewModel.removePendingActions(for: document.id)
           } else {
               // Set the new action
               documentListViewModel.addPendingAction(documentId: document.id, action: action ?? .update, updateData: updatedDocument)
           }
       }
    
    func toggleExpanded() {
        isExpanded.toggle()
    }
    
    // MARK: - Hover actions
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
        do {
            // First, get the JSON data
            let jsonData = try document.rawDocument.documentToJSON(document.rawDocument)
            
            // Convert the JSON data to a string
            guard let jsonString = String(data: jsonData, encoding: .utf8) else {
                print("Failed to convert JSON data to string")
                return
            }
            
            // Copy to pasteboard
            let pasteboard = NSPasteboard.general
            pasteboard.clearContents()
            pasteboard.setString(jsonString, forType: .string)
            
            showCopyFeedback = true
            Task {
                try? await Task.sleep(for: .seconds(1.5))
                showCopyFeedback = false
            }
        } catch {
            print("Error converting document to JSON: \(error)")
        }
    }
    
    func updateField(key: String, value: String) {
        var documentCopy = document.rawDocument
        documentCopy[key] = value
        documentListViewModel.updatePendingActionData(for: document.id, updateData: documentCopy)
    }
    
    private func getOriginalType(for key: String) -> Primitive? {
        if let field = document.fields.first(where: { $0.key == key }) {
            return field.rawValue
        }
        return nil
    }
    
    private func convertStringToPrimitive(_ string: String, matchingType original: Primitive?) -> Primitive? {
        guard let original = original else { return string }
        
        switch original {
        case is Int32:
            return Int32(string)
        case is Int:
            return Int(string)
        case is Double:
            return Double(string)
        case is Bool:
            return string.lowercased() == "true"
        case is Date:
            // Simple date parsing - you might need a more sophisticated approach
            let formatter = ISO8601DateFormatter()
            return formatter.date(from: string) ?? Date()
        case is ObjectId:
            return ObjectId(string)
        default:
            return string
        }
    }
}


public enum DocumentAction: String, CaseIterable {
    case delete
    case update
}

public struct PendingDocumentAction {
    let documentId: String
    let action: DocumentAction
    var updateData: [String: Any]?
}
