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
    private let documentListModel: DocumentListModel
    
    var defaultQuery: String = """
{
    
}
"""
    var query: String = """
{
    
}
"""
    var lastQuery: String = ""
    
    // MARK: - Shared Properties
    
    /// Current processing stage
    var processingStage: ProcessingStage = .idle
    
    // MARK: - AI Search Properties
    
    /// The natural language search query input by the user
    var search: String = ""
    
    var showQueryEditor: Bool = false
    var showCreateDocumentSheet: Bool = false
    
    init(documentListModel: DocumentListModel) {
        self.documentListModel = documentListModel
    }
    
    // MARK: - Public Methods
    
    func goBack() {
        Task { @MainActor in
            withAnimation(.spring(response: 0.3)) {
                documentListModel.action = ActionBar.main
            }
        }
    }
    
    // MARK: - AI Request Methods
    /// Submits a natural language query to AI service and processes the result
    func processNaturalLanguageQuery(search: String) async {
        guard !search.isEmpty else { return }
        
        // Update processing stage to writing query
        await MainActor.run { [weak self] in
            self?.processingStage = .writingQuery
            self?.lastQuery = search
        }
        
        do {
            await MainActor.run { [weak self] in
                self?.query = ""
            }
            
            let openAIService = AIProxy.openAIService(
                partialKey: "v2|3fe1f505|AS4tm59nSGxScFCN",
                serviceURL: "https://api.aiproxy.pro/4c1638f9/2f62a0df"
            )
            
            // Get schema for the AI to understand the table structure
            var schema = "No schema available"
            if let selectedTable = documentListModel.instance.selectedTab {
                do {
                    let schemaResult = try await documentListModel.databaseDriver.getSchema(for: selectedTable.name)
                    // Format schema information for AI prompt
                    let columnInfo = schemaResult.columns.map { column in
                        let nullable = column.isNullable == "YES" ? "NULL" : "NOT NULL"
                        let defaultValue = column.columnDefault != nil ? " DEFAULT \(column.columnDefault!)" : ""
                        return "\(column.columnName): \(column.dataType) \(nullable)\(defaultValue)"
                    }.joined(separator: "\n")
                    
                    schema = """
Table: \(schemaResult.tableName)
Schema: \(schemaResult.schemaName)
Columns:
\(columnInfo)
"""
                } catch {
                    // Keep default schema message if error occurs
                    print("Error getting schema: \(error)")
                }
            }
            
            let currentDate = Date()
        
            let stream = try await openAIService.streamingChatCompletionRequest(body: .init(
                model: "gpt-4.1-mini",
                messages: [
                    .user(content: .text(search)),
                    .system(content: .text("""
You are a PostgreSQL query assistant. Your primary task is to convert natural language user queries into valid PostgreSQL SQL queries.

Core Responsibilities: 
- Convert the user query into a PostgreSQL SQL query.
- Return ONLY the SQL query without explanation.
- Optimize the query for best performance.
- Support all PostgreSQL operators and query features.

# Database Schema
The current table schema is:
\(schema)

# Output Format
Return ONLY the PostgreSQL SQL query.
Do not include any explanation, preamble, or commentary.
Format the query for readability with proper indentation.
One-line queries are acceptable for simple filters.

# Examples

**Example 1:**
**Input:** Find all users where age is greater than 30
**Output:**
SELECT * FROM users WHERE age > 30;

**Example 2:**
**Input:** Get records where status is active and created date is in the last week
**Output:**
SELECT * FROM records 
WHERE status = 'active' 
AND created_at > CURRENT_DATE - INTERVAL '7 days';

**Example 3:**
**Input:** Show me customers from New York or California with at least 5 orders
**Output:**
SELECT * FROM customers 
WHERE (state = 'New York' OR state = 'California') 
AND order_count >= 5;

**Example 4:**
**Input:** Get user with id 12345
**Output:**
SELECT * FROM users WHERE id = 12345;

**Example 5:**
**Input:** Find products containing 'laptop' in name, ordered by price descending
**Output:**
SELECT * FROM products 
WHERE name ILIKE '%laptop%' 
ORDER BY price DESC;

# Notes
- NEVER provide explanations or ask clarifying questions.
- NEVER describe what the query does.
- Use the provided schema to understand available columns and data types.
- When user input is ambiguous, refer to the schema for proper column names.
- Use appropriate PostgreSQL operators (=, >, <, IN, LIKE, ILIKE, etc.) based on query requirements.
- Use ILIKE for case-insensitive string matching.
- Use proper PostgreSQL date/time functions (CURRENT_DATE, INTERVAL, etc.).
- Default to SELECT * unless specific columns are mentioned.
- Include proper semicolon termination.

Current Date: \(currentDate)
"""))
                ],
            ))
            
            // Process the stream
            for try await chunk in stream {
                if let chunkContent = chunk.choices.first?.delta.content {
                    // Update the UI immediately with each new chunk
                    await MainActor.run { [weak self, chunkContent] in
                        self?.query += chunkContent
                    }
                }
            }
            
            // All stream processing is complete at this point
            // Now process the final result on the main thread
            await MainActor.run { [weak self] in
                guard let self = self else { return }
                self.search = ""
                executeQuery()

                Task {
                    try? await Task.sleep(for: .seconds(1.10))
                    self.processingStage = .idle
                }
            }
        } catch AIProxyError.unsuccessfulRequest(let statusCode, let responseBody) {
            await MainActor.run { [weak self] in
                print("Error: Received \(statusCode) status code with response body: \(responseBody)")
                self?.processingStage = .idle
            }
        } catch {
            await MainActor.run { [weak self] in
                print("Error: Could not create Message: \(error.localizedDescription)")
                self?.processingStage = .idle
            }
        }
    }

    
    func processNaturalLanguageQueryMongodb(search: String) async {
        guard !search.isEmpty else { return }
        
        // Update processing stage to writing query
        await MainActor.run { [weak self] in
            self?.processingStage = .writingQuery
            self?.lastQuery = search
        }
        
        do {
            await MainActor.run { [weak self] in
                self?.query = ""
            }
            
            let openAIService = AIProxy.openAIService(
                partialKey: "v2|3fe1f505|AS4tm59nSGxScFCN",
                serviceURL: "https://api.aiproxy.pro/4c1638f9/2f62a0df"
            )
            
            // Get a sample document for the AI to understand the schema
            var sampleDocument = Document()
//            if let document = documentListModel.formattedDocuments.first?.rawDocument {
//                sampleDocument = document
//            }
            
            let currentDate = Date()
        
            let stream = try await openAIService.streamingChatCompletionRequest(body: .init(
                model: "gpt-4.1-mini",
                messages: [
                    .user(content: .text(search)),
                    .system(content: .text("""
You are a MongoDB query assistant. Your primary task is to convert natural language user queries into valid MongoDB filter queries in JSON format.
Core Responsibilities: Convert the user query into a MongoDB JSON filter query.
Return ONLY the MongoDB query in JSON format without explanation.

Optimize the query for best performance.
Support all MongoDB operators and query features.

# MongoDB Schema Reference

\(sampleDocument.keys.map { "\($0): \(type(of: sampleDocument[$0]!))" }.joined(separator: "\n"))


# Output Format
Return ONLY the MongoDB query in JSON format.
Do not include any explanation, preamble, or commentary.

Format the query for readability with proper indentation.
One-line queries are acceptable for simple filters.

# Examples\n\n**Example 1:**
**Input:** Find all users where age is greater than 30
 **Output:**
```json
{
    "age": {
        "$gt": 30
    }
}
```

**Example 2:**
**Input:** Get documents where status is active and created date is in the last week
**Output:**
```json 
{
    "status": "active",
    "createdAt": {
        "$gt": {
            "$date": "2025-03-08T00:00:00Z"
        }
    }
}
```

**Example 3:**
**Input:** Show me customers from New York or California with at least 5 orders\n- 
**Output:**
``json  
{
    "$and": [
        {
            "$or": [
                {
                    "state": "New York"
                },
                {
                    "state": "California"
                }
            ]
        },
        {
            "orderCount": {
                "$gte": 5
            }
        }
    ]
}

**Example 4:**
**Input:** _id: "66def00118741b4011c5126b"
**Output:**
``json  
{
    "_id": {
        "$oid": "66def00118741b4011c5126b" 
    }
}

```
# Notes NEVER provide explanations or ask clarifying questions.
NEVER describe what the query does.
When user input is ambiguous, make reasonable assumptions about field names and data types.
Use appropriate MongoDB operators ($eq, $gt, $lt, $in, etc.) based on the query requirements. 

Current Date: \(currentDate)
"""))
                ],
                responseFormat: .jsonObject
            ))
            
            // Process the stream
            for try await chunk in stream {
                if let chunkContent = chunk.choices.first?.delta.content {
                    // Update the UI immediately with each new chunk
                    await MainActor.run { [weak self, chunkContent] in
                        self?.query += chunkContent
                    }
                }
            }
            
            // All stream processing is complete at this point
            // Now process the final result on the main thread
            await MainActor.run { [weak self] in
                guard let self = self else { return }
                self.search = ""
                executeQuery()

                Task {
                    try? await Task.sleep(for: .seconds(1.10))
                    self.processingStage = .idle
                }
            }
        } catch AIProxyError.unsuccessfulRequest(let statusCode, let responseBody) {
            await MainActor.run { [weak self] in
                print("Error: Received \(statusCode) status code with response body: \(responseBody)")
                self?.processingStage = .idle
            }
        } catch {
            await MainActor.run { [weak self] in
                print("Error: Could not create Message: \(error.localizedDescription)")
                self?.processingStage = .idle
            }
        }
    }
    
    func clearQuery() {
        self.query = defaultQuery
        Task {
            await documentListModel.loadDocuments()
        }
    }
    
    
    /// Open the full query editor view with animation
    func openQueryEditor() {
        Task { @MainActor in
            // Only perform animation if the editor is currently open
            if !showQueryEditor {
                withAnimation(.spring(response: 0.15)) {
                    showQueryEditor = true
                }
            }
        }
    }
    
    /// Execute the current query and update results
    func executeQuery() {
        processingStage = .fetchingData
        
        Task {
            do {
                await documentListModel.loadDocuments(filter: query)
                await MainActor.run { [weak self] in
                    guard let self = self else { return }
                    processingStage = .idle
                }
            } catch {
                await MainActor.run { [weak self] in
                    self?.processingStage = .idle
                }
                print("Error during query execution: \(error)")
            }
        }
    }
    
    func executeQueryMongodb() {
        processingStage = .fetchingData
        
        Task {
            do {
                if query == defaultQuery {
                    await documentListModel.loadDocuments()
                } else {
                    guard let document = try? Document(fromJSON: query) else {
                        throw MongoError.invalidData
                    }
                    
                    let serializeQuery = MongoKittenQueryHandler.serialize(document: document)
                    
//                    await documentListModel.loadDocuments(filter: serializeQuery as! Document)
                }
                
                await MainActor.run { [weak self] in
                    guard let self = self else { return }
                    processingStage = .idle
                }
            } catch {
                await MainActor.run { [weak self] in
                    self?.processingStage = .idle
                }
                print("Error during query execution: \(error)")
            }
        }
    }
    
    func getFilter() -> Document? {
        guard let document = try? Document(fromJSON: query) else {
            return nil
        }
        
        return document
    }
}
