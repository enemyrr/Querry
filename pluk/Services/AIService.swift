//
//  AIService.swift
//  Pluk
//
//  Created by Claude on 1/4/25.
//

import Foundation

class AIService {

    private static let modelId = BedrockConfig.haikuModelId

    private static let schemaToolName = "get_table_schema"

    static func analyzeError(query: String, error: Error, databaseType: String, databaseService: DatabaseService) async throws -> String {
        let collections = try await databaseService.listCollections(schema: nil)
        let tablesList = collections.map { "- \($0.name) (\($0.type))" }.joined(separator: "\n")

        let systemPrompt = """
        You are a \(databaseType) error analysis assistant. Your output replaces the broken query in a SQL editor, so respond with only the corrected SQL query as plain text. Preserve the original comments and formatting style so the user can easily diff the change.

        <available_tables>
        \(tablesList)
        </available_tables>

        <instructions>
        1. Analyze the query and error message to identify the cause.
        2. Check the available tables list for table name typos or case mismatches.
        3. If you need column-level detail, call the \(schemaToolName) tool.
        4. Return only the corrected, syntactically valid SQL query.
        </instructions>
        """

        let userPrompt = """
        <query>
        \(query)
        </query>

        <error>
        \(error.localizedDescription)
        </error>
        """

        return try await performRequestWithTools(
            systemPrompt: systemPrompt,
            userPrompt: userPrompt,
            databaseService: databaseService
        )
    }

    static func generateSQL(prompt: String, selectedText: String? = nil, databaseService: DatabaseService) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    let systemPrompt = try await databaseService.buildAICommandPromptSystemPrompt(prompt)

                    var userMessage = prompt
                    if let selectedText, !selectedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        userMessage = """
                        User prompt: \(prompt)

                        <selected_text>
                        \(selectedText)
                        </selected_text>

                        Consider the selected text when generating the SQL query. If the prompt refers to modifying, explaining, or working with existing code, use the selected text as the base.
                        """
                    }

                    var messages: [AnthropicMessage] = [
                        AnthropicMessage(role: .user, content: .text(userMessage))
                    ]

                    // First request (non-streaming) to check for tool use
                    let response = try await BedrockService.shared.messageRequest(
                        messages: messages,
                        system: systemPrompt,
                        tools: [schemaTool],
                        maxTokens: 4096,
                        modelId: modelId
                    )

                    let toolUses = extractToolUses(from: response.content)

                    if toolUses.isEmpty {
                        for block in response.content {
                            if case .text(let text) = block, !text.isEmpty {
                                continuation.yield(text)
                            }
                        }
                    } else {
                        messages.append(AnthropicMessage(role: .assistant, content: .blocks(buildAssistantBlocks(from: response.content))))

                        let toolResults = try await collectToolResults(for: toolUses, databaseService: databaseService)
                        messages.append(AnthropicMessage(role: .user, content: .blocks(toolResults)))

                        _ = try await BedrockService.shared.messageRequestStream(
                            messages: messages,
                            system: systemPrompt,
                            tools: [],
                            maxTokens: 4096,
                            thinking: nil,
                            modelId: modelId,
                            onTextDelta: { delta in
                                continuation.yield(delta)
                            }
                        )
                    }

                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    // MARK: - Private

    private static let schemaTool = AnthropicToolDefinition(
        name: schemaToolName,
        description: "Get the complete schema information for a specific table including column names, data types, constraints, and relationships",
        inputSchema: [
            "type": "object",
            "properties": [
                "table_name": [
                    "type": "string",
                    "description": "The name of the table to get schema information for"
                ],
                "schema_name": [
                    "type": "string",
                    "description": "The schema/database name (optional, will use current schema if not provided)"
                ]
            ],
            "required": ["table_name"]
        ]
    )

    private static func extractToolUses(from content: [ResponseContentBlock]) -> [(id: String, name: String, input: [String: any Sendable])] {
        content.compactMap { block in
            guard case .toolUse(let id, let name, let input) = block else { return nil }
            return (id, name, input)
        }
    }

    private static func buildAssistantBlocks(from content: [ResponseContentBlock]) -> [ContentBlock] {
        content.compactMap { block in
            switch block {
            case .text(let text): .text(text)
            case .toolUse(let id, let name, let input):
                .toolUse(id: id, name: name, input: input.mapValues { JSONValue.fromAny($0) })
            case .thinking: nil
            }
        }
    }

    private static func collectToolResults(for toolUses: [(id: String, name: String, input: [String: any Sendable])], databaseService: DatabaseService) async throws -> [ContentBlock] {
        var results: [ContentBlock] = []
        for toolUse in toolUses {
            if toolUse.name == schemaToolName {
                let inputDict = toolUse.input.mapValues { $0 as Any }
                let toolResult = try await handleSchemaToolCall(
                    input: inputDict,
                    databaseService: databaseService
                )
                results.append(.toolResult(toolUseId: toolUse.id, content: toolResult))
            }
        }
        return results
    }

    private static func extractText(from content: [ResponseContentBlock]) -> String {
        content.compactMap { block in
            guard case .text(let text) = block else { return nil }
            return text
        }.joined()
    }

    private static func performRequestWithTools(systemPrompt: String, userPrompt: String, databaseService: DatabaseService) async throws -> String {
        var messages: [AnthropicMessage] = [
            AnthropicMessage(role: .user, content: .text(userPrompt))
        ]

        let response = try await BedrockService.shared.messageRequest(
            messages: messages,
            system: systemPrompt,
            tools: [schemaTool],
            maxTokens: 4096,
            modelId: modelId
        )

        let toolUses = extractToolUses(from: response.content)

        if toolUses.isEmpty {
            return extractText(from: response.content).trimmingCharacters(in: .whitespacesAndNewlines)
        }

        messages.append(AnthropicMessage(role: .assistant, content: .blocks(buildAssistantBlocks(from: response.content))))

        let toolResults = try await collectToolResults(for: toolUses, databaseService: databaseService)
        messages.append(AnthropicMessage(role: .user, content: .blocks(toolResults)))

        let finalResponse = try await BedrockService.shared.messageRequest(
            messages: messages,
            system: systemPrompt,
            tools: [],
            maxTokens: 4096,
            modelId: modelId
        )

        return extractText(from: finalResponse.content).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func handleSchemaToolCall(input: [String: Any], databaseService: DatabaseService) async throws -> String {
        guard let tableName = input["table_name"] as? String else {
            return "Error: Invalid arguments for get_table_schema"
        }

        let schemaName = input["schema_name"] as? String

        do {
            guard let schemaResult = try await databaseService.getSchema(for: tableName, databaseSchema: schemaName) else {
                return "Error: Could not retrieve schema for table '\(tableName)'"
            }

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
