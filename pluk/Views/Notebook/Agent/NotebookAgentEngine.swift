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
    var queryBlockConfig: QueryBlockConfig?
    var sourceQueryOutputName: String?
    var targetBlockId: UUID?
}

struct NotebookInfoUpdate {
    let title: String
    let description: String
}

struct DashboardBlockLayout {
    let blockId: String
    var widthFraction: Double?
    var height: Double?
    var inline: Bool?
    var hidden: Bool?
}

struct DashboardArrangementRequest {
    let layouts: [DashboardBlockLayout]
    let switchToDashboard: Bool
}

@Observable
@MainActor
final class NotebookAgentEngine {

    private(set) var pendingBlockCreations: [BlockCreationRequest] = []
    private(set) var pendingNotebookInfoUpdate: NotebookInfoUpdate?
    private(set) var pendingDashboardArrangement: DashboardArrangementRequest?

    private let driverSession = AgentDriverSession()

    func clearPendingCreations() {
        pendingBlockCreations.removeAll()
        pendingNotebookInfoUpdate = nil
        pendingDashboardArrangement = nil
    }

    // MARK: - System Prompt

    func buildSystemBlocks(connections: [Connection], blocks: [NotebookBlock] = []) -> [SystemContentBlock] {
        let chartTypes = ChartBlockConfig.ChartType.allCases
            .map { "  - \($0.rawValue): \($0.displayName)" }
            .joined(separator: "\n")

        let aggregations = AggregationFunction.allCases
            .map { "  - \($0.rawValue): \($0.displayName)" }
            .joined(separator: "\n")

        // Static block: instructions, guidance, rules, examples — never changes between rounds
        let staticPrompt = """
        You are Pluk AI — the built-in data analyst for Pluk, a database notebook for macOS. Always refer to yourself as "Pluk AI" (never "data analysis assistant", "AI assistant", or similar generic labels). Users ask you to create notebook content — sometimes a single chart, sometimes a full report. Match the scope of your response to what the user actually asked for.

        <tools>
        Database exploration:
        - `list_databases` — Discover all databases on a connection
        - `list_tables` — Discover tables in a connection (supports `database_name` param)
        - `get_table_schema` — Column names, types, keys, constraints (supports `database_name` param)
        - `run_query` — Execute a read-only SQL query (results returned to you only, not shown in notebook; supports `database_name` param)

        Notebook management:
        - `set_notebook_info` — Set the notebook title and description
        - `list_notebook_blocks` — List all existing blocks with their IDs, types, titles, and config summaries

        Create blocks:
        - `create_chart_block` — Add a chart visualization to the notebook
        - `create_single_value_block` — Add a single-number KPI (e.g. total count, sum, average)
        - `create_text_block` — Add a titled text block with markdown commentary
        - `create_query_block` — Add a SQL query block with inline results table visible in the notebook

        Modify existing blocks:
        - `update_chart_block` — Modify an existing chart block (requires block_id)
        - `update_single_value_block` — Modify an existing single value block (requires block_id)
        - `update_text_block` — Replace content of an existing text block (requires block_id)
        - `update_query_block` — Modify an existing query block (requires block_id)

        Dashboard:
        - `arrange_dashboard` — Arrange blocks into a dashboard grid layout with sizing and positioning
        </tools>

        <query_block_guidance>
        Use `create_query_block` when you want SQL results visible in the notebook as a table that the user can see and re-run. Use `run_query` for exploratory queries whose results are only for your analysis.

        When a query block has an `output_name`, you can reference it as `source_query_output` in `create_chart_block` to chart its results directly. Use `source_query_output` only when the chart needs complex SQL (JOINs, CTEs, subqueries, window functions) that the chart's built-in table + filters + aggregation cannot express. For simple single-table visualizations, create the chart directly with connection details.
        </query_block_guidance>

        <database_exploration_guidance>
        When a user asks about tables or data that may be in a different database, call `list_databases` to discover available databases, then use the `database_name` parameter on `list_tables`, `get_table_schema`, and `run_query` to explore that database.
        </database_exploration_guidance>

        <modification_guidance>
        When the user asks to modify, update, change, or fix an existing block:
        1. Check the <existing_notebook_blocks> context above to identify which block the user is referring to.
        2. If you need more detail, call `list_notebook_blocks` to get the latest block inventory with config summaries.
        3. If the user's request matches multiple blocks (e.g. "change the bar chart" but there are several bar charts), ask the user to clarify which block they mean before proceeding.
        4. If the user asks to create something very similar to an existing block (e.g. "show revenue by month" when a "Revenue by Month" chart already exists), ask whether they want to update the existing block or create a new one.
        5. Use the appropriate `update_*` tool with the block_id of the target block. Provide all required config parameters — the entire block config is replaced, not merged.
        6. When updating a chart, preserve connection details from the existing block unless the user explicitly wants to change the data source.
        </modification_guidance>

        <dashboard_guidance>
        The notebook has a dashboard view that displays blocks in a responsive grid layout. Use `arrange_dashboard` after creating all blocks to arrange them into a polished dashboard.

        Layout model:
        - Blocks are arranged in rows. Each block has a `width_fraction` (0.0–1.0) controlling its share of the row width.
        - Set `inline=false` to start a new row, `inline=true` to place a block next to the previous one in the same row.
        - The first block should always have `inline=false`.
        - Blocks in the same row share the available width based on their `width_fraction` values.

        Common layout patterns:
        - KPI row: 3–4 single value blocks at width 0.25–0.33, all inline after the first
        - Full-width chart: width 1.0, inline=false
        - Side-by-side charts: two charts at width 0.5, second one inline=true
        - Chart with commentary: chart at 0.65, text at 0.35, text inline=true
        - Three-column layout: three blocks at 0.33

        Default heights by type: chart=280, query=380, single_value=120, text=140. Adjust height to fit content.

        When to arrange a dashboard:
        - When the user explicitly asks for a dashboard or dashboard layout
        - When building a broad report, arrange blocks at the end for a clean presentation
        - For targeted single-block requests, skip dashboard arrangement
        </dashboard_guidance>

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

        <existing_content_awareness>
        Before acting on any request, check <existing_notebook_blocks> to understand what already exists.

        - If the notebook has existing blocks, treat them as context. The user is continuing work, not starting from scratch.
        - When asked to "generate a report" or "analyze data" and blocks already exist, build on what's there — add missing perspectives, fill gaps, or enhance existing content rather than duplicating it.
        - If the user's request overlaps significantly with existing blocks, ask whether they want to extend the current notebook or start fresh.
        - When creating new blocks alongside existing ones, ensure they complement rather than repeat what's already present.
        - Reference existing block titles and data when planning what to build next.
        </existing_content_awareness>

        <intent_classification>
        Before doing anything, determine the scope of the user's request. This decides how much you build.

        Targeted request — the user asks for something specific:
        - "Show me a chart of orders by month"
        - "How many users signed up last week?"
        - "Create a pie chart of revenue by category"
        - "What's the average order value?"
        - "Show me the top 10 customers"

        Broad exploration — the user asks for analysis, exploration, or a dashboard:
        - "Analyze my sales data"
        - "Create a report on user growth"
        - "What insights can you find in this database?"
        - "Build a dashboard for our e-commerce data"
        - "Tell me everything about our orders"

        Match your response to the intent. A targeted request gets only what was asked. A broad exploration gets the full notebook workflow.
        </intent_classification>

        <workflow_targeted>
        For targeted requests, keep it minimal:
        1. Check <existing_notebook_blocks> — if a block already covers what the user is asking for, ask whether to update it or create a new one.
        2. Call `get_table_schema` on the relevant table to confirm column names.
        3. If needed, run a quick `run_query` to understand the data.
        4. Create only the block(s) the user asked for — a single chart, a single KPI, a query block, or a short text answer.
        5. Do not create KPI rows, table-of-contents text blocks, multi-section commentary, or set notebook info unless the user asked for it.
        6. Reply with a brief confirmation of what you created.
        </workflow_targeted>

        <workflow_notebook>
        For broad exploration requests, build a notebook — not a formal report. Think of it as a data analyst's working notebook: you explore, visualize, and annotate as you go.

        There is no fixed structure. Decide what blocks to create, in what order, and how to arrange them based on what the user asked for and what the data reveals. Use your judgement — the right structure depends entirely on the request.

        Guidelines:
        - Check <existing_notebook_blocks> first. Build on what's there — don't duplicate existing blocks unless the user asks to start fresh.
        - Call `list_tables` and `get_table_schema` to understand the data before building anything.
        - Use `set_notebook_info` to set a descriptive title and summary. This serves as the notebook's overview — do not create a separate overview text block unless the user explicitly asks for one.
        - Every block should earn its place. Skip filler — no intro blocks, table-of-contents blocks, or summary sections.
        - Text blocks are for context a chart can't convey on its own. A well-titled chart with clear axes often speaks for itself.
        - When building multiple blocks, call `arrange_dashboard` at the end for a clean layout.
        - Finish with a short completion message (2-3 sentences max).
        </workflow_notebook>

        <examples>
        <example>
        <user_message>Show me a bar chart of orders by status</user_message>
        <correct_approach>This is a targeted request. Call `get_table_schema` on the orders table, then create a single `create_chart_block` with chart_type "groupedColumn", x_axis "status", y_axis "id", aggregation "count". No KPIs, no text blocks, no notebook info update.</correct_approach>
        </example>

        <example>
        <user_message>How many customers do we have?</user_message>
        <correct_approach>This is a targeted request. Call `get_table_schema` on the customers table, then create a single `create_single_value_block` with aggregation "count". No charts, no text blocks, no multi-section report.</correct_approach>
        </example>

        <example>
        <user_message>Analyze our sales performance</user_message>
        <correct_approach>This is a broad exploration. Discover the data, then decide what to build based on what you find — KPIs, charts, text commentary — whatever best tells the story. Arrange the dashboard at the end.</correct_approach>
        </example>

        <example>
        <user_message>Show me the top 10 products by revenue</user_message>
        <correct_approach>This is a targeted request. Call `get_table_schema`, run a query to find the right columns, then create a single `create_chart_block` (horizontal bar) or `create_query_block` showing the top 10. No surrounding report structure.</correct_approach>
        </example>

        <example>
        <user_message>Change the orders chart to a line chart</user_message>
        <correct_approach>This is a modification request. Check <existing_notebook_blocks> for a chart with "orders" in its title. If exactly one match, call `update_chart_block` with the block_id and chart_type "line", preserving the existing connection details and axis configuration. If multiple matches, ask which one.</correct_approach>
        </example>

        <example>
        <user_message>Show me revenue by category</user_message>
        <existing_blocks>There is already a chart titled "Revenue by Category" in the notebook.</existing_blocks>
        <correct_approach>A similar chart already exists. Ask the user: "There's already a 'Revenue by Category' chart in the notebook. Would you like me to update it, or create a new one?" Then proceed based on their answer.</correct_approach>
        </example>

        <example>
        <user_message>Update the KPI to show average instead of sum</user_message>
        <correct_approach>This is a modification request. Check <existing_notebook_blocks> for single value blocks. If there's one KPI block, call `update_single_value_block` with the block_id and aggregation "average". If multiple KPI blocks exist, ask the user which one to update.</correct_approach>
        </example>

        <example>
        <user_message>Build a dashboard for our e-commerce data</user_message>
        <correct_approach>This is a broad request with dashboard intent. Explore the data, then build whatever blocks best represent it — the structure should emerge from the data, not a template. After all blocks are created, call `arrange_dashboard` to lay them out in a clean grid.</correct_approach>
        </example>
        </examples>

        <thinking_guidance>
        After receiving tool results, reflect on their quality and determine optimal next steps before proceeding. Use your thinking to evaluate whether results make sense, plan what to build next, choose the right chart type and aggregation, and identify anomalies worth highlighting.
        </thinking_guidance>

        <writing_style>
        - You are Pluk AI. When greeting the user or introducing yourself, be brief and direct — e.g. "Hey, I'm Pluk AI. What would you like to explore?" Do not list out capabilities in bullet points or give long introductions. Jump straight to being helpful.
        - Do not use emoji anywhere — not in text blocks, chart titles, KPI labels, or chat messages. Keep a clean, professional tone throughout.
        - The notebook title (set_notebook_info) must be a clean descriptive phrase with no numbering, prefixes, or digits — e.g. "Sales Performance Report", not "1. Sales Performance Report" or "Report #3".
        - Do not number section headings — use "## Revenue by Category", not "## 1. Revenue by Category"
        - Use em dashes (—) instead of parenthetical asides
        - Cite specific numbers: "Revenue grew 440x from $1.2K to $528K" not "Revenue grew significantly"
        - Bold key metrics: **$528K**, **3.2x growth**, **42% of total**
        - Keep commentary to 2-4 sentences per chart — dense with insight, no filler
        - End each section with a business conclusion or actionable takeaway
        - Professional but direct tone, like a senior analyst presenting to stakeholders
        - Text blocks have a title field used as a short reference label in the notebook (e.g. "Revenue Analysis", "Key Takeaways"). The content field is fully yours to structure — use markdown headings, prose, or any format that fits the context. Do not create text blocks titled "Overview" or "Introduction" — the notebook's title and description already cover that.
        - In markdown content, never insert a blank line after a heading. The notebook renders blank lines as visible gaps, so write "## Heading\nBody text" not "## Heading\n\nBody text".
        </writing_style>

        <rules>
        - Always call `get_table_schema` before using column names — do not guess.
        - Every statistic in commentary must come from a `run_query` result.
        - Prefer numeric columns for Y axis, categorical/date for X axis.
        - If no connection is selected, ask the user to pick one from the connection picker.
        - `run_query` results are returned to you only. Use `create_chart_block` and `create_text_block` to add content to the notebook.
        - Never create markdown tables inside `create_text_block`. Text blocks are for written commentary, analysis, and section headings only — not for displaying data. Use `create_chart_block` or `create_single_value_block` to present data visually.
        - If a query returns unexpected data (nulls, zeros, outliers, empty results), run a follow-up query to investigate before drawing conclusions. Surface anomalies in your commentary.
        - For comprehensive reports, cover: key breakdowns, trends over time, and notable outliers. The notebook title and description handle the overview — do not add a separate overview block. For narrow questions, just answer what was asked.
        </rules>
        """

        // Dynamic block: connections and notebook blocks — changes between rounds
        let connectionList: String
        if connections.isEmpty {
            connectionList = "No connections selected. Ask the user to select a connection using the picker below the chat input."
        } else {
            connectionList = connections.map { conn in
                "- \(conn.name) (keychainId: \(conn.keychainId), type: \(conn.databaseType.rawValue), database: \(conn.defaultDatabase ?? "default"))"
            }.joined(separator: "\n")
        }

        let blockInventory: String
        if blocks.isEmpty {
            blockInventory = "No blocks in this notebook yet."
        } else {
            blockInventory = blocks.map { block in
                let configSummary: String
                switch block.blockType {
                case .chart:
                    if let cfg = block.chartConfig() {
                        configSummary = "chart_type: \(cfg.chartType.rawValue), table: \(cfg.tableName), x: \(cfg.xAxisColumn ?? "none"), y: \(cfg.fields["yAxis"]?.joined(separator: ", ") ?? "none")"
                    } else {
                        configSummary = "unconfigured"
                    }
                case .singleValue:
                    if let cfg = block.singleValueConfig() {
                        configSummary = "column: \(cfg.column ?? "none"), aggregation: \(cfg.aggregation.rawValue), table: \(cfg.tableName)"
                    } else {
                        configSummary = "unconfigured"
                    }
                case .query:
                    if let cfg = block.queryBlockConfig() {
                        let queryPreview = cfg.queryText.prefix(60)
                        configSummary = "query: \(queryPreview)\(cfg.queryText.count > 60 ? "..." : "")"
                    } else {
                        configSummary = "unconfigured"
                    }
                case .text:
                    let preview = block.textContent.prefix(60)
                    configSummary = "content: \(preview)\(block.textContent.count > 60 ? "..." : "")"
                }
                return "  - id: \(block.id.uuidString) | type: \(block.blockType.rawValue) | title: \"\(block.title)\" | \(configSummary)"
            }.joined(separator: "\n")
        }

        let dynamicPrompt = """
        <available_connections>
        \(connectionList)
        </available_connections>

        <existing_notebook_blocks>
        \(blockInventory)
        </existing_notebook_blocks>
        """

        return [
            SystemContentBlock(text: staticPrompt, cacheControl: .ephemeralLong),
            SystemContentBlock(text: dynamicPrompt),
        ]
    }

