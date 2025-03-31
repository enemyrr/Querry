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
    
    func updateField(key: String, value: String) {
        let originalValue = getOriginalType(for: key)
        let primitiveValue = convertStringToPrimitive(value, matchingType: originalValue)
        
        var documentCopy = document.rawDocument
        documentCopy[key] = primitiveValue
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
            // Integer types
        case is Int32:
            return Int32(string)
        case is Int, is Int64:
            return Int(string)
            
        case is Double:
            return Double(string)
            //        case is Decimal128:
            //            return Decimal128(string) ?? Decimal128("0")
            //
        case is Bool:
            return ["true", "yes", "1", "on"].contains(string.lowercased())
            
        case is Date:
            // Try various date formats
            let iso8601Formatter = ISO8601DateFormatter()
            if let date = iso8601Formatter.date(from: string) {
                return date
            }
            
            let dateFormatter = DateFormatter()
            // Try common formats
            for format in ["yyyy-MM-dd", "MM/dd/yyyy", "dd/MM/yyyy", "yyyy-MM-dd'T'HH:mm:ss", "yyyy-MM-dd HH:mm:ss"] {
                dateFormatter.dateFormat = format
                if let date = dateFormatter.date(from: string) {
                    return date
                }
            }
            
            return Date()
            
        case is ObjectId:
            return try? ObjectId(string)
            
            //        case is Document where original is [Primitive]:
            //            if let data = string.data(using: .utf8),
            //               let jsonArray = try? JSONSerialization.jsonObject(with: data) as? [Any] {
            //                return jsonArray.map { item in
            //                    if let stringItem = item as? String {
            //                        return stringItem
            //                    }
            //                    return String(describing: item)
            //                } as Document
            //            }
            //            // Fallback: parse as comma-separated values
            //            return string.split(separator: ",")
            //                .map { String($0.trimmingCharacters(in: .whitespacesAndNewlines)) } as Document
            
            // Document/Object
        case is Document:
            if let data = string.data(using: .utf8),
               let jsonObject = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                var document = Document()
                for (key, value) in jsonObject {
                    document[key] = String(describing: value)
                }
                return document
            }
            return Document() // Empty document as fallback
            
            // RegularExpression
        case is RegularExpression:
            return RegularExpression(pattern: string, options: "")
            
            //        case is Timestamp:
            //            if let timestamp = UInt32(string) {
            //                return Timestamp(timestamp: timestamp, increment: 0)
            //            }
            //            return Timestamp()
            
            // MinKey & MaxKey
        case is MinKey:
            return MinKey()
        case is MaxKey:
            return MaxKey()
            
            // Null
        case is Null:
            return Null()
            
            //        case is JavaScriptCode:
            //            return JavaScriptCode(code: string)
            //        case is JavaScriptCodeWithScope:
            //            return JavaScriptCodeWithScope(code: string, scope: [:])
            
            // Default - keep as string
        default:
            return string
        }
    }
    
    // MARK: - Document Edit
    var jsonDocument = ""
    
    func getEditingJSON() -> String {
        do {
            print("calling json")
            let jsonString = document.rawDocument.jsonString
//            let jsonData = try.mongoShell
            
//            guard let jsonString = String(data: jsonData, encoding: .utf8) else {
//                print("Failed to convert JSON data to string")
//                return ""
//            }
            
            return jsonString
        } catch {
            print("Error converting document to JSON: \(error)")
            return ""
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
