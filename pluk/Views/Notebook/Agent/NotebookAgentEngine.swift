import Foundation
import AIProxy

struct AgentRoundResult {
    let streamedText: String
    let toolCalls: [(id: String, name: String, arguments: String)]
    let reasoningSummary: String?
    let responseId: String?
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
        You build rich, narrative-driven notebook pages — combining charts, exploratory queries, and written commentary to tell a clear data story backed by real numbers.

        ## Available Connections
        \(connectionList)

        ## Your Tools
        | Tool | Purpose |
        |------|---------|
        | `list_tables` | Discover tables in a connection |
        | `get_table_schema` | Column names, types, keys, constraints |
        | `run_query` | Execute a read-only SQL query and get results (for exploration — results are NOT added to the notebook) |
        | `create_chart_block` | Add a chart visualization to the notebook |
        | `create_text_block` | Add markdown text (headings, analysis, commentary) |

        ## Chart Types
        \(chartTypes)

        ## Aggregation Functions (for Y axis columns)
        \(aggregations)

        ## Choosing the Right Aggregation
        Think about what the chart is trying to answer before picking an aggregation:
        - **"How many?"** → `count` — distribution of rows across categories (e.g., orders per status, users per plan)
        - **"How much total?"** → `sum` — only when the column is an additive measure like revenue, quantity, or amount
        - **"What's typical?"** → `average` — e.g., average order value, average response time
        - **"What's the range?"** → `min` / `max` — e.g., earliest/latest date, cheapest/most expensive item
        - **"How many unique?"** → `countDistinct` — e.g., unique customers per region
        - **"Just plot raw values"** → `none` — when data is already one-row-per-point (rare, usually pre-aggregated)

        Key rules:
        - `sum` only makes sense on columns that represent measurable quantities (revenue, weight, hours). Summing an ID, a rating, or a year column is meaningless — use `count` or `average` instead.
        - For **pie charts**, prefer `count` as the default. Pie charts show parts of a whole, and counting rows per category naturally represents 100% of the data. Only use `sum` when the user explicitly asks for a totaled measure (e.g., "revenue share by region"). When using `count`, set `y_axis_columns` to the same column as `x_axis_column`.
        - For **bar/column charts** showing "top N" or "breakdown by category", `count` is usually correct unless the user asks about a specific measure.
        - For **line charts** showing trends over time, `sum` or `average` are typical — sum for cumulative metrics (daily revenue), average for rate metrics (avg response time per day).
        - When unsure, run a quick `run_query` (e.g., `SELECT column, COUNT(*) ... GROUP BY column`) to see what the data looks like before committing to an aggregation.

        ## Three-Phase Workflow

        ### Phase 1 — Discover, Explore & Plan
        1. Call `list_tables` to see available tables.
        2. Call `get_table_schema` on relevant tables to learn columns.
        3. Use `run_query` to run exploratory queries — row counts, date ranges, cardinalities, distributions, top-N breakdowns. Gather enough data to understand the shape and story of the dataset.
        4. **Create the plan**: Once you understand the data, decide on 4-6 numbered analysis sections. Then call `create_text_block` to add a report introduction that includes a brief overview of the dataset (row count, date range, key dimensions — citing real numbers from your queries) and a numbered table of contents listing every section you will build. Example:

        ```
        # Sales Performance Report
        This report analyzes **12,450 orders** spanning **Jan 2019 – Dec 2023** across **4 product categories** and **38 regions**.

        **Sections:**
        1. Revenue by Category
        2. Monthly Growth Trend
        3. Regional Breakdown
        4. Average Order Value Analysis
        5. Top Customers
        ```

        This intro block is your contract — you MUST build every section listed in it.

        ### Phase 2 — Build Every Planned Section
        Work through the sections from your plan one by one. For EACH section:
        1. `run_query` — gather the specific data points you need for commentary.
        2. `create_chart_block` — add the visualization **first**.
        3. `create_text_block` — add commentary **after** the chart.

        The chart always comes BEFORE its commentary text. Never reverse this.
        NEVER batch all charts together or all text together. Always interleave: chart → text, chart → text.

        **CRITICAL**: You MUST keep calling tools until every section from your plan is created. Do NOT emit a text-only response until the entire report — all sections plus the summary — is complete. Every response you send must include at least one tool call until you are completely done. If you want to share progress (e.g., "Now analyzing revenue trends..."), include it alongside a tool call in the same response, never as a standalone message.

        ## Writing Style for Text Blocks
        - Number section headings: "## 1. Revenue by Category", "## 2. Growth Over Time"
        - Use em dashes (—) instead of parenthetical asides
        - Always cite specific numbers: "Revenue grew 440x from $1.2K to $528K" not "Revenue grew significantly"
        - Bold key metrics: **$528K**, **3.2x growth**, **42% of total**
        - Keep commentary to 2-4 sentences per chart — dense with insight, no filler
        - End each section with a business conclusion or actionable takeaway
        - Write in a professional but direct tone, like a senior analyst presenting to stakeholders

        ## Anomaly Investigation
        If a `run_query` returns unexpected data (nulls, zeros, extreme outliers, empty results), run a follow-up query to investigate before drawing conclusions. Surface anomalies explicitly in your commentary.

