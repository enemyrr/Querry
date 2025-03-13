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
    
    // Optional callback for notifying parent after operations
    var onDocumentChanged: (() -> Void)?
    
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
    
    func deleteDocument() async {
        guard let connectionInstance = connectionInstance,
              let collectionName = collectionName else {
            errorMessage = "Cannot delete document: connection information missing"
            return
        }
        
        isLoading = true
        defer { isLoading = false }
        
        do {
            // Parse the document ID (assuming it's an ObjectId)
            guard let objectId = try? ObjectId(document.id) else {
                errorMessage = "Invalid document ID format"
                return
            }
            
            // Perform deletion
//            try await connectionInstance.deleteDocument(
//                fromCollection: collectionName,
//                withId: objectId
//            )
            
            // Notify parent that a document was deleted
            onDocumentChanged?()
        } catch {
            errorMessage = "Failed to delete document: \(error.localizedDescription)"
        }
    }
    
    func editDocument() {
        // This would navigate to edit view or trigger edit mode
        // Implementation depends on your navigation architecture
    }
}
