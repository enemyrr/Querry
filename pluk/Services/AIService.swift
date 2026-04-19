//
//  AIService.swift
//  Pluk
//
//  Created by Claude on 1/4/25.
//

import Foundation

class AIService: @unchecked Sendable {

    private static let modelId = BedrockConfig.glm47ModelId
    private static let generationTemperature = 0.2

    private static let schemaToolName = "get_table_schema"

    static func analyzeError(query: String, error: Error, databaseType: String, databaseService: DatabaseService) async throws -> String {
        let collections = try await databaseService.listCollections(schema: nil)
        let tablesList = collections.map { "- \($0.name) (\($0.type))" }.joined(separator: "\n")

        let systemPrompt = errorAnalysisSystemPrompt(
            databaseType: databaseType,
            availableTables: tablesList
        )

        let userPrompt = """
        <query>
        \(query)
        </query>

        <error>
        \(error.localizedDescription)
        </error>
        """

        return try await performErrorFixRequest(
            systemPrompt: systemPrompt,
            userPrompt: userPrompt
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

                        Consider the selected text when generating the query. If the prompt refers to modifying, fixing, or working with existing code, use the selected text as the base and preserve its current query format unless the user explicitly asks to change it.
                        """
                    }

                    var messages: [BedrockGLMChatMessage] = [
                        BedrockGLMChatMessage(role: .user, content: userMessage)
                    ]

                    let response = try await BedrockGLMService.shared.chatCompletion(
                        messages: messages,
                        systemPrompt: systemPrompt,
                        tools: [schemaTool],
                        maxTokens: 4096,
                        model: modelId,
                        temperature: generationTemperature,
                        thinkingMode: .enabled
                    )

                    let toolUses = response.assistantMessage.toolCalls ?? []

                    if toolUses.isEmpty {
                        if let text = response.assistantMessage.content, !text.isEmpty {
                            continuation.yield(text)
                        }
                    } else {
                        messages.append(response.assistantMessage)

                        let toolResults = try await collectToolResults(for: toolUses, databaseService: databaseService)
                        messages.append(contentsOf: toolResults)

                        _ = try await BedrockGLMService.shared.chatCompletionStream(
                            messages: messages,
                            systemPrompt: systemPrompt,
                            tools: [],
                            maxTokens: 4096,
                            model: modelId,
                            temperature: generationTemperature,
                            thinkingMode: .enabled,
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

    private static func errorAnalysisSystemPrompt(databaseType: String, availableTables: String) -> String {
        let normalizedDatabaseType = databaseType.lowercased()

        if normalizedDatabaseType == DatabaseType.convex.rawValue {
            return """
            You fix broken Convex queries for the Pluk query editor. Your response replaces the user's query text in the editor and is executed immediately.

            Output rules:
            - Respond with ONLY the corrected Convex JavaScript query.
            - DO NOT wrap the output in markdown code fences (no ```, no ```js, no ```javascript).
            - DO NOT include prose before or after the code.
            - If you must explain something, use JavaScript comments (`// ...` or `/* ... */`) inside the query.
            - The first and last characters of your response must be part of the query itself.

            Fix rules:
            1. Make the minimal change needed to resolve the error. Preserve the user's variable names, formatting, and comments.
            2. Keep the `export default query({ ... })` wrapper. Return a read-only query — no mutations, no actions.
            3. Match table names against <available_tables> to catch typos or casing mismatches.
            4. Return exactly one valid Convex JavaScript query.

            <available_tables>
            \(availableTables)
            </available_tables>

            <example>
            <query>export default query({
              handler: async (ctx) => {
                return await ctx.db.query("users").take(10)
              }
            })</query>
            <error>Unexpected token ')'</error>
            <output>export default query({
              handler: async (ctx) => {
                return await ctx.db.query("users").take(10);
              },
            })</output>
            </example>

            <example>
            <query>export default query({
              handler: async (ctx) => {
                return await ctx.db.query("orders").order(desc).take(5);
              }
            })</query>
            <error>desc is not defined</error>
            <output>export default query({
              handler: async (ctx) => {
                return await ctx.db.query("orders").order("desc").take(5);
              },
            })</output>
            </example>
            """
        }

        if normalizedDatabaseType == DatabaseType.mongodb.rawValue.lowercased() {
            return """
            You fix broken MongoDB queries for the Pluk query editor. Your response replaces the user's query text in the editor and is executed immediately.

            Output rules:
            - Respond with ONLY the corrected MongoDB expression.
            - DO NOT wrap the output in markdown code fences (no ```, no ```js, no ```javascript).
            - DO NOT include prose before or after the code.
            - If you must explain something, use JavaScript comments (`// ...` or `/* ... */`) inside the expression.
            - The first and last characters of your response must be part of the expression itself.

            Fix rules:
            1. Make the minimal change needed to resolve the error. Preserve the user's formatting and comments.
            2. Return a read-only expression such as `db.collection.find(...)`, `db.collection.aggregate(...)`, or a chained read operation.
            3. Match collection names against <available_collections> to catch typos or casing mismatches.
            4. Return exactly one valid MongoDB expression.

            <available_collections>
            \(availableTables)
            </available_collections>

            <example>
            <query>db.user.find({age: {$gt: 30} AND</query>
            <error>Unexpected identifier 'AND'</error>
            <output>db.users.find({ age: { $gt: 30 } })</output>
            </example>

            <example>
            <query>db.orders.find({ status: "active" }).sort(createdAt: -1)</query>
            <error>Unexpected token ':'</error>
            <output>db.orders.find({ status: "active" }).sort({ createdAt: -1 })</output>
            </example>
            """
        }

        return """
        You fix broken \(databaseType) SQL queries for the Pluk SQL editor. Your response replaces the user's query text in the editor and is executed immediately.

        Output rules:
        - Respond with ONLY the corrected SQL statement.
        - DO NOT wrap the output in markdown code fences (no ```, no ```sql).
        - DO NOT include prose before or after the SQL.
        - If you must explain something, use SQL comments (`-- ...` or `/* ... */`) inside the query.
        - The first and last characters of your response must be part of the SQL itself.

        Fix rules:
        1. Make the minimal change needed to resolve the error. Preserve the user's comments, whitespace, casing, and aliases.
        2. Match table names against <available_tables> to catch typos or casing mismatches.
        3. Return exactly one syntactically valid \(databaseType) statement.

        <available_tables>
        \(availableTables)
        </available_tables>

        <example>
        <query>SELECT id, emial FROM users WHERE id = 1;</query>
        <error>column "emial" does not exist</error>
        <output>SELECT id, email FROM users WHERE id = 1;</output>
        </example>

        <example>
        <query>SELECT * FROM ordres WHERE status = 'paid';</query>
        <error>relation "ordres" does not exist</error>
        <output>SELECT * FROM orders WHERE status = 'paid';</output>
        </example>
        """
    }

    private static let schemaTool = BedrockGLMToolDefinition(
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

    private static func collectToolResults(for toolUses: [BedrockGLMToolCall], databaseService: DatabaseService) async throws -> [BedrockGLMChatMessage] {
        var results: [BedrockGLMChatMessage] = []
        for toolUse in toolUses where toolUse.name == schemaToolName {
            let inputDict: [String: Any]
            if let data = toolUse.arguments.data(using: .utf8),
               let parsed = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                inputDict = parsed
            } else {
                inputDict = [:]
            }

            let toolResult = try await handleSchemaToolCall(
                input: inputDict,
                databaseService: databaseService
            )

            results.append(
                BedrockGLMChatMessage(
                    role: .tool,
                    content: toolResult,
                    toolCallId: toolUse.id,
                    name: toolUse.name
                )
            )
        }
        return results
    }

    private static func performErrorFixRequest(
        systemPrompt: String,
        userPrompt: String
    ) async throws -> String {
        let messages: [BedrockGLMChatMessage] = [
            BedrockGLMChatMessage(role: .user, content: userPrompt)
        ]

        let response = try await BedrockGLMService.shared.chatCompletion(
            messages: messages,
            systemPrompt: systemPrompt,
            tools: [],
            maxTokens: 4096,
            model: BedrockConfig.glm47ModelId,
            temperature: generationTemperature,
            thinkingMode: .disabled
        )

        return response.assistantMessage.content?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
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
