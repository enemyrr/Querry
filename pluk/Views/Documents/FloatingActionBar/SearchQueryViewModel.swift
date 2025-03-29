//
//  SearchQueryViewModel.swift
//  Collection
//
//  Created on 3/16/25.
//

import SwiftUI
import AIProxy
import Combine
import MongoKitten

// MARK: - Processing Stage Enum
/// Represents the different stages of query processing
public enum ProcessingStage: Int {
    case idle = 0
    case writingQuery = 1
    case fetchingData = 2
    
    var description: String {
        switch self {
        case .idle:
            return ""
        case .writingQuery:
            return "Writing query"
        case .fetchingData:
            return "Fetching data"
        }
    }
}

/// A shared ViewModel that handles both AI-powered search and query editing functionality
@Observable class SearchQueryViewModel {
    // Document ViewModel reference
    private let DocumentListModel: DocumentListModel
    
    // AI Query results
    var aiQueryResult: String = """
{
    "workspace": {
        "$eq": "some_workspace_id"
    },
    "action": {
        "$in": [
            "create",
            "update"
        ]
    },
    "createdAt": {
        "$gte": {
            "$date": "2023-01-01T00:00:00Z"
        }
    }
}
"""
    var lastQuery: String = ""
    
    // MARK: - Shared Properties
    
    /// Flag indicating if processing is in progress
    var isProcessing: Bool = false
    
    /// Current processing stage
    var processingStage: ProcessingStage = .idle
    
    /// Flag to show/hide the filter view
    var showFilterView: Bool = false
    
    // MARK: - AI Search Properties
    
    /// The natural language search query input by the user
    var search: String = ""
    
    /// The editable version of the filter for manual adjustments
    var editableFilter: String = ""
    
    /// Flag to show/hide search suggestions
    var showSuggestions: Bool = false
    
    /// Available filter suggestions based on current input
    var filterSuggestions: [FilterSuggestion] = []
    
    // MARK: - Query Editor Properties
    
    /// Flag to show the full query editor
    var isFullQueryEditorOpen: Bool = false
    
    /// The number of documents matching the current query
    var matchingDocumentsCount: Int = 0
    
    /// The time the query took to execute
    var queryExecutionTime: String = "0s"
    
    /// The last time the query was executed
    var lastQueryTime: String = ""
    
    // Private cancellables set
    private var cancellables = Set<AnyCancellable>()
    
    init(DocumentListModel: DocumentListModel) {
        self.DocumentListModel = DocumentListModel
        
        // Setup search text monitoring
//        $search
//            .debounce(for: .milliseconds(300), scheduler: RunLoop.main)
//            .sink { [weak self] text in
//                self?.updateFilterSuggestions(for: text)
//            }
//            .store(in: &cancellables)
    }
    
    // MARK: - Public Methods
    
    func goBack() {
        Task { @MainActor in
            withAnimation(.spring(response: 0.3)) {
                DocumentListModel.action = ActionBar.main
            }
        }
    }
    

    
    func submitDirectFilter() {
        guard !search.isEmpty && !isProcessing else { return }
        
        isProcessing = true
        showSuggestions = false
        
        Task {
            do {
                // Use the search directly as a filter
                try await Task.sleep(for: .milliseconds(600))
                
                await MainActor.run { [weak self] in
                    self?.isProcessing = false
                }
            } catch {
                await MainActor.run { [weak self] in
                    self?.isProcessing = false
                }
                print("Error during filter submission: \(error)")
            }
        }
    }
    
    func insertSuggestion(_ suggestion: FilterSuggestion) {
        if search.hasSuffix(" ") {
            search += suggestion.text
        } else {
            search += " " + suggestion.text
        }
        
        if ["author", "date", "extension", "shared"].contains(suggestion.text.lowercased()) {
            search += " = "
        }
        
        showSuggestions = false
    }
    
    // MARK: - AI Request Methods
    