    // MARK: - Tool Definitions

    func buildTools(connections: [Connection]) -> [AnthropicToolDefinition] {
        var tools: [AnthropicToolDefinition] = [
            listTablesTool,
            listDatabasesTool,
            getTableSchemaTool,
            runQueryTool,
            setNotebookInfoTool,
            listNotebookBlocksTool,
            arrangeDashboardTool,
        ]
        tools.append(contentsOf: NotebookBlockKind.allToolDefinitions)
        tools.append(contentsOf: NotebookBlockKind.allUpdateToolDefinitions)

        // Cache breakpoint on last tool — all tool definitions are static
        if !tools.isEmpty {
            tools[tools.count - 1].cacheControl = .ephemeralLong
        }

        return tools
    }

    // MARK: - API Round (Streaming)

    func performRound(
        messages: [AnthropicMessage],
        connections: [Connection],
        blocks: [NotebookBlock] = [],
        onToken: @MainActor @Sendable (String) -> Void = { _ in },
        onThinking: @MainActor @Sendable (String) -> Void = { _ in }
    ) async throws -> AgentRoundResult {
        let tools = buildTools(connections: connections)
        let systemBlocks = buildSystemBlocks(connections: connections, blocks: blocks)

        // Cache breakpoint on the last message (user tool results) to cache the conversation prefix.
        // Must target a user message — Bedrock ignores cache_control on assistant messages.
        var cachedMessages = messages
        if cachedMessages.count >= 3 {
            let targetIdx = cachedMessages.count - 1
            cachedMessages[targetIdx] = addCacheControl(to: cachedMessages[targetIdx])
        }

        let response = try await BedrockService.shared.messageRequestStream(
            messages: cachedMessages,
            system: systemBlocks,
            tools: tools,
            onTextDelta: onToken,
            onThinkingDelta: onThinking
        )

        let text = response.content.compactMap { content -> String? in
            guard case .text(let t) = content else { return nil }
            return t
        }.joined()

        let toolCalls: [(id: String, name: String, input: [String: Any])] = response.content.compactMap { content in
            guard case .toolUse(let id, let name, let input) = content else { return nil }
            return (id: id, name: name, input: sendableToAny(input))
        }

        return AgentRoundResult(
            text: text,
            toolCalls: toolCalls,
            responseContent: response.content
        )
    }

