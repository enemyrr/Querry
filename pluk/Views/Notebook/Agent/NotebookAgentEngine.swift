import Foundation

// MainActor-only: produced and consumed within @MainActor engine/controller.
// toolCalls uses [String: Any] because tool inputs pass through JSONSerialization before execution.
struct AgentRoundResult {
    let text: String
    let toolCalls: [(id: String, name: String, input: [String: Any])]
    let responseContent: [ResponseContentBlock]
}

struct BlockCreationRequest {
    let kind: NotebookBlockKind
    let title: String
    var config: ChartBlockConfig?
    var textContent: String?
    var singleValueConfig: SingleValueBlockConfig?
}

struct NotebookInfoUpdate {
    let title: String
    let description: String
}

@Observable
@MainActor
final class NotebookAgentEngine {

    private(set) var pendingBlockCreations: [BlockCreationRequest] = []
    private(set) var pendingNotebookInfoUpdate: NotebookInfoUpdate?

    private let driverSession = AgentDriverSession()

    func clearPendingCreations() {
        pendingBlockCreations.removeAll()
        pendingNotebookInfoUpdate = nil
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
        You are an expert data analyst embedded in Pluk, a database notebook for macOS. You build narrative-driven notebook pages — combining charts, exploratory queries, and written commentary to tell a clear data story backed by real numbers.

        <available_connections>
        \(connectionList)
        </available_connections>

        <tools>
        - `list_tables` — Discover tables in a connection
        - `get_table_schema` — Column names, types, keys, constraints
        - `run_query` — Execute a read-only SQL query (results returned to you only, not shown in notebook)
        - `set_notebook_info` — Set the notebook title and description
        - `create_chart_block` — Add a chart visualization to the notebook
        - `create_single_value_block` — Add a single-number KPI (e.g. total count, sum, average)
        - `create_text_block` — Add markdown text (headings, analysis, commentary)
        </tools>

        <chart_types>
        \(chartTypes)
        </chart_types>

        <aggregation_functions>
        \(aggregations)

        Choose aggregation based on what the chart answers:
        - "How many?" → `count` (orders per status, users per plan)
        - "How much total?" → `sum` (only for additive measures: revenue, quantity, amount)
        - "What's typical?" → `average` (average order value, response time)
        - "What's the range?" → `min` / `max` (earliest date, cheapest item)
        - "How many unique?" → `countDistinct` (unique customers per region)
        - "Raw values" → `none` (pre-aggregated data, rare)

        `sum` only applies to measurable quantities. Summing IDs, ratings, or years is meaningless — use `count` or `average`.
        Pie charts default to `count` (parts of a whole). Use `sum` only when the user asks for a totaled measure.
        Line charts over time: `sum` for cumulative metrics, `average` for rate metrics.
        When unsure, run a quick `run_query` to see the data before choosing.
        </aggregation_functions>

        <use_parallel_tool_calls>
        If you intend to call multiple tools and there are no dependencies between them, make all independent calls in parallel. For example, call `get_table_schema` on several tables simultaneously, or run multiple `run_query` calls at once. Only call tools sequentially when one result is needed to inform the next call.
        </use_parallel_tool_calls>

        <thinking_guidance>
        After receiving tool results, reflect on their quality and determine optimal next steps before proceeding. Use your thinking to:
        - Evaluate whether query results make sense or need investigation
        - Plan which sections to build and in what order
        - Decide on the right chart type and aggregation based on the data shape
        - Identify anomalies or unexpected patterns worth highlighting
        </thinking_guidance>

        <workflow>
        Work in three phases:

        Phase 1 — Discover & Plan:
        1. Call `list_tables` and `get_table_schema` on relevant tables (in parallel when possible).
        2. Run exploratory queries — row counts, date ranges, cardinalities, distributions.
        3. Call `set_notebook_info` with a descriptive title and 1-2 sentence summary citing real numbers.
        4. Create up to 4 `create_single_value_block` calls for the top-level KPIs. These appear as a summary row at the top.
        5. Create an intro `create_text_block` with a dataset overview and numbered table of contents listing 4-6 sections you will build.

        Phase 2 — Build Each Section:
        For each planned section, in order:
        1. `run_query` to gather the data you need for commentary.
        2. `create_chart_block` — visualization first.
        3. `create_text_block` — commentary after the chart.

        Always interleave: chart → text, chart → text. Keep calling tools until every planned section is complete.

        Phase 3 — Wrap Up:
        Only stop when every section from your plan has been created. If you want to share progress, include it alongside a tool call rather than as a standalone message.
        When you are done, send a short completion message (2-3 sentences max). Mention what was built at a high level — e.g. the types of blocks created (KPIs, charts, commentary, tables) and total count. Do not list every block individually and do not create markdown tables or structured reports in the chat. Keep it casual and concise like: "Done — all 12 cells are now in the notebook: the intro, KPI metrics, charts, and commentary blocks. The underlying SQL queries are excluded since they're just intermediate data."
        </workflow>

        <writing_style>
        - Do not use emoji anywhere — not in text blocks, chart titles, KPI labels, or chat messages. Keep a clean, professional tone throughout.
        - Number section headings: "## 1. Revenue by Category"
        - Use em dashes (—) instead of parenthetical asides
        - Cite specific numbers: "Revenue grew 440x from $1.2K to $528K" not "Revenue grew significantly"
        - Bold key metrics: **$528K**, **3.2x growth**, **42% of total**
        - Keep commentary to 2-4 sentences per chart — dense with insight, no filler
        - End each section with a business conclusion or actionable takeaway
        - Professional but direct tone, like a senior analyst presenting to stakeholders
        </writing_style>

        <rules>
        - Always call `get_table_schema` before using column names — do not guess.
        - Every statistic in commentary must come from a `run_query` result.
        - Prefer numeric columns for Y axis, categorical/date for X axis.
        - If no connection is selected, ask the user to pick one from the connection picker.
        - `run_query` results are returned to you only. Use `create_chart_block` and `create_text_block` to add content to the notebook.
        - If a query returns unexpected data (nulls, zeros, outliers, empty results), run a follow-up query to investigate before drawing conclusions. Surface anomalies in your commentary.
        - For comprehensive reports, cover: overview/summary, key breakdowns, trends over time, and notable outliers. For narrow questions, just answer what was asked.
        </rules>
        """
    }

    // MARK: - Tool Definitions

    func buildTools(connections: [Connection]) -> [AnthropicToolDefinition] {
        var tools: [AnthropicToolDefinition] = [
            listTablesTool,
            getTableSchemaTool,
            runQueryTool,
            setNotebookInfoTool,
        ]
        tools.append(contentsOf: NotebookBlockKind.allToolDefinitions)
        return tools
    }

    // MARK: - API Round (Streaming)

    func performRound(
        messages: [AnthropicMessage],
        connections: [Connection],
        onToken: @MainActor @Sendable (String) -> Void = { _ in },
        onThinking: @MainActor @Sendable (String) -> Void = { _ in }
    ) async throws -> AgentRoundResult {
        let tools = buildTools(connections: connections)
        let systemPrompt = buildSystemPrompt(connections: connections)

        print("[AgentEngine] performRound — sending \(messages.count) messages, \(tools.count) tools, \(connections.count) connections")

        let response = try await BedrockService.shared.messageRequestStream(
            messages: messages,
            system: systemPrompt,
            tools: tools,
            onTextDelta: onToken,
            onThinkingDelta: onThinking
        )

        print("[AgentEngine] response received — \(response.content.count) content blocks, stopReason: \(response.stopReason ?? "nil")")
        for (i, block) in response.content.enumerated() {
            switch block {
            case .text(let t):
                print("[AgentEngine]   block[\(i)] text (\(t.count) chars): \(String(t.prefix(200)))")
            case .thinking(let t, let sig):
                print("[AgentEngine]   block[\(i)] thinking (\(t.count) chars, sig: \(sig.prefix(20))...): \(String(t.prefix(200)))")
            case .toolUse(let id, let name, let input):
                let inputStr = input.map { "\($0.key): \($0.value)" }.joined(separator: ", ")
                print("[AgentEngine]   block[\(i)] toolUse id=\(id) name=\(name) input={\(inputStr)}")
            }
        }

        let text = response.content.compactMap { content -> String? in
            guard case .text(let t) = content else { return nil }
            return t
        }.joined()

        let toolCalls: [(id: String, name: String, input: [String: Any])] = response.content.compactMap { content in
            guard case .toolUse(let id, let name, let input) = content else { return nil }
            return (id: id, name: name, input: sendableToAny(input))
        }

        print("[AgentEngine] parsed — text: \(text.count) chars, toolCalls: \(toolCalls.count)")

        return AgentRoundResult(
            text: text,
            toolCalls: toolCalls,
            responseContent: response.content
        )
    }

    // MARK: - Tool Execution

    func executeToolCall(
        _ toolCall: (id: String, name: String, input: [String: Any]),
        connections: [Connection]
    ) async -> String {
        let json = toolCall.input

        let inputStr = json.map { "\($0.key): \($0.value)" }.joined(separator: ", ")
        print("[AgentEngine] executeToolCall — name=\(toolCall.name) id=\(toolCall.id) input={\(inputStr)}")

        let result: String
        switch toolCall.name {
        case "list_tables":
            result = await executeListTables(json: json, connections: connections)
        case "get_table_schema":
            result = await executeGetTableSchema(json: json, connections: connections)
        case "run_query":
            result = await executeRunQuery(json: json, connections: connections)
        case "create_chart_block":
            result = executeCreateChartBlock(json: json)
        case "create_single_value_block":
            result = executeCreateSingleValueBlock(json: json)
        case "create_text_block":
            result = executeCreateTextBlock(json: json)
        case "set_notebook_info":
            result = executeSetNotebookInfo(json: json)
        default:
            result = "Unknown tool: \(toolCall.name)"
        }

        print("[AgentEngine] toolResult — name=\(toolCall.name) result (\(result.count) chars): \(String(result.prefix(500)))")
        return result
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

        guard let conn = resolveConnection(json: json, connections: connections) else {
            return "Error: No connection available"
        }

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

    // MARK: - Run Query

    private static let blockedPrefixes = ["INSERT", "UPDATE", "DELETE", "DROP", "ALTER", "TRUNCATE", "CREATE"]

    private func executeRunQuery(json: [String: Any], connections: [Connection]) async -> String {
        guard let query = json["query"] as? String else {
            return "Error: query is required"
        }

        let trimmedUpper = query.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        if Self.blockedPrefixes.contains(where: { trimmedUpper.hasPrefix($0) }) {
            return "Error: run_query only supports read-only SELECT queries. Write operations are not allowed."
        }

        let schemaName = json["schema_name"] as? String

        guard let conn = resolveConnection(json: json, connections: connections) else {
            return "Error: No connection available"
        }

        do {
            try await driverSession.connect(
                databaseType: conn.databaseType,
                uri: conn.connectionUri,
                keychainId: conn.keychainId,
                databaseName: conn.defaultDatabase ?? ""
            )
            let results = try await driverSession.executeRawQuery(query, schema: schemaName)
            return formatQueryResults(results)
        } catch {
            return "Error executing query: \(error.localizedDescription)"
        }
    }

    private func formatQueryResults(_ results: [QueryResult]) -> String {
        guard let result = results.first else {
            return "Query executed successfully. No results returned."
        }

        let columns = result.columns.map(\.name)
        guard !columns.isEmpty else {
            return "Query executed successfully. No columns returned."
        }

        let maxRows = 50
        let maxCellWidth = 100
        let rows = result.rows.prefix(maxRows)

        var table: [[String]] = []
        table.append(columns)

        for row in rows {
            let cells = columns.map { col -> String in
                guard let info = row[col] else { return "NULL" }
                let str = info.value.map { "\($0)" } ?? "NULL"
                if str.count > maxCellWidth {
                    return String(str.prefix(maxCellWidth - 3)) + "..."
                }
                return str
            }
            table.append(cells)
        }

        var colWidths = columns.indices.map { i in
            table.map { $0[i].count }.max() ?? 0
        }
        for i in colWidths.indices {
            colWidths[i] = min(colWidths[i], maxCellWidth)
        }

        func formatRow(_ cells: [String]) -> String {
            cells.enumerated().map { i, cell in
                cell.padding(toLength: colWidths[i], withPad: " ", startingAt: 0)
            }.joined(separator: " | ")
        }

        var output = formatRow(table[0]) + "\n"
        output += colWidths.map { String(repeating: "-", count: $0) }.joined(separator: " | ") + "\n"
        for row in table.dropFirst() {
            output += formatRow(row) + "\n"
        }

        let totalRows = result.rows.count
        if totalRows > maxRows {
            output += "... (\(totalRows) total rows, showing first \(maxRows))\n"
        } else {
            output += "\(totalRows) row(s) returned.\n"
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

        if let aggs = json["aggregations"] as? [String: String] {
            for (column, aggRaw) in aggs {
                if let agg = AggregationFunction(rawValue: aggRaw) {
                    config.setAggregation(agg, forField: "yAxis", column: column)
                }
            }
        } else if chartType == .pie {
            for column in yAxisColumns {
                config.setAggregation(.count, forField: "yAxis", column: column)
            }
        }

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

    // MARK: - Create Single Value Block

    private func executeCreateSingleValueBlock(json: [String: Any]) -> String {
        guard let keychainId = json["connection_keychain_id"] as? String,
              let connName = json["connection_name"] as? String,
              let dbType = json["database_type"] as? String,
              let dbName = json["database_name"] as? String,
              let tableName = json["table_name"] as? String,
              let column = json["column"] as? String,
              let aggRaw = json["aggregation"] as? String,
              let title = json["title"] as? String else {
            return "Error: Missing required parameters for create_single_value_block."
        }

        let aggregation = AggregationFunction(rawValue: aggRaw) ?? .count
        let schemaName = json["schema_name"] as? String
        let label = json["label"] as? String

        var singleValueCfg = SingleValueBlockConfig(
            connectionKeychainId: keychainId,
            connectionName: connName,
            databaseType: dbType,
            databaseName: dbName,
            schemaName: schemaName,
            tableName: tableName,
            column: column,
            aggregation: aggregation,
            label: label
        )

        if let filterArray = json["filters"] as? [[String: String]] {
            for filterDict in filterArray {
                guard let field = filterDict["field"],
                      let opRaw = filterDict["operator"],
                      let op = ChartFilterCondition.ChartFilterOperator(rawValue: opRaw) else { continue }
                let value = filterDict["value"] ?? ""
                singleValueCfg.filters.append(ChartFilterCondition(field: field, filterOperator: op, value: value))
            }
        }

        pendingBlockCreations.append(BlockCreationRequest(
            kind: .singleValue,
            title: title,
            singleValueConfig: singleValueCfg
        ))

        return "Single value block '\(title)' created: \(aggregation.displayName) of \(column) from \(tableName)"
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

    // MARK: - Set Notebook Info

    private func executeSetNotebookInfo(json: [String: Any]) -> String {
        guard let title = json["title"] as? String else {
            return "Error: title is required for set_notebook_info"
        }
        let description = json["description"] as? String ?? ""

        pendingNotebookInfoUpdate = NotebookInfoUpdate(title: title, description: description)

        return "Notebook info updated: title='\(title)'"
    }

    // MARK: - Cleanup

    func cleanup() async {
        await driverSession.disconnect()
    }

    // MARK: - Helpers

    private func resolveConnection(json: [String: Any], connections: [Connection]) -> Connection? {
        if let keychainId = json["connection_keychain_id"] as? String {
            return connections.first { $0.keychainId == keychainId }
        }
        return connections.first
    }

    private func sendableToAny(_ input: [String: any Sendable]) -> [String: Any] {
        input.mapValues { $0 as Any }
    }

    nonisolated static func anyToJSONValues(_ input: [String: any Sendable]) -> [String: JSONValue] {
        input.mapValues { JSONValue.fromAny($0) }
    }

    // MARK: - Anthropic Tool Definitions

    private let listTablesTool = AnthropicToolDefinition(
        name: "list_tables",
        description: "Lists all tables and collections in a database connection. Call this first to discover available data.",
        inputSchema: [
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
        ]
    )

    private let runQueryTool = AnthropicToolDefinition(
        name: "run_query",
        description: "Execute a read-only SQL query to explore data. Use this to gather specific numbers, distributions, and statistics before building charts and writing commentary. Results are returned to you for analysis but are NOT added to the notebook.",
        inputSchema: [
            "type": .string("object"),
            "properties": .object([
                "connection_keychain_id": .object([
                    "type": .string("string"),
                    "description": .string("The keychainId of the connection to query"),
                ]),
                "query": .object([
                    "type": .string("string"),
                    "description": .string("A read-only SQL query (SELECT only). Used for data exploration — results are returned to you but NOT added to the notebook."),
                ]),
                "schema_name": .object([
                    "type": .string("string"),
                    "description": .string("Schema name (optional, e.g. 'public' for PostgreSQL)"),
                ]),
            ]),
            "required": .array([.string("connection_keychain_id"), .string("query")]),
        ]
    )

    private let setNotebookInfoTool = AnthropicToolDefinition(
        name: "set_notebook_info",
        description: "Sets the notebook title and description. Call this early in the workflow to give the notebook a meaningful name based on the data being analyzed.",
        inputSchema: [
            "type": .string("object"),
            "properties": .object([
                "title": .object([
                    "type": .string("string"),
                    "description": .string("A concise, descriptive title for the notebook (e.g. 'Sales Performance Report', 'User Growth Analysis')"),
                ]),
                "description": .object([
                    "type": .string("string"),
                    "description": .string("A 1-2 sentence description summarizing what this notebook analyzes"),
                ]),
            ]),
            "required": .array([.string("title")]),
        ]
    )

    private let getTableSchemaTool = AnthropicToolDefinition(
        name: "get_table_schema",
        description: "Gets detailed column information for a table: names, data types, primary keys, foreign keys, and constraints.",
        inputSchema: [
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
        ]
    )
}
