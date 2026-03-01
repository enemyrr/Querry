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

                    let anthropicService = AIProxy.anthropicService(
                        partialKey: partialKey,
                        serviceURL: serviceURL
                    )

                    let getSchemaFunction = AnthropicToolUnion(
                        description: "Get the complete schema information for a specific table including column names, data types, constraints, and relationships",
                        inputSchema: [
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
                        name: "get_table_schema"
                    )

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

                    var messages: [AnthropicInputMessage] = [
                        AnthropicInputMessage(content: .text(userMessage), role: .user)
                    ]

                    let response = try await anthropicService.messageRequest(
                        body: AnthropicMessageRequestBody(
                            maxTokens: 4096,
                            messages: messages,
                            model: "claude-haiku-4-5-20241022",
                            system: .text(systemPrompt),
                            tools: [getSchemaFunction]
                        ),
                        secondsToWait: 60
                    )

                    var toolUses: [(id: String, name: String, input: [String: any Sendable])] = []
                    for content in response.content {
                        switch content {
                        case .textBlock(let block):
                            if !block.text.isEmpty {
                                continuation.yield(block.text)
                            }
                        case .toolUseBlock(let block):
                            toolUses.append((block.id, block.name, block.input))
                        default:
                            break
                        }
                    }

                    if !toolUses.isEmpty {
                        let assistantBlocks: [AnthropicContentBlockParam] = response.content.compactMap { c in
                            switch c {
                            case .textBlock(let block):
                                return .textBlock(AnthropicTextBlockParam(text: block.text))
                            case .toolUseBlock(let block):
                                return .toolUseBlock(AnthropicToolUseBlockParam(
                                    id: block.id,
                                    input: sendableToAIProxyJSONValues(block.input),
                                    name: block.name
                                ))
                            default:
                                return nil
                            }
                        }
                        messages.append(AnthropicInputMessage(content: .blocks(assistantBlocks), role: .assistant))

                        var toolResults: [AnthropicContentBlockParam] = []
                        for toolUse in toolUses {
                            if toolUse.name == "get_table_schema" {
                                let inputDict = sendableToAny(toolUse.input)
                                let toolResult = try await handleSchemaToolCall(
                                    input: inputDict,
                                    databaseService: databaseService
                                )
                                toolResults.append(.toolResultBlock(AnthropicToolResultBlockParam(toolUseId: toolUse.id, content: .text(toolResult))))
                            }
                        }
                        messages.append(AnthropicInputMessage(content: .blocks(toolResults), role: .user))

                        let finalResponse = try await anthropicService.messageRequest(
                            body: AnthropicMessageRequestBody(
                                maxTokens: 4096,
                                messages: messages,
                                model: "claude-haiku-4-5-20241022",
                                system: .text(systemPrompt)
                            ),
                            secondsToWait: 60
                        )

                        for content in finalResponse.content {
                            if case .textBlock(let block) = content, !block.text.isEmpty {
                                continuation.yield(block.text)
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
        let anthropicService = AIProxy.anthropicService(
            partialKey: partialKey,
            serviceURL: serviceURL
        )

        let response = try await anthropicService.messageRequest(
            body: AnthropicMessageRequestBody(
                maxTokens: 4096,
                messages: [
                    AnthropicInputMessage(content: .text(userPrompt), role: .user)
                ],
                model: "claude-haiku-4-5-20241022",
                system: .text(systemPrompt)
            ),
            secondsToWait: 60
        )

        let result = response.content.compactMap { content -> String? in
            guard case .textBlock(let block) = content else { return nil }
            return block.text
        }.joined()

        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func performAIRequestWithTools(systemPrompt: String, userPrompt: String, databaseService: DatabaseService) async throws -> String {
        let anthropicService = AIProxy.anthropicService(
            partialKey: partialKey,
            serviceURL: serviceURL
        )

        let getSchemaFunction = AnthropicToolUnion(
            description: "Get the complete schema information for a specific table including column names, data types, constraints, and relationships",
            inputSchema: [
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
            name: "get_table_schema"
        )

        var messages: [AnthropicInputMessage] = [
            AnthropicInputMessage(content: .text(userPrompt), role: .user)
        ]

        let response = try await anthropicService.messageRequest(
            body: AnthropicMessageRequestBody(
                maxTokens: 4096,
                messages: messages,
                model: "claude-haiku-4-5-20241022",
                system: .text(systemPrompt),
                tools: [getSchemaFunction]
            ),
            secondsToWait: 60
        )

        var result = ""
        var toolUses: [(id: String, name: String, input: [String: any Sendable])] = []

        for content in response.content {
            switch content {
            case .textBlock(let block):
                result += block.text
            case .toolUseBlock(let block):
                toolUses.append((block.id, block.name, block.input))
            default:
                break
            }
        }

        if !toolUses.isEmpty {
            let assistantBlocks: [AnthropicContentBlockParam] = response.content.compactMap { c in
                switch c {
                case .textBlock(let block):
                    return .textBlock(AnthropicTextBlockParam(text: block.text))
                case .toolUseBlock(let block):
                    return .toolUseBlock(AnthropicToolUseBlockParam(
                        id: block.id,
                        input: sendableToAIProxyJSONValues(block.input),
                        name: block.name
                    ))
                default:
                    return nil
                }
            }
            messages.append(AnthropicInputMessage(content: .blocks(assistantBlocks), role: .assistant))

            var toolResults: [AnthropicContentBlockParam] = []
            for toolUse in toolUses {
                if toolUse.name == "get_table_schema" {
                    let inputDict = sendableToAny(toolUse.input)
                    let toolResult = try await handleSchemaToolCall(
                        input: inputDict,
                        databaseService: databaseService
                    )
                    toolResults.append(.toolResultBlock(AnthropicToolResultBlockParam(toolUseId: toolUse.id, content: .text(toolResult))))
                }
            }
            messages.append(AnthropicInputMessage(content: .blocks(toolResults), role: .user))

            let finalResponse = try await anthropicService.messageRequest(
                body: AnthropicMessageRequestBody(
                    maxTokens: 4096,
                    messages: messages,
                    model: "claude-haiku-4-5-20241022",
                    system: .text(systemPrompt)
                ),
                secondsToWait: 60
            )

            var finalResult = ""
            for content in finalResponse.content {
                if case .textBlock(let block) = content {
                    finalResult += block.text
                }
            }

            return finalResult.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        return result.trimmingCharacters(in: .whitespacesAndNewlines)
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

    private static func sendableToAny(_ input: [String: any Sendable]) -> [String: Any] {
        input.reduce(into: [String: Any]()) { $0[$1.key] = $1.value }
    }

    private static func anyToAIProxyJSONValue(_ value: Any) -> AIProxyJSONValue {
        switch value {
        case is NSNull: return .null(NSNull())
        case let b as Bool: return .bool(b)
        case let i as Int: return .int(i)
        case let d as Double: return .double(d)
        case let s as String: return .string(s)
        case let arr as [Any]: return .array(arr.map { anyToAIProxyJSONValue($0) })
        case let dict as [String: Any]: return .object(dict.mapValues { anyToAIProxyJSONValue($0) })
        default: return .string("\(value)")
        }
    }

    private static func sendableToAIProxyJSONValues(_ input: [String: any Sendable]) -> [String: AIProxyJSONValue] {
        input.reduce(into: [String: AIProxyJSONValue]()) { result, pair in
            result[pair.key] = anyToAIProxyJSONValue(pair.value)
        }
    }
}
