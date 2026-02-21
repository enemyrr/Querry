import Foundation
import AIProxy

struct AgentRoundResult {
    let streamedText: String
    let toolCalls: [(id: String, name: String, arguments: String)]
}

struct BlockCreationRequest {
    let kind: NotebookBlockKind
    let title: String
    var config: ChartBlockConfig?
    var textContent: String?
}

@Observable
@MainActor
final class NotebookAgentEngine {

    private(set) var pendingBlockCreations: [BlockCreationRequest] = []
    private(set) var toolStatusMessage: String?

    private let driverSession = AgentDriverSession()

    private static let partialKey = "v2|3fe1f505|AS4tm59nSGxScFCN"
    private static let serviceURL = "https://api.aiproxy.pro/4c1638f9/2f62a0df"

    func clearPendingCreations() {
        pendingBlockCreations.removeAll()
    }

    // MARK: - System Prompt

    func buildSystemPrompt(connections: [Connection]) -> String {
        let connectionList: String
        if connections.isEmpty {
            connectionList = "No connections selected. Ask the user to select a connection using the picker below the chat input."
        } else {
            connectionList = connections.map { conn in
                "- \(conn.name) (keychainId: \(conn.keychainId), type: \(conn.databaseType.rawValue), database: \(conn.defaultDatabase ?? "default"))"
            }.joined(separator: "\n")
        }

        let chartTypes = ChartBlockConfig.ChartType.allCases
            .map { "  - \($0.rawValue): \($0.displayName)" }
            .joined(separator: "\n")

        let aggregations = AggregationFunction.allCases
            .map { "  - \($0.rawValue): \($0.displayName)" }
            .joined(separator: "\n")

        return """
        You are an expert data analyst embedded in Pluk, a database notebook for macOS.
        You build rich, narrative-driven notebook pages — combining charts, analysis, and written commentary to tell a clear data story.

        Think of yourself like a BI analyst presenting findings: every visualization should be accompanied by context explaining what the data shows, why it matters, and what to look for.

        ## Available Connections
        \(connectionList)

        ## Your Capabilities
        - Use `list_tables` to discover tables in a connection
        - Use `get_table_schema` to understand column names, types, and constraints
        - Use `create_chart_block` to add chart visualizations to the notebook
        - Use `create_text_block` to add markdown text (section headers, analysis, commentary, context)
        - You can create multiple blocks in a single response to build full analysis pages

        ## Chart Types
        \(chartTypes)

        ## Aggregation Functions (for Y axis columns)
        \(aggregations)

        ## Workflow
        1. If you don't know the schema, call `list_tables` first
        2. Call `get_table_schema` to understand columns before building charts
        3. Choose chart type based on data shape (categorical -> bar/column, time-series -> line, proportional -> pie)
        4. Use aggregations when appropriate (e.g., SUM of revenue grouped by category)

        ## CRITICAL: Block Creation Order
        Blocks appear in the notebook in the EXACT order you create them. You MUST call `create_text_block` and `create_chart_block` in the order you want them displayed. Follow this pattern:

        1. FIRST: call `create_text_block` with a section heading, context, and key insights — explain what the chart shows and what to look for
        2. THEN: call `create_chart_block` to add the visualization right after the text
        3. Repeat this pattern for each additional analysis section

        Example flow for a single analysis:
        → create_text_block("# Revenue by Category\nDumplings dominate at 45% of total revenue, nearly double the next category. Let's visualize the full breakdown.")
        → create_chart_block(bar chart of revenue by category)

        Text always comes BEFORE its chart, never after.

        NEVER batch all charts together or all text together. Always interleave them.

        ## Writing Style for Text Blocks
        - Use markdown formatting: `#` for section headings, `**bold**` for emphasis, bullet points for key findings
        - Section headings should be descriptive (e.g., "Revenue by Category" not just "Chart 1")
        - Commentary should highlight specific insights: trends, outliers, comparisons, or actionable takeaways
        - Keep commentary concise — 2-4 sentences per chart is ideal
        - Write in a professional but approachable tone, like a colleague presenting findings

        ## Rules
        - NEVER guess column names. Always call `get_table_schema` first.
        - Prefer numeric columns for Y axis, categorical/date for X axis
        - If no connection is selected, ask the user to pick one from the connection picker
        - When building multi-chart analyses, create a logical flow — overview first, then drill into specifics
        """
    }