    /// Submits a natural language query to AI service and processes the result
    func processNaturalLanguageQuery(search: String) async {
        guard !search.isEmpty else { return }
        
        // Update processing stage to writing query
        await MainActor.run { [weak self] in
            self?.isProcessing = true
            self?.processingStage = .writingQuery
            self?.lastQuery = search
        }
        
        do {
            let openAIService = AIProxy.openAIService(
                partialKey: "v2|3fe1f505|AS4tm59nSGxScFCN",
                serviceURL: "https://api.aiproxy.pro/4c1638f9/2f62a0df"
            )
            
            // Get a sample document for the AI to understand the schema
            var sampleDocument = Document()
            if let document = DocumentListModel.formattedDocuments.first?.rawDocument {
                sampleDocument = document
            }
        
            let stream = try await openAIService.streamingChatCompletionRequest(body: .init(
                model: "gpt-4o-mini",
                messages: [
                    .user(content: .text(search)),
                    .system(content: .text("You are a MongoDB query assistant. Your primary task is to convert natural language user queries into valid MongoDB filter queries in JSON format.\n\nCore Responsibilities:\n- Convert the user query into a MongoDB JSON filter query.\n- Return ONLY the MongoDB query in JSON format without explanation.\n- Optimize the query for best performance.\n- Support all MongoDB operators and query features.\n\n# MongoDB Schema Reference\n\n\(sampleDocument.keys.map { "\($0): \(type(of: sampleDocument[$0]!))" }.joined(separator: "\n"))\n\n# Output Format\n\n- Return ONLY the MongoDB query in JSON format.\n- Do not include any explanation, preamble, or commentary.\n- Format the query for readability with proper indentation.\n- One-line queries are acceptable for simple filters.\n\n# Examples\n\n**Example 1:**\n\n- **Input:** Find all users where age is greater than 30\n- **Output:**\n  ```json\n  {\n    \"age\": { \"$gt\": 30 }\n  }\n  ```\n\n**Example 2:**\n\n- **Input:** Get documents where status is active and created date is in the last week\n- **Output:**\n  ```json\n  {\n    \"status\": \"active\",\n    \"createdAt\": { \"$gt\": { \"$date\": \"2025-03-08T00:00:00Z\" } }\n  }\n  ```\n\n**Example 3:**\n\n- **Input:** Show me customers from New York or California with at least 5 orders\n- **Output:**\n  ```json\n  {\n    \"$and\": [\n      { \"$or\": [\n        { \"state\": \"New York\" },\n        { \"state\": \"California\" }\n      ]},\n      { \"orderCount\": { \"$gte\": 5 }\n    ]\n  }\n  ```\n\n# Notes\n\n- NEVER provide explanations or ask clarifying questions.\n- NEVER describe what the query does.\n- When user input is ambiguous, make reasonable assumptions about field names and data types.\n- Use appropriate MongoDB operators ($eq, $gt, $lt, $in, etc.) based on the query requirements."))
                ],
                responseFormat: .jsonObject
            ))
            
            // Use a local variable to collect the streaming content
            var fullQueryString = ""
            
            // Process the stream
            for try await chunk in stream {
                if let chunkContent = chunk.choices.first?.delta.content {
                    // Update the local variable
                    fullQueryString += chunkContent
                    
                    // Safely update the published property on the main thread
                    await MainActor.run { [weak self]in
                        self?.aiQueryResult = fullQueryString
                    }
                }
            }
            
            // All stream processing is complete at this point
            // Now process the final result on the main thread
            if !fullQueryString.isEmpty {
                // Update processing stage to fetching data
                await MainActor.run { [weak self] in
                    self?.processingStage = .fetchingData
                }
                
                let result = try convertJSONWithSpecialTypes(fullQueryString)
                await DocumentListModel.loadDocuments(filter: result)
                
                // Reset processing state and clear search field
                await MainActor.run { [weak self] in
                    self?.isProcessing = false
                    self?.processingStage = .idle
                    self?.search = ""
                }
            }
            
        } catch AIProxyError.unsuccessfulRequest(let statusCode, let responseBody) {
            await MainActor.run { [weak self] in
                print("Error: Received \(statusCode) status code with response body: \(responseBody)")
                self?.isProcessing = false
                self?.processingStage = .idle
            }
        } catch {
            await MainActor.run { [weak self] in
                print("Error: Could not create Message: \(error.localizedDescription)")
                self?.isProcessing = false
                self?.processingStage = .idle
            }
        }
    }
    