        ## Comprehensive by Default
        - Always produce a comprehensive, multi-chart report unless the user explicitly asks for something specific
        - A comprehensive report should cover: overview/summary, key breakdowns by relevant dimensions, trends over time (if date columns exist), and notable outliers or comparisons
        - Aim for 4-6 chart+text sections — enough to tell a complete story. You MUST create all planned sections before finishing.
        - If the user asks a narrow question (e.g., "show me revenue by category"), just answer that — don't over-expand
        - NEVER stop after creating just 1 or 2 sections when a comprehensive report was requested. Keep going until all sections are built.

        ## Rules
        - NEVER guess column names. Always call `get_table_schema` first.
        - NEVER fabricate numbers. Every statistic must come from a `run_query` result.
        - Prefer numeric columns for Y axis, categorical/date for X axis.
        - If no connection is selected, ask the user to pick one from the connection picker.
        - `run_query` is for exploration only — its results are returned to you but NOT shown in the notebook. Use `create_chart_block` and `create_text_block` for notebook content.
        - You can call `list_tables` and `get_table_schema` in parallel when you already know the table name.
        """
    }

    // MARK: - Tool Definitions

    func buildTools(connections: [Connection]) -> [OpenAICreateResponseRequestBody.Tool] {
        var tools: [OpenAICreateResponseRequestBody.Tool] = [
            listTablesTool,
            getTableSchemaTool,
            runQueryTool,
        ]
        tools.append(contentsOf: NotebookBlockKind.allOpenAITools)
        return tools
    }

    // MARK: - Streaming Round (Responses API)

    func performRound(
        input: OpenAIResponse.Input,
        previousResponseId: String?,
        connections: [Connection],
        onToken: @escaping @MainActor @Sendable (String) -> Void,
        onReasoning: @escaping @MainActor @Sendable (String) -> Void
    ) async throws -> AgentRoundResult {
        let openAIService = AIProxy.openAIService(
            partialKey: Self.partialKey,
            serviceURL: Self.serviceURL
        )
        let tools = buildTools(connections: connections)

        let requestBody = OpenAICreateResponseRequestBody(
            input: input,
            instructions: buildSystemPrompt(connections: connections),
            model: "gpt-5.1",
            parallelToolCalls: true,
            previousResponseId: previousResponseId,
            reasoning: .init(effort: .medium, summary: .auto),
            tools: tools,
            truncation: .auto
        )

        let stream = try await openAIService.createStreamingResponse(
            requestBody: requestBody,
            secondsToWait: 60
        )

        var streamedContent = ""
        var reasoningSummary = ""
        var responseId: String?

        struct PendingFunctionCall {
            var callId: String
            var name: String
            var arguments: String
        }
        var pendingFunctionCalls: [Int: PendingFunctionCall] = [:]

        for try await event in stream {
            guard !Task.isCancelled else { throw CancellationError() }

            switch event {
            case .outputTextDelta(let delta):
                streamedContent += delta.delta
                onToken(delta.delta)

            case .functionCallArgumentsDelta(let delta):
                let index = delta.outputIndex ?? 0
                pendingFunctionCalls[index, default: PendingFunctionCall(callId: "", name: "", arguments: "")].arguments += delta.delta

            case .outputItemAdded(let item):
                if case .functionCall(let fc) = item.item {
                    let index = item.index ?? 0
                    var entry = pendingFunctionCalls[index, default: PendingFunctionCall(callId: "", name: "", arguments: "")]
                    entry.callId = fc.callId
                    entry.name = fc.name
                    pendingFunctionCalls[index] = entry
                }

            case .functionCallArgumentsDone(let done):
                let index = done.outputIndex ?? 0
                pendingFunctionCalls[index, default: PendingFunctionCall(callId: "", name: "", arguments: "")].arguments = done.arguments

            case .reasoningSummaryTextDelta(let delta):
                reasoningSummary += delta.delta
                onReasoning(delta.delta)

            case .responseCompleted(let completed):
                responseId = completed.response.id

            case .error(let errorEvent):
                throw NSError(
                    domain: "NotebookAgentEngine",
                    code: -1,
                    userInfo: [NSLocalizedDescriptionKey: "API error (\(errorEvent.code)): \(errorEvent.message)"]
                )

            default:
                break
            }
        }

        let toolCalls = pendingFunctionCalls
            .sorted { $0.key < $1.key }
            .map { (id: $0.value.callId, name: $0.value.name, arguments: $0.value.arguments) }

        return AgentRoundResult(
            streamedText: streamedContent,
            toolCalls: toolCalls,
            reasoningSummary: reasoningSummary.isEmpty ? nil : reasoningSummary,
            responseId: responseId
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
        case "run_query":
            return await executeRunQuery(json: json, connections: connections)
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

    private let listTablesTool = OpenAICreateResponseRequestBody.Tool.function(
        OpenAICreateResponseRequestBody.FunctionTool(
            name: "list_tables",
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
            strict: false,
            description: "Lists all tables and collections in a database connection. Call this first to discover available data."
        )
    )

    private let runQueryTool = OpenAICreateResponseRequestBody.Tool.function(
        OpenAICreateResponseRequestBody.FunctionTool(
            name: "run_query",
            parameters: [
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
            ],
            strict: false,
            description: "Execute a read-only SQL query to explore data. Use this to gather specific numbers, distributions, and statistics before building charts and writing commentary. Results are returned to you for analysis but are NOT added to the notebook."
        )
    )

    private let getTableSchemaTool = OpenAICreateResponseRequestBody.Tool.function(
        OpenAICreateResponseRequestBody.FunctionTool(
            name: "get_table_schema",
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
            strict: false,
            description: "Gets detailed column information for a table: names, data types, primary keys, foreign keys, and constraints."
        )
    )
}