    // MARK: - Tool Definitions

    func buildTools(connections: [Connection]) -> [OpenAIChatCompletionRequestBody.Tool] {
        var tools: [OpenAIChatCompletionRequestBody.Tool] = [
            listTablesTool,
            getTableSchemaTool,
        ]
        tools.append(contentsOf: NotebookBlockKind.allAITools)
        return tools
    }

    // MARK: - Streaming Round

    func performRound(
        messages: [OpenAIChatCompletionRequestBody.Message],
        connections: [Connection],
        onToken: @escaping @MainActor @Sendable (String) -> Void
    ) async throws -> AgentRoundResult {
        let openAIService = AIProxy.openAIService(
            partialKey: Self.partialKey,
            serviceURL: Self.serviceURL
        )
        let tools = buildTools(connections: connections)

        let stream = try await openAIService.streamingChatCompletionRequest(
            body: .init(
                model: "gpt-5.1",
                messages: messages,
                parallelToolCalls: false,
                tools: tools
            ),
            secondsToWait: 60
        )

        var streamedContent = ""
        var rawToolCalls: [(id: String, name: String, arguments: String)] = []

        for try await chunk in stream {
            guard !Task.isCancelled else { throw CancellationError() }

            // Debug: log the raw chunk
            print("[AgentDebug] Raw chunk: \(chunk)")

            if let choice = chunk.choices.first {
                print("[AgentDebug] delta.content: \(choice.delta.content ?? "nil")")
                print("[AgentDebug] delta.role: \(choice.delta.role ?? "nil")")
                print("[AgentDebug] finishReason: \(choice.finishReason ?? "nil")")

                if let toolCallDeltas = choice.delta.toolCalls {
                    print("[AgentDebug] delta.toolCalls count: \(toolCallDeltas.count)")
                    for tc in toolCallDeltas {
                        print("[AgentDebug]   toolCall index=\(tc.index ?? -1) id=\(tc.id ?? "nil") fn.name=\(tc.function?.name ?? "nil") fn.args=\(tc.function?.arguments ?? "nil")")
                    }
                }
            }

            if let token = chunk.choices.first?.delta.content {
                streamedContent += token
                onToken(token)
            }

            if let deltas = chunk.choices.first?.delta.toolCalls {
                for delta in deltas {
                    guard let index = delta.index, let function = delta.function else { continue }
                    while rawToolCalls.count <= index {
                        rawToolCalls.append((id: "", name: "", arguments: ""))
                    }
                    var current = rawToolCalls[index]
                    if let id = delta.id { current.id = id }
                    if let name = function.name { current.name = name }
                    if let args = function.arguments { current.arguments += args }
                    rawToolCalls[index] = current
                }
            }
        }

        print("[AgentDebug] === Round Complete ===")
        print("[AgentDebug] streamedContent: \(streamedContent)")
        print("[AgentDebug] toolCalls: \(rawToolCalls.map { "(id: \($0.id), name: \($0.name), args: \($0.arguments))" })")

        return AgentRoundResult(
            streamedText: streamedContent,
            toolCalls: rawToolCalls
        )
    }

    // MARK: - Tool Execution

    func executeToolCall(
        _ toolCall: (id: String, name: String, arguments: String),
        connections: [Connection]
    ) async -> String {
        let json = parseArguments(toolCall.arguments)

        switch toolCall.name {
        case "list_tables":
            return await executeListTables(json: json, connections: connections)
        case "get_table_schema":
            return await executeGetTableSchema(json: json, connections: connections)
        case "create_chart_block":
            return executeCreateChartBlock(json: json)
        case "create_text_block":
            return executeCreateTextBlock(json: json)
        default:
            return "Unknown tool: \(toolCall.name)"
        }
    }

    // MARK: - List Tables

