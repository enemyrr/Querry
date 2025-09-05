//
//  AIService.swift
//  Pluk
//
//  Created by Claude on 1/4/25.
//

import Foundation
import AIProxy

class AIService {
    private static let partialKey = "v2|3fe1f505|AS4tm59nSGxScFCN"
    private static let serviceURL = "https://api.aiproxy.pro/4c1638f9/2f62a0df"
    
    static func analyzeError(query: String, error: Error, databaseType: String, databaseService: DatabaseService) async throws -> String {
        // Get available tables list
        let collections = try await databaseService.listCollections(schema: nil)
        let tablesList = collections.map { "- \($0.name) (\($0.type))" }.joined(separator: "\n")
        
        let systemPrompt = """
        You are a SQL error analysis assistant for \(databaseType). Your task is to analyze SQL errors and provide a corrected SQL query.
        
        ## Available Tables
        The database contains the following tables:
        \(tablesList)
        
        Instructions:
        - Analyze the SQL query and error message
        - Use the available tables list to check for table name typos or case issues
        - Use schema information when needed to understand table structures
        - Return ONLY the corrected SQL query
        - Do not include explanations, comments, or markdown formatting
        - Focus on fixing the specific error reported
        - Ensure the corrected query is syntactically valid
        
        If you need detailed schema information about specific tables, use the get_table_schema tool.
        
        Return only the corrected SQL query as plain text.
        """
        
        let userPrompt = """
        Original SQL Query:
        \(query)
        
        Error Message:
        \(error.localizedDescription)
        
        IMPORTANT: Try to keep code comments and style as it so its easier to make a diff and find the changes
        
        Please provide the corrected SQL query.
        """
        
        return try await performAIRequestWithTools(
            systemPrompt: systemPrompt,
            userPrompt: userPrompt,
            databaseService: databaseService
        )
    }
    