    /// Converts a JSON string to a MongoDB Document with proper type conversion
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
    
    /// Converts a Swift value to a MongoDB primitive type
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
    
    // MARK: - Private Methods
    
    private func updateFilterSuggestions(for input: String) {
        if input.isEmpty {
            showSuggestions = false
            return
        }
        
        let lowercasedInput = input.lowercased()
        var suggestions: [FilterSuggestion] = []
        
        if input.contains("=") || input.contains(">") || input.contains("<") {
            suggestions.append(FilterSuggestion(text: "true", description: "Boolean value", icon: "checkmark.circle", shortcut: ""))
            suggestions.append(FilterSuggestion(text: "false", description: "Boolean value", icon: "xmark.circle", shortcut: ""))
            suggestions.append(FilterSuggestion(text: "currentUser", description: "Current user ID", icon: "person", shortcut: ""))
        } else if lowercasedInput.hasSuffix(" and") || lowercasedInput.hasSuffix(" or") || input.hasSuffix(" ") {
            suggestions.append(FilterSuggestion(text: "author", description: "Document author", icon: "person.text.rectangle", shortcut: ""))
            suggestions.append(FilterSuggestion(text: "date", description: "Document creation date", icon: "calendar", shortcut: ""))
            suggestions.append(FilterSuggestion(text: "extension", description: "File extension", icon: "doc", shortcut: ""))
            suggestions.append(FilterSuggestion(text: "shared", description: "Sharing status", icon: "person.2", shortcut: ""))
        } else {
            suggestions.append(FilterSuggestion(text: "AND", description: "Logical AND operator", icon: "plus.square", shortcut: "&&"))
            suggestions.append(FilterSuggestion(text: "OR", description: "Logical OR operator", icon: "plus.square.fill", shortcut: "||"))
            suggestions.append(FilterSuggestion(text: "CONTAINS", description: "String contains value", icon: "text.magnifyingglass", shortcut: ""))
            suggestions.append(FilterSuggestion(text: "IN", description: "Value in collection", icon: "list.bullet", shortcut: ""))
        }
        
        filterSuggestions = suggestions
        showSuggestions = !suggestions.isEmpty
    }
    
    
    private func extractTechnicalFilter(from query: String) -> String {
        let lowercasedQuery = query.lowercased()
        
        if lowercasedQuery.contains("last month") {
            return "date >= startOfLastMonth AND date <= endOfLastMonth"
        } else if lowercasedQuery.contains("created by me") {
            return "author = 'currentUser'"
        } else if lowercasedQuery.contains("pdf") {
            return "extension = 'pdf'"
        } else if lowercasedQuery.contains("shared with") {
            return "shared = true"
        } else if lowercasedQuery.contains("important") {
            return "tags CONTAINS 'important'"
        } else {
            return "content CONTAINS '\(query)'"
        }
    }
    
    // MARK: - Query Editor Methods
    /// Close the full query editor view with animation
    func closeFullQueryEditor() {
        Task { @MainActor in
            // Only perform animation if the editor is currently open
            if isFullQueryEditorOpen {
                withAnimation(.spring(response: 0.15)) {
                    isFullQueryEditorOpen = false
                }
            }
        }
    }
    
    /// Open the full query editor view with animation
    func openFullQueryEditor() {
        Task { @MainActor in
            // Only perform animation if the editor is currently open
            if !isFullQueryEditorOpen {
                withAnimation(.spring(response: 0.15)) {
                    isFullQueryEditorOpen = true
                }
            }
        }
    }
    
    /// Execute the current query and update results
    func executeQuery() {
        guard !isProcessing else { return }
        
        isProcessing = true
        
        Task {
            do {
                // Simulate query execution
                try await Task.sleep(for: .milliseconds(600))
                
                // Update query stats
                await MainActor.run { [weak self] in
                    guard let self = self else { return }
                    self.matchingDocumentsCount = 2 // This would be the actual count from the query
                    self.queryExecutionTime = "0s"
                    self.lastQueryTime = "just now"
                    self.isProcessing = false
                }
            } catch {
                await MainActor.run { [weak self] in
                    self?.isProcessing = false
                }
                print("Error during query execution: \(error)")
            }
        }
    }
}
