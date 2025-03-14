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
@Observable
class DocumentRowViewModel {
    // Document data
    private(set) var document: FormattedDocument
    private let connectionInstance: ConnectionInstance?
    private let collectionName: String?
    
    // UI state
    private(set) var isExpanded = false
    private(set) var isLoading = false
    private(set) var errorMessage: String?
    private(set) var showCopyFeedback = false
    private(set) var isDeleted = false
    private(set) var pendingAction: DocumentViewModel.DocumentAction? = nil
    
    // Optional callback for notifying parent after operations
    var onDocumentChanged: ((DocumentViewModel.DocumentAction?) -> Void)?
    
    init(document: FormattedDocument, connectionInstance: ConnectionInstance? = nil, collectionName: String? = nil) {
        self.document = document
        self.connectionInstance = connectionInstance
        self.collectionName = collectionName
    }
    
    // MARK: - User Actions
    
    func toggleExpanded() {
        isExpanded.toggle()
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
    
    private func createJSONString() -> String {
        // Implement JSON formatting logic here
        // This is a simplified example
        return "{\n  \"_id\": \"\(document.id)\"\n  // Other fields would be here\n}"
    }
    
    // Removed hideActionConfirmation method as it's no longer needed
    
    func setPendingAction(_ action: DocumentViewModel.DocumentAction?) {
        // If the same action is already set, toggle it off (remove it)
        if pendingAction == action {
            pendingAction = nil
        } else {
            pendingAction = action
        }
        
        // Notify parent about the action change
        onDocumentChanged?(pendingAction)
    }
    
    func clearPendingAction() {
        pendingAction = nil
        
        // Notify parent that action was cleared
        onDocumentChanged?(nil)
    }
    
    func togglePendingAction(_ action: DocumentViewModel.DocumentAction) {
        if pendingAction == action {
            pendingAction = nil
        } else {
            pendingAction = action
        }
        
        // Notify parent about the action change
        onDocumentChanged?(pendingAction)
    }
    
    func executeAction() async {
        guard let connectionInstance = connectionInstance,
              let collectionName = collectionName,
              let action = pendingAction else {
            errorMessage = "Cannot execute action: missing information"
            return
        }
        
        isLoading = true
        defer { isLoading = false }
        
        do {
            // Parse the document ID (assuming it's an ObjectId)
            guard let objectId = ObjectId(document.id) else {
                errorMessage = "Invalid document ID format"
                return
            }
            
            switch action {
            case .delete:
                // Perform deletion
                try await connectionInstance.deleteDocumentBy(
                    fromCollection: collectionName,
                    withId: objectId
                )
                isDeleted = true
                
            case .update:
                // Placeholder for update functionality
                // Will be implemented in the future
                errorMessage = "Update functionality not yet implemented"
                return
            }
            
            // Clear the pending action after successful execution
            pendingAction = nil

            // Notify parent that the action was executed
            onDocumentChanged?(nil)
        } catch {
            errorMessage = "Failed to execute \(action) action: \(error.localizedDescription)"
        }
    }
    
    func editDocument() {
        // This would navigate to edit view or trigger edit mode
        // Implementation depends on your navigation architecture
    }
}