    private func executeListTables(json: [String: Any], connections: [Connection]) async -> String {
        guard let keychainId = json["connection_keychain_id"] as? String,
              let connection = connections.first(where: { $0.keychainId == keychainId }) else {
            if let conn = connections.first {
                return await fetchTables(connection: conn, schema: json["schema_name"] as? String)
            }
            return "Error: No connection available. Ask the user to select a connection."
        }
        return await fetchTables(connection: connection, schema: json["schema_name"] as? String)
    }

    private func fetchTables(connection: Connection, schema: String?) async -> String {
        toolStatusMessage = "Fetching tables from \(connection.name)..."
        defer { toolStatusMessage = nil }

        do {
            try await driverSession.connect(
                databaseType: connection.databaseType,
                uri: connection.connectionUri,
                keychainId: connection.keychainId,
                databaseName: connection.defaultDatabase ?? ""
            )

            var schemaInfo = ""
            let schemaCapableTypes: Set<DatabaseType> = [.postgres, .supabase, .mysql]
            if schemaCapableTypes.contains(connection.databaseType) {
                let schemas = try await driverSession.getInformationSchema()
                if !schemas.isEmpty {
                    schemaInfo = "\nAvailable schemas: \(schemas.map(\.name).joined(separator: ", "))\n"
                }
            }

            let collections = try await driverSession.listCollections(schema: schema)
            let list = collections.map { "- \($0.name) (\($0.type))" }.joined(separator: "\n")
            return "Tables in \(connection.name):\(schemaInfo)\n\(list)"
        } catch {
            return "Error listing tables: \(error.localizedDescription)"
        }
    }

    // MARK: - Get Table Schema

    private func executeGetTableSchema(json: [String: Any], connections: [Connection]) async -> String {
        guard let tableName = json["table_name"] as? String else {
            return "Error: table_name is required"
        }

        let schemaName = json["schema_name"] as? String
        let keychainId = json["connection_keychain_id"] as? String

        let connection: Connection?
        if let kid = keychainId {
            connection = connections.first(where: { $0.keychainId == kid })
        } else {
            connection = connections.first
        }

        guard let conn = connection else {
            return "Error: No connection available"
        }

        toolStatusMessage = "Reading schema for \(tableName)..."
        defer { toolStatusMessage = nil }

        do {
            try await driverSession.connect(
                databaseType: conn.databaseType,
                uri: conn.connectionUri,
                keychainId: conn.keychainId,
                databaseName: conn.defaultDatabase ?? ""
            )
            let result = try await driverSession.getSchema(tableName: tableName, schema: schemaName)
            return formatSchemaResult(result)
        } catch {
            return "Error getting schema for \(tableName): \(error.localizedDescription)"
        }
    }

    private func formatSchemaResult(_ result: DatabaseSchemaResult) -> String {
        var output = "Table: \(result.tableName)\n"
        if !result.schemaName.isEmpty { output += "Schema: \(result.schemaName)\n" }
        output += "Columns (\(result.columns.count)):\n"
        for col in result.columns {
            output += "- \(col.columnName): \(col.dataType)"
            if col.isPrimaryKey { output += " [PK]" }
            if col.hasForeignKey {
                for fk in col.foreignKeyConstraints {
                    if let refTable = fk.referencedTable {
                        output += " [FK -> \(refTable)]"
                    }
                }
            }
            if col.isNullable == "NO" { output += " NOT NULL" }
            if let def = col.columnDefault { output += " DEFAULT \(def)" }
            output += "\n"
        }
        return output
    }

    // MARK: - Create Chart Block

