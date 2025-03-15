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
    @Published var action: ActionBar = ActionBar.main
    
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
    
    // MARK: - AI Request Methods
    @Published var erorrs: String?
    @Published var isAILoading: Bool = false
    
    func submitAIRequest(search: String) async {
        guard !search.isEmpty else { return }
        
        isAILoading = true
        var sampleDocument = Document()
        
        do {
            let openAIService = AIProxy.openAIService(
                partialKey: "v2|3fe1f505|AS4tm59nSGxScFCN",
                serviceURL: "https://api.aiproxy.pro/4c1638f9/2f62a0df"
            )
            
            if let document = formattedDocuments.first?.rawDocument {
                sampleDocument = document
            }
            
            let response = try await openAIService.chatCompletionRequest(body: .init(
                model: "gpt-4o-mini",
                messages: [
                    .user(content: .text(search)),
                    .system(content: .text("You are a MongoDB query assistant. Your primary task is to convert natural language user queries into valid MongoDB filter queries in JSON format.\n\nCore Responsibilities:\n- Convert the user query into a MongoDB JSON filter query.\n- Return ONLY the MongoDB query in JSON format without explanation.\n- Optimize the query for best performance.\n- Support all MongoDB operators and query features.\n\n# MongoDB Schema Reference\n\n\(sampleDocument.keys.map { "\($0): \(type(of: sampleDocument[$0]!))" }.joined(separator: "\n"))\n\n# Output Format\n\n- Return ONLY the MongoDB query in JSON format.\n- Do not include any explanation, preamble, or commentary.\n- Format the query for readability with proper indentation.\n- One-line queries are acceptable for simple filters.\n\n# Examples\n\n**Example 1:**\n\n- **Input:** Find all users where age is greater than 30\n- **Output:**\n  ```json\n  {\n    \"age\": { \"$gt\": 30 }\n  }\n  ```\n\n**Example 2:**\n\n- **Input:** Get documents where status is active and created date is in the last week\n- **Output:**\n  ```json\n  {\n    \"status\": \"active\",\n    \"createdAt\": { \"$gt\": { \"$date\": \"2025-03-08T00:00:00Z\" } }\n  }\n  ```\n\n**Example 3:**\n\n- **Input:** Show me customers from New York or California with at least 5 orders\n- **Output:**\n  ```json\n  {\n    \"$and\": [\n      { \"$or\": [\n        { \"state\": \"New York\" },\n        { \"state\": \"California\" }\n      ]},\n      { \"orderCount\": { \"$gte\": 5 }\n    ]\n  }\n  ```\n\n# Notes\n\n- NEVER provide explanations or ask clarifying questions.\n- NEVER describe what the query does.\n- When user input is ambiguous, make reasonable assumptions about field names and types.\n- Assume referenced fields are available due to the dynamic schema nature of MongoDB.\n- For dates, use the MongoDB extended JSON format with \"$date\" fields.\n- If a query cannot be created, return \"Invalid query\" without explanation.\n\nMongoDB JSON Query Syntax Guidelines:\n- Simple equality: `{ \"fieldName\": value }`\n- Comparison operators: `{ \"fieldName\": { \"$gt\": value } }`, `{ \"fieldName\": { \"$lt\": value } }`, etc.\n- Logical operators: `{ \"$and\": [...] }`, `{ \"$or\": [...] }`, `{ \"$not\": {...} }`\n- Array operators: `{ \"fieldName\": { \"$in\": [...] } }`, `{ \"fieldName\": { \"$all\": [...] } }`, `{ \"fieldName\": { \"$elemMatch\": {...} } }`\n- Text search: `{ \"$text\": { \"$search\": \"search string\" } }`\n- Regular expressions: `{ \"fieldName\": { \"$regex\": \"pattern\", \"$options\": \"options\" } }`\n- Geospatial: `{ \"$near\": {...} }`, `{ \"$geoWithin\": {...} }`\n- Dates: `{ \"createdAt\": { \"$gt\": { \"$date\": \"2025-03-08T00:00:00Z\" } } }`"))
                ],
                responseFormat: .jsonObject
            ))
            
            await MainActor.run {
                isAILoading = false
            }
            
            if let queryString = response.choices.first?.message.content {
                NSLog(queryString)
                let result = try convertJSONWithSpecialTypes(queryString)
                await loadDocuments(filter: result)
            }
        } catch AIProxyError.unsuccessfulRequest(let statusCode, let responseBody) {
            await MainActor.run {
                erorrs = "Error: Received \(statusCode) status code with response body: \(responseBody)"
                isAILoading = false
            }
        } catch {
            await MainActor.run {
                erorrs = "Error: Could not create Meesage: \(error.localizedDescription)"
                isAILoading = false
            }
        }
    }
    
    func convertJSONWithSpecialTypes(_ jsonString: String) throws -> Document {
        guard let jsonData = jsonString.data(using: .utf8) else {
            throw NSError(domain: "JSONParsingError", code: 0, userInfo: nil)
        }
        
        let jsonDict = try! JSONSerialization.jsonObject(with: jsonData, options: []) as! [String: Any]
        
        // Create an empty document
        var document = Document()
        
        // Add each key-value pair to the document with proper type conversion
        for (key, value) in jsonDict {
            if let convertedValue = convertToBSONPrimitive(value) {
                document[key] = convertedValue
            }
        }
        
        // Now 'document' is your MongoKitten Document
        let result: Document = document
        return result
    }
    
    func convertToBSONPrimitive(_ value: Any) -> (any Primitive)? {
        switch value {
        case let string as String:
            return string
        case let int as Int:
            return Int32(int) // Use Int32 instead of Int64
        case let double as Double:
            return double
        case let bool as Bool:
            return bool
        case let date as Date:
            return date
            //        case let array as [Any]:
            //            // Convert array elements to primitive types
            //            let primitiveArray = array.compactMap { convertToBSONPrimitive($0) }
            //            return primitiveArray
        case let dict as [String: Any]:
            var subdoc = Document()
            for (k, v) in dict {
                if let converted = convertToBSONPrimitive(v) {
                    subdoc[k] = converted
                }
            }
            return subdoc
        case is NSNull:
            return nil // Use nil instead of Null() if that's causing issues
        default:
            return nil
        }
    }
    
}