    static func generateSQL(prompt: String, selectedText: String? = nil, databaseService: DatabaseService) -> AsyncThrowingStream<String, Error> {
        return AsyncThrowingStream { continuation in
            Task {
                do {
                    let systemPrompt = try await databaseService.buildAICommandPromptSystemPrompt(prompt)
                    
                    let openAIService = AIProxy.openAIService(
                        partialKey: partialKey,
                        serviceURL: serviceURL
                    )
        
                    // Define the schema tool for accessing table schemas
                    let getSchemaFunction = OpenAIChatCompletionRequestBody.Tool.function(
                        name: "get_table_schema",
                        description: "Get the complete schema information for a specific table including column names, data types, constraints, and relationships",
                        parameters: [
                            "type": .string("object"),
                            "properties": .object([
                                "table_name": .object([
                                    "type": .string("string"),
                                    "description": .string("The name of the table to get schema information for")
                                ]),
                                "schema_name": .object([
                                    "type": .string("string"),
                                    "description": .string("The schema/database name (optional, will use current schema if not provided)")
                                ])
                            ]),
                            "required": .array([.string("table_name")])
                        ],
                        strict: nil
                    )
                    
                    // Build user message with optional selected text context
                    var userMessage = prompt
                    if let selectedText = selectedText, !selectedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        userMessage = """
                        User prompt: \(prompt)
                        
                        Selected text context:
                        ```sql
                        \(selectedText)
                        ```
                        
                        Please consider the selected text when generating the SQL query. If the prompt refers to modifying, explaining, or working with existing code, use the selected text as the base.
                        """
                    }
                    
                    let stream = try await openAIService.streamingChatCompletionRequest(
                        body: .init(
                            model: "gpt-4.1-mini",
                            messages: [
                                .user(content: .text(userMessage)),
                                .system(content: .text(systemPrompt))
                            ],
                            parallelToolCalls: true,
                            tools: [getSchemaFunction]
                        )
                    )
                    
                    var toolCalls: [(id: String, name: String, arguments: String)] = []
                    
                    for try await chunk in stream {
                        if let content = chunk.choices.first?.delta.content {
                            continuation.yield(content)
                        }
                        
                        // Handle tool calls
                        if let toolCallDeltas = chunk.choices.first?.delta.toolCalls {
                            for toolCallDelta in toolCallDeltas {
                                if let index = toolCallDelta.index,
                                   let function = toolCallDelta.function {
                                    
                                    // Ensure we have enough space in the array
                                    while toolCalls.count <= index {
                                        toolCalls.append((id: "", name: "", arguments: ""))
                                    }
                                    
                                    // Update the tool call at the correct index
                                    var current = toolCalls[index]
                                    
                                    if let id = toolCallDelta.id {
                                        current.id = id
                                    }
                                    
                                    if let name = function.name {
                                        current.name = name
                                    }
                                    
                                    if let arguments = function.arguments {
                                        current.arguments += arguments
                                    }
                                    
                                    toolCalls[index] = current
                                }
                            }
                        }
                    }
                    
                    // Process any tool calls and stream final response
                    if !toolCalls.isEmpty {
                        var messages: [OpenAIChatCompletionRequestBody.Message] = [
                            .user(content: .text(userMessage)),
                            .system(content: .text(systemPrompt))
                        ]
                        
                        // Create the assistant message with tool calls
                        let assistantToolCalls = toolCalls.map { toolCall in
                            OpenAIChatCompletionRequestBody.Message.ToolCall(
                                id: toolCall.id,
                                function: OpenAIChatCompletionRequestBody.Message.ToolCall.Function(
                                    name: toolCall.name,
                                    arguments: toolCall.arguments
                                )
                            )
                        }
                        
                        messages.append(.assistant(
                            content: nil,
                            toolCalls: assistantToolCalls
                        ))
                        
                        // Add tool call results
                        for toolCall in toolCalls {
                            if toolCall.name == "get_table_schema" {
                                let toolResult = try await handleSchemaToolCall(
                                    arguments: toolCall.arguments,
                                    databaseService: databaseService
                                )
                                
                                messages.append(.tool(
                                    content: .text(toolResult),
                                    toolCallID: toolCall.id
                                ))
                            }
                        }
                        
                        // Stream final response with tool results
                        let finalStream = try await openAIService.streamingChatCompletionRequest(
                            body: .init(
                                model: "gpt-4.1-mini",
                                messages: messages
                            )
                        )
                        
                        for try await chunk in finalStream {
                            if let content = chunk.choices.first?.delta.content {
                                continuation.yield(content)
                            }
                        }
                    }
                    
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }
    
    
    private static func performAIRequest(systemPrompt: String, userPrompt: String) async throws -> String {
        let openAIService = AIProxy.openAIService(
            partialKey: partialKey,
            serviceURL: serviceURL
        )
        
        let stream = try await openAIService.streamingChatCompletionRequest(
            body: .init(
                model: "gpt-4.1-mini",
                messages: [
                    .system(content: .text(systemPrompt)),
                    .user(content: .text(userPrompt))
                ]
            )
        )
        
        var result = ""
        for try await chunk in stream {
            if let content = chunk.choices.first?.delta.content {
                result += content
            }
        }
        
        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    private static func performAIRequestWithTools(systemPrompt: String, userPrompt: String, databaseService: DatabaseService) async throws -> String {
        let openAIService = AIProxy.openAIService(
            partialKey: partialKey,
            serviceURL: serviceURL
        )
        
        // Define the schema tool for accessing table schemas
        let getSchemaFunction = OpenAIChatCompletionRequestBody.Tool.function(
            name: "get_table_schema",
            description: "Get the complete schema information for a specific table including column names, data types, constraints, and relationships",
            parameters: [
                "type": .string("object"),
                "properties": .object([
                    "table_name": .object([
                        "type": .string("string"),
                        "description": .string("The name of the table to get schema information for")
                    ]),
                    "schema_name": .object([
                        "type": .string("string"),
                        "description": .string("The schema/database name (optional, will use current schema if not provided)")
                    ])
                ]),
                "required": .array([.string("table_name")])
            ],
            strict: nil
        )
        
        let stream = try await openAIService.streamingChatCompletionRequest(
            body: .init(
                model: "gpt-4.1-mini",
                messages: [
                    .system(content: .text(systemPrompt)),
                    .user(content: .text(userPrompt))
                ],
                parallelToolCalls: true,
                tools: [getSchemaFunction]
            )
        )
        
        var result = ""
        var toolCalls: [(id: String, name: String, arguments: String)] = []
        
        for try await chunk in stream {
            if let content = chunk.choices.first?.delta.content {
                result += content
            }
            
            // Handle tool calls
            if let toolCallDeltas = chunk.choices.first?.delta.toolCalls {
                for toolCallDelta in toolCallDeltas {
                    if let index = toolCallDelta.index,
                       let function = toolCallDelta.function {
                        
                        // Ensure we have enough space in the array
                        while toolCalls.count <= index {
                            toolCalls.append((id: "", name: "", arguments: ""))
                        }
                        
                        // Update the tool call at the correct index
                        var current = toolCalls[index]
                        
                        if let id = toolCallDelta.id {
                            current.id = id
                        }
                        
                        if let name = function.name {
                            current.name = name
                        }
                        
                        if let arguments = function.arguments {
                            current.arguments += arguments
                        }
                        
                        toolCalls[index] = current
                    }
                }
            }
        }
        
        // Process any tool calls
        if !toolCalls.isEmpty {
            var messages: [OpenAIChatCompletionRequestBody.Message] = [
                .system(content: .text(systemPrompt)),
                .user(content: .text(userPrompt))
            ]
            
            // Create the assistant message with tool calls
            let assistantToolCalls = toolCalls.map { toolCall in
                OpenAIChatCompletionRequestBody.Message.ToolCall(
                    id: toolCall.id,
                    function: OpenAIChatCompletionRequestBody.Message.ToolCall.Function(
                        name: toolCall.name,
                        arguments: toolCall.arguments
                    )
                )
            }
            
            messages.append(.assistant(
                content: nil,
                toolCalls: assistantToolCalls
            ))
            
            // Add tool call results
            for toolCall in toolCalls {
                if toolCall.name == "get_table_schema" {
                    let toolResult = try await handleSchemaToolCall(
                        arguments: toolCall.arguments,
                        databaseService: databaseService
                    )
                    
                    messages.append(.tool(
                        content: .text(toolResult),
                        toolCallID: toolCall.id
                    ))
                }
            }
            
            // Get final response with tool results
            let finalStream = try await openAIService.streamingChatCompletionRequest(
                body: .init(
                    model: "gpt-4.1-mini",
                    messages: messages
                )
            )
            
            var finalResult = ""
            for try await chunk in finalStream {
                if let content = chunk.choices.first?.delta.content {
                    finalResult += content
                }
            }
            
            return finalResult.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        
        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    private static func handleSchemaToolCall(arguments: String, databaseService: DatabaseService) async throws -> String {
        // Parse the JSON arguments
        guard let data = arguments.data(using: .utf8),
              let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let tableName = json["table_name"] as? String else {
            return "Error: Invalid arguments for get_table_schema"
        }
        
        let schemaName = json["schema_name"] as? String
        
        do {
            guard let schemaResult = try await databaseService.getSchema(for: tableName, databaseSchema: schemaName) else {
                return "Error: Could not retrieve schema for table '\(tableName)'"
            }
            
            // Format the schema information as a readable string
            var schemaDescription = "Table: \(schemaResult.tableName)\n"
            if !schemaResult.schemaName.isEmpty {
                schemaDescription += "Schema: \(schemaResult.schemaName)\n"
            }
            schemaDescription += "Columns (\(schemaResult.columnCount)):\n\n"
            
            for column in schemaResult.columns {
                schemaDescription += "- \(column.columnName): \(column.dataType)"
                
                if let precision = column.numericPrecision {
                    schemaDescription += "(\(precision)"
                    if let scale = column.numericScale {
                        schemaDescription += ",\(scale)"
                    }
                    schemaDescription += ")"
                }
                
                if column.isNullable == "NO" {
                    schemaDescription += " NOT NULL"
                }
                
                if let defaultValue = column.columnDefault {
                    schemaDescription += " DEFAULT \(defaultValue)"
                }
                
                // Add constraint information
                if column.isPrimaryKey {
                    schemaDescription += " [PRIMARY KEY]"
                }
                
                if column.hasForeignKey {
                    for fk in column.foreignKeyConstraints {
                        if let refTable = fk.referencedTable {
                            schemaDescription += " [FK -> \(refTable)"
                            if let refCols = fk.referencedColumns, !refCols.isEmpty {
                                schemaDescription += "(\(refCols.joined(separator: ", ")))"
                            }
                            schemaDescription += "]"
                        }
                    }
                }
                
                if !column.uniqueConstraints.isEmpty {
                    schemaDescription += " [UNIQUE]"
                }
                
                if let comment = column.comment {
                    schemaDescription += " -- \(comment)"
                }
                
                schemaDescription += "\n"
            }
            
            return schemaDescription
            
        } catch {
            return "Error retrieving schema for table '\(tableName)': \(error.localizedDescription)"
        }
    }
}