    // MARK: - Tool Execution

    func executeToolCall(
        _ toolCall: (id: String, name: String, input: [String: Any]),
        connections: [Connection],
        blocks: [NotebookBlock] = []
    ) async -> String {
        let json = toolCall.input

        let result: String
        switch toolCall.name {
        case "list_tables":
            result = await executeListTables(json: json, connections: connections)
        case "list_databases":
            result = await executeListDatabases(json: json, connections: connections)
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
        case "create_query_block":
            result = executeCreateQueryBlock(json: json)
        case "set_notebook_info":
            result = executeSetNotebookInfo(json: json)
        case "list_notebook_blocks":
            result = executeListNotebookBlocks(blocks: blocks)
        case "update_chart_block":
            result = executeUpdateChartBlock(json: json)
        case "update_single_value_block":
            result = executeUpdateSingleValueBlock(json: json)
        case "update_text_block":
            result = executeUpdateTextBlock(json: json)
        case "update_query_block":
            result = executeUpdateQueryBlock(json: json)
        case "arrange_dashboard":
            result = executeArrangeDashboard(json: json)
        default:
            result = "Unknown tool: \(toolCall.name)"
        }

        return result
    }

    // MARK: - List Tables

    private func executeListTables(json: [String: Any], connections: [Connection]) async -> String {
        let databaseName = json["database_name"] as? String
        guard let keychainId = json["connection_keychain_id"] as? String,
              let connection = connections.first(where: { $0.keychainId == keychainId }) else {
            if let conn = connections.first {
                return await fetchTables(connection: conn, schema: json["schema_name"] as? String, databaseName: databaseName)
            }
            return "Error: No connection available. Ask the user to select a connection."
        }
        return await fetchTables(connection: connection, schema: json["schema_name"] as? String, databaseName: databaseName)
    }