    private func executeCreateChartBlock(json: [String: Any]) -> String {
        guard let keychainId = json["connection_keychain_id"] as? String,
              let connName = json["connection_name"] as? String,
              let dbType = json["database_type"] as? String,
              let dbName = json["database_name"] as? String,
              let tableName = json["table_name"] as? String,
              let chartTypeRaw = json["chart_type"] as? String,
              let xAxis = json["x_axis_column"] as? String,
              let title = json["title"] as? String else {
            return "Error: Missing required parameters for create_chart_block"
        }

        let yAxisColumns: [String]
        if let arr = json["y_axis_columns"] as? [String] {
            yAxisColumns = arr
        } else if let arr = json["y_axis_columns"] as? [Any] {
            yAxisColumns = arr.compactMap { $0 as? String }
        } else {
            return "Error: y_axis_columns must be an array of strings"
        }

        let chartType = ChartBlockConfig.ChartType(rawValue: chartTypeRaw) ?? .groupedColumn
        let rowLimit = min(json["row_limit"] as? Int ?? 500, 500)
        let schemaName = json["schema_name"] as? String

        var config = ChartBlockConfig(
            connectionKeychainId: keychainId,
            connectionName: connName,
            databaseType: dbType,
            databaseName: dbName,
            schemaName: schemaName,
            tableName: tableName,
            chartType: chartType,
            rowLimit: rowLimit
        )
        config.xAxisColumn = xAxis
        config.fields["yAxis"] = yAxisColumns

        // Apply aggregations if provided
        if let aggs = json["aggregations"] as? [String: String] {
            for (column, aggRaw) in aggs {
                if let agg = AggregationFunction(rawValue: aggRaw) {
                    config.setAggregation(agg, forField: "yAxis", column: column)
                }
            }
        }

        // Apply filters if provided
        if let filterArray = json["filters"] as? [[String: String]] {
            for filterDict in filterArray {
                guard let field = filterDict["field"],
                      let opRaw = filterDict["operator"],
                      let op = ChartFilterCondition.ChartFilterOperator(rawValue: opRaw) else { continue }
                let value = filterDict["value"] ?? ""
                config.filters.append(ChartFilterCondition(field: field, filterOperator: op, value: value))
            }
        }

        pendingBlockCreations.append(BlockCreationRequest(
            kind: .chart,
            title: title,
            config: config
        ))

        return "Chart block '\(title)' created: \(chartType.displayName) chart on \(tableName) (x: \(xAxis), y: \(yAxisColumns.joined(separator: ", ")))"
    }

    // MARK: - Create Text Block

    private func executeCreateTextBlock(json: [String: Any]) -> String {
        guard let content = json["content"] as? String else {
            return "Error: content is required for create_text_block"
        }

        pendingBlockCreations.append(BlockCreationRequest(
            kind: .text,
            title: "",
            textContent: content
        ))

        return "Text block created."
    }

    // MARK: - Cleanup

    func cleanup() async {
        await driverSession.disconnect()
    }

    // MARK: - Helpers

    private func parseArguments(_ arguments: String) -> [String: Any] {
        guard let data = arguments.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return [:]
        }
        return json
    }

    // MARK: - Static Tool Definitions

    private let listTablesTool = OpenAIChatCompletionRequestBody.Tool.function(
        name: "list_tables",
        description: "Lists all tables and collections in a database connection. Call this first to discover available data.",
        parameters: [
            "type": .string("object"),
            "properties": .object([
                "connection_keychain_id": .object([
                    "type": .string("string"),
                    "description": .string("The keychainId of the connection to query"),
                ]),
                "schema_name": .object([
                    "type": .string("string"),
                    "description": .string("Schema name to list tables from (optional, e.g. 'public' for PostgreSQL)"),
                ]),
            ]),
            "required": .array([.string("connection_keychain_id")]),
        ],
        strict: nil
    )

    private let getTableSchemaTool = OpenAIChatCompletionRequestBody.Tool.function(
        name: "get_table_schema",
        description: "Gets detailed column information for a table: names, data types, primary keys, foreign keys, and constraints.",
        parameters: [
            "type": .string("object"),
            "properties": .object([
                "connection_keychain_id": .object([
                    "type": .string("string"),
                    "description": .string("The keychainId of the connection"),
                ]),
                "table_name": .object([
                    "type": .string("string"),
                    "description": .string("The table name to get schema for"),
                ]),
                "schema_name": .object([
                    "type": .string("string"),
                    "description": .string("Schema name (optional, e.g. 'public' for PostgreSQL)"),
                ]),
            ]),
            "required": .array([.string("connection_keychain_id"), .string("table_name")]),
        ],
        strict: nil
    )
}