    private func fetchTables(connection: Connection, schema: String?, databaseName: String? = nil) async -> String {
        do {
            try await driverSession.connect(
                databaseType: connection.databaseType,
                uri: connection.connectionUri,
                keychainId: connection.keychainId,
                databaseName: databaseName ?? connection.defaultDatabase ?? ""
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

    // MARK: - List Databases

    private func executeListDatabases(json: [String: Any], connections: [Connection]) async -> String {
        guard let conn = resolveConnection(json: json, connections: connections) else {
            return "Error: No connection available. Ask the user to select a connection."
        }
        do {
            try await driverSession.connect(
                databaseType: conn.databaseType,
                uri: conn.connectionUri,
                keychainId: conn.keychainId,
                databaseName: conn.defaultDatabase ?? ""
            )
            let databases = try await driverSession.listDatabases()
            let list = databases.map { "- \($0.name)" }.joined(separator: "\n")
            return "Databases on \(conn.name):\n\(list)"
        } catch {
            return "Error listing databases: \(error.localizedDescription)"
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
            let databaseName = (json["database_name"] as? String) ?? conn.defaultDatabase ?? ""
            try await driverSession.connect(
                databaseType: conn.databaseType,
                uri: conn.connectionUri,
                keychainId: conn.keychainId,
                databaseName: databaseName
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
            let databaseName = (json["database_name"] as? String) ?? conn.defaultDatabase ?? ""
            try await driverSession.connect(
                databaseType: conn.databaseType,
                uri: conn.connectionUri,
                keychainId: conn.keychainId,
                databaseName: databaseName
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
        guard let title = json["title"] as? String,
              let chartTypeRaw = json["chart_type"] as? String,
              let xAxis = json["x_axis_column"] as? String else {
            return "Error: Missing required parameters for create_chart_block (title, chart_type, x_axis_column)"
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

        // Query source path — chart reads data from a query block's output
        if let sourceOutput = json["source_query_output"] as? String {
            var config = ChartBlockConfig(
                connectionKeychainId: "",
                connectionName: sourceOutput,
                databaseType: "",
                databaseName: "",
                tableName: sourceOutput,
                chartType: chartType
            )
            config.xAxisColumn = xAxis
            config.fields["yAxis"] = yAxisColumns

            if let aggs = json["aggregations"] as? [String: String] {
                for (column, aggRaw) in aggs {
                    if let agg = AggregationFunction(rawValue: aggRaw) {
                        config.setAggregation(agg, forField: "yAxis", column: column)
                    }
                }
            }

            pendingBlockCreations.append(BlockCreationRequest(
                kind: .chart,
                title: title,
                config: config,
                sourceQueryOutputName: sourceOutput
            ))

            return "Chart block '\(title)' created from query output '\(sourceOutput)': \(chartType.displayName) (x: \(xAxis), y: \(yAxisColumns.joined(separator: ", ")))"
        }

        // Direct connection path
        guard let keychainId = json["connection_keychain_id"] as? String,
              let connName = json["connection_name"] as? String,
              let dbType = json["database_type"] as? String,
              let dbName = json["database_name"] as? String,
              let tableName = json["table_name"] as? String else {
            return "Error: When not using source_query_output, connection_keychain_id, connection_name, database_type, database_name, and table_name are required"
        }

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

        let title = json["title"] as? String ?? ""

        pendingBlockCreations.append(BlockCreationRequest(
            kind: .text,
            title: title,
            textContent: content
        ))

        return "Text block '\(title)' created."
    }

    // MARK: - Create Query Block

    private func executeCreateQueryBlock(json: [String: Any]) -> String {
        guard let keychainId = json["connection_keychain_id"] as? String,
              let connName = json["connection_name"] as? String,
              let dbType = json["database_type"] as? String,
              let dbName = json["database_name"] as? String,
              let query = json["query"] as? String,
              let title = json["title"] as? String else {
            return "Error: Missing required parameters for create_query_block"
        }

        let schemaName = json["schema_name"] as? String
        let outputName = json["output_name"] as? String ?? ""

        let dialect: SQLDialect = switch dbType {
        case "postgres", "supabase", "convex": .postgresql
        case "mysql": .mysql
        default: .sqlite
        }
        let formattedQuery = SQLFormatter.format(query.trimmingCharacters(in: .whitespacesAndNewlines), dialect: dialect)

        let queryCfg = QueryBlockConfig(
            connectionKeychainId: keychainId,
            connectionName: connName,
            databaseType: dbType,
            databaseName: dbName,
            schemaName: schemaName,
            queryText: formattedQuery,
            outputName: outputName
        )

        pendingBlockCreations.append(BlockCreationRequest(
            kind: .query,
            title: title,
            queryBlockConfig: queryCfg
        ))

        let outputInfo = outputName.isEmpty ? "" : " (output_name: '\(outputName)' — use this as source_query_output in create_chart_block to chart this data)"
        return "Query block '\(title)' created with SQL query.\(outputInfo)"
    }

    // MARK: - List Notebook Blocks

    private func executeListNotebookBlocks(blocks: [NotebookBlock]) -> String {
        guard !blocks.isEmpty else { return "No blocks in this notebook yet." }
        let lines = blocks.enumerated().map { index, block in
            let configSummary: String
            switch block.blockType {
            case .chart:
                if let cfg = block.chartConfig() {
                    configSummary = "chart_type: \(cfg.chartType.rawValue), table: \(cfg.tableName), x: \(cfg.xAxisColumn ?? "none"), y: \(cfg.fields["yAxis"]?.joined(separator: ", ") ?? "none")"
                } else {
                    configSummary = "unconfigured"
                }
            case .singleValue:
                if let cfg = block.singleValueConfig() {
                    configSummary = "column: \(cfg.column ?? "none"), aggregation: \(cfg.aggregation.rawValue), table: \(cfg.tableName)"
                } else {
                    configSummary = "unconfigured"
                }
            case .query:
                if let cfg = block.queryBlockConfig() {
                    let queryPreview = cfg.queryText.prefix(80)
                    configSummary = "query: \(queryPreview)\(cfg.queryText.count > 80 ? "..." : "")"
                } else {
                    configSummary = "unconfigured"
                }
            case .text:
                let preview = block.textContent.prefix(80)
                configSummary = "content: \(preview)\(block.textContent.count > 80 ? "..." : "")"
            }
            return "  \(index + 1). id: \(block.id.uuidString) | type: \(block.blockType.rawValue) | title: \"\(block.title)\" | \(configSummary)"
        }
        return "Notebook blocks (\(blocks.count)):\n\(lines.joined(separator: "\n"))"
    }

    // MARK: - Update Chart Block

    private func executeUpdateChartBlock(json: [String: Any]) -> String {
        guard let blockIdStr = json["block_id"] as? String,
              let blockId = UUID(uuidString: blockIdStr) else {
            return "Error: block_id is required and must be a valid UUID"
        }

        var mutableJson = json
        mutableJson.removeValue(forKey: "block_id")

        guard let title = mutableJson["title"] as? String,
              let chartTypeRaw = mutableJson["chart_type"] as? String,
              let xAxis = mutableJson["x_axis_column"] as? String else {
            return "Error: Missing required parameters (title, chart_type, x_axis_column)"
        }

        let yAxisColumns: [String]
        if let arr = mutableJson["y_axis_columns"] as? [String] {
            yAxisColumns = arr
        } else if let arr = mutableJson["y_axis_columns"] as? [Any] {
            yAxisColumns = arr.compactMap { $0 as? String }
        } else {
            return "Error: y_axis_columns must be an array of strings"
        }

        let chartType = ChartBlockConfig.ChartType(rawValue: chartTypeRaw) ?? .groupedColumn

        if let sourceOutput = mutableJson["source_query_output"] as? String {
            var config = ChartBlockConfig(
                connectionKeychainId: "",
                connectionName: sourceOutput,
                databaseType: "",
                databaseName: "",
                tableName: sourceOutput,
                chartType: chartType
            )
            config.xAxisColumn = xAxis
            config.fields["yAxis"] = yAxisColumns

            if let aggs = mutableJson["aggregations"] as? [String: String] {
                for (column, aggRaw) in aggs {
                    if let agg = AggregationFunction(rawValue: aggRaw) {
                        config.setAggregation(agg, forField: "yAxis", column: column)
                    }
                }
            }

            pendingBlockCreations.append(BlockCreationRequest(
                kind: .chart, title: title, config: config,
                sourceQueryOutputName: sourceOutput, targetBlockId: blockId
            ))
            return "Chart block '\(title)' updated from query output '\(sourceOutput)'"
        }

        guard let keychainId = mutableJson["connection_keychain_id"] as? String,
              let connName = mutableJson["connection_name"] as? String,
              let dbType = mutableJson["database_type"] as? String,
              let dbName = mutableJson["database_name"] as? String,
              let tableName = mutableJson["table_name"] as? String else {
            return "Error: When not using source_query_output, connection details and table_name are required"
        }

        let rowLimit = min(mutableJson["row_limit"] as? Int ?? 500, 500)
        let schemaName = mutableJson["schema_name"] as? String

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

        if let aggs = mutableJson["aggregations"] as? [String: String] {
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

        if let filterArray = mutableJson["filters"] as? [[String: String]] {
            for filterDict in filterArray {
                guard let field = filterDict["field"],
                      let opRaw = filterDict["operator"],
                      let op = ChartFilterCondition.ChartFilterOperator(rawValue: opRaw) else { continue }
                let value = filterDict["value"] ?? ""
                config.filters.append(ChartFilterCondition(field: field, filterOperator: op, value: value))
            }
        }

        pendingBlockCreations.append(BlockCreationRequest(
            kind: .chart, title: title, config: config, targetBlockId: blockId
        ))
        return "Chart block '\(title)' updated: \(chartType.displayName) on \(tableName) (x: \(xAxis), y: \(yAxisColumns.joined(separator: ", ")))"
    }

    // MARK: - Update Single Value Block

    private func executeUpdateSingleValueBlock(json: [String: Any]) -> String {
        guard let blockIdStr = json["block_id"] as? String,
              let blockId = UUID(uuidString: blockIdStr) else {
            return "Error: block_id is required and must be a valid UUID"
        }

        guard let keychainId = json["connection_keychain_id"] as? String,
              let connName = json["connection_name"] as? String,
              let dbType = json["database_type"] as? String,
              let dbName = json["database_name"] as? String,
              let tableName = json["table_name"] as? String,
              let column = json["column"] as? String,
              let aggRaw = json["aggregation"] as? String,
              let title = json["title"] as? String else {
            return "Error: Missing required parameters for update_single_value_block"
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
            kind: .singleValue, title: title, singleValueConfig: singleValueCfg, targetBlockId: blockId
        ))
        return "Single value block '\(title)' updated: \(aggregation.displayName) of \(column) from \(tableName)"
    }

    // MARK: - Update Text Block

    private func executeUpdateTextBlock(json: [String: Any]) -> String {
        guard let blockIdStr = json["block_id"] as? String,
              let blockId = UUID(uuidString: blockIdStr) else {
            return "Error: block_id is required and must be a valid UUID"
        }

        guard let content = json["content"] as? String else {
            return "Error: content is required for update_text_block"
        }

        pendingBlockCreations.append(BlockCreationRequest(
            kind: .text, title: "", textContent: content, targetBlockId: blockId
        ))
        return "Text block updated."
    }

    // MARK: - Update Query Block

    private func executeUpdateQueryBlock(json: [String: Any]) -> String {
        guard let blockIdStr = json["block_id"] as? String,
              let blockId = UUID(uuidString: blockIdStr) else {
            return "Error: block_id is required and must be a valid UUID"
        }

        guard let keychainId = json["connection_keychain_id"] as? String,
              let connName = json["connection_name"] as? String,
              let dbType = json["database_type"] as? String,
              let dbName = json["database_name"] as? String,
              let query = json["query"] as? String,
              let title = json["title"] as? String else {
            return "Error: Missing required parameters for update_query_block"
        }

        let schemaName = json["schema_name"] as? String
        let outputName = json["output_name"] as? String ?? ""

        let dialect: SQLDialect = switch dbType {
        case "postgres", "supabase", "convex": .postgresql
        case "mysql": .mysql
        default: .sqlite
        }
        let formattedQuery = SQLFormatter.format(query.trimmingCharacters(in: .whitespacesAndNewlines), dialect: dialect)

        let queryCfg = QueryBlockConfig(
            connectionKeychainId: keychainId,
            connectionName: connName,
            databaseType: dbType,
            databaseName: dbName,
            schemaName: schemaName,
            queryText: formattedQuery,
            outputName: outputName
        )

        pendingBlockCreations.append(BlockCreationRequest(
            kind: .query, title: title, queryBlockConfig: queryCfg, targetBlockId: blockId
        ))

        let outputInfo = outputName.isEmpty ? "" : " (output_name: '\(outputName)')"
        return "Query block '\(title)' updated with new SQL query.\(outputInfo)"
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

    private func addCacheControl(to message: AnthropicMessage) -> AnthropicMessage {
        switch message.content {
        case .text(let text):
            return AnthropicMessage(
                role: message.role,
                content: .blocks([.text(text, cacheControl: .ephemeral)])
            )
        case .blocks(var blocks):
            guard let lastIdx = blocks.indices.last else { return message }
            switch blocks[lastIdx] {
            case .text(let t, _):
                blocks[lastIdx] = .text(t, cacheControl: .ephemeral)
            case .toolResult(let id, let content, _):
                blocks[lastIdx] = .toolResult(toolUseId: id, content: content, cacheControl: .ephemeral)
            default:
                break
            }
            return AnthropicMessage(role: message.role, content: .blocks(blocks))
        }
    }

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
                "database_name": .object([
                    "type": .string("string"),
                    "description": .string("Database name to connect to. If omitted, uses the connection's default database. Use list_databases to discover available databases."),
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
                "database_name": .object([
                    "type": .string("string"),
                    "description": .string("Database name to connect to. If omitted, uses the connection's default database. Use list_databases to discover available databases."),
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

    private let listNotebookBlocksTool = AnthropicToolDefinition(
        name: "list_notebook_blocks",
        description: "Returns all existing blocks in the notebook with their IDs, types, titles, and configuration summaries. Call this to get block_id values needed for update_* tools.",
        inputSchema: [
            "type": .string("object"),
            "properties": .object([:]),
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
                "database_name": .object([
                    "type": .string("string"),
                    "description": .string("Database name to connect to. If omitted, uses the connection's default database. Use list_databases to discover available databases."),
                ]),
            ]),
            "required": .array([.string("connection_keychain_id"), .string("table_name")]),
        ]
    )

    private let arrangeDashboardTool = AnthropicToolDefinition(
        name: "arrange_dashboard",
        description: """
        Arranges notebook blocks into a dashboard grid layout. Each block can be sized and positioned in rows. \
        Blocks with inline=true sit next to the previous block in the same row. \
        Blocks with inline=false start a new row. The order of the blocks array determines their dashboard sort order. \
        Call this after creating all blocks to produce a polished dashboard layout.
        """,
        inputSchema: [
            "type": .string("object"),
            "properties": .object([
                "blocks": .object([
                    "type": .string("array"),
                    "description": .string("Array of block layout configurations, in the order they should appear in the dashboard."),
                    "items": .object([
                        "type": .string("object"),
                        "properties": .object([
                            "block_id": .object([
                                "type": .string("string"),
                                "description": .string("The UUID of the block to position"),
                            ]),
                            "width_fraction": .object([
                                "type": .string("number"),
                                "description": .string("Width as a fraction of available space (0.0 to 1.0). E.g. 0.5 = half width, 0.25 = quarter width, 1.0 = full width"),
                            ]),
                            "height": .object([
                                "type": .string("number"),
                                "description": .string("Content height in points. Defaults: chart=280, query=380, single_value=120, text=140"),
                            ]),
                            "inline": .object([
                                "type": .string("boolean"),
                                "description": .string("If true, this block sits next to the previous block in the same row. If false, starts a new row. The first block should always be false."),
                            ]),
                            "hidden": .object([
                                "type": .string("boolean"),
                                "description": .string("If true, the block is hidden from the dashboard view"),
                            ]),
                        ]),
                        "required": .array([.string("block_id")]),
                    ]),
                ]),
                "switch_to_dashboard": .object([
                    "type": .string("boolean"),
                    "description": .string("If true, switches the notebook view to dashboard mode after arranging. Defaults to true."),
                ]),
            ]),
            "required": .array([.string("blocks")]),
        ]
    )

    private let listDatabasesTool = AnthropicToolDefinition(
        name: "list_databases",
        description: "Lists all databases available on a connection. Use this when the user references a table that may be in a different database.",
        inputSchema: [
            "type": .string("object"),
            "properties": .object([
                "connection_keychain_id": .object([
                    "type": .string("string"),
                    "description": .string("The keychainId of the connection to query"),
                ]),
            ]),
            "required": .array([.string("connection_keychain_id")]),
        ]
    )

    // MARK: - Arrange Dashboard

    private func executeArrangeDashboard(json: [String: Any]) -> String {
        guard let blocksArray = json["blocks"] as? [[String: Any]], !blocksArray.isEmpty else {
            return "Error: blocks array is required for arrange_dashboard"
        }

        var layouts: [DashboardBlockLayout] = []
        for blockJson in blocksArray {
            guard let blockId = blockJson["block_id"] as? String else { continue }
            var layout = DashboardBlockLayout(blockId: blockId)
            if let width = blockJson["width_fraction"] as? Double {
                layout.widthFraction = width
            }
            if let height = blockJson["height"] as? Double {
                layout.height = height
            }
            if let inline = blockJson["inline"] as? Bool {
                layout.inline = inline
            }
            if let hidden = blockJson["hidden"] as? Bool {
                layout.hidden = hidden
            }
            layouts.append(layout)
        }

        let switchToDashboard = json["switch_to_dashboard"] as? Bool ?? true

        pendingDashboardArrangement = DashboardArrangementRequest(
            layouts: layouts,
            switchToDashboard: switchToDashboard
        )

        return "Dashboard arranged with \(layouts.count) blocks.\(switchToDashboard ? " Switched to dashboard view." : "")"
    }
}
