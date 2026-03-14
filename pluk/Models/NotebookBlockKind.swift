import Foundation

enum NotebookBlockKind: String, Codable, CaseIterable {
    case chart
    case text
    case singleValue = "metric"
    case query

    var displayName: String {
        switch self {
        case .chart: "Chart"
        case .text: "Text"
        case .singleValue: "Single Value"
        case .query: "Query"
        }
    }

    var icon: String {
        switch self {
        case .chart: "chart.bar"
        case .text: "doc.text"
        case .singleValue: "numbers.rectangle"
        case .query: "terminal"
        }
    }

    // MARK: - AI Tool Registration

    var isAICreatable: Bool {
        switch self {
        case .chart, .text, .singleValue, .query: true
        }
    }

    var aiToolName: String? {
        guard isAICreatable else { return nil }
        switch self {
        case .singleValue: return "create_single_value_block"
        default: return "create_\(rawValue)_block"
        }
    }

    var toolDefinition: AnthropicToolDefinition? {
        guard isAICreatable else { return nil }
        switch self {
        case .chart: return Self.chartToolDefinition
        case .text: return Self.textToolDefinition
        case .singleValue: return Self.singleValueToolDefinition
        case .query: return Self.queryToolDefinition
        }
    }

    static var allToolDefinitions: [AnthropicToolDefinition] {
        allCases.compactMap(\.toolDefinition)
    }

    var updateToolDefinition: AnthropicToolDefinition? {
        guard isAICreatable else { return nil }
        switch self {
        case .chart: return Self.updateChartToolDefinition
        case .text: return Self.updateTextToolDefinition
        case .singleValue: return Self.updateSingleValueToolDefinition
        case .query: return Self.updateQueryToolDefinition
        }
    }

    static var allUpdateToolDefinitions: [AnthropicToolDefinition] {
        allCases.compactMap(\.updateToolDefinition)
    }

    static func kindForToolName(_ name: String) -> NotebookBlockKind? {
        allCases.first { $0.aiToolName == name }
    }

    // MARK: - Tool Definitions

    private static let chartToolDefinition = AnthropicToolDefinition(
        name: "create_chart_block",
        description: """
        Creates a chart visualization block in the notebook. \
        Two modes: (1) Direct connection — provide connection details and table_name to query the database directly. \
        (2) Query source — provide source_query_output with the output_name of a previously created query block to chart its results. \
        When using source_query_output, omit connection_keychain_id, connection_name, database_type, database_name, and table_name. \
        Always call get_table_schema first to understand available columns before creating a chart.
        """,
        inputSchema: [
            "type": .string("object"),
            "properties": .object([
                "title": .object([
                    "type": .string("string"),
                    "description": .string("A short descriptive title for the chart block"),
                ]),
                "source_query_output": .object([
                    "type": .string("string"),
                    "description": .string("The output_name of a previously created query block to use as the chart's data source. When provided, omit connection and table fields."),
                ]),
                "connection_keychain_id": .object([
                    "type": .string("string"),
                    "description": .string("The keychainId of the connection to use (omit when using source_query_output)"),
                ]),
                "connection_name": .object([
                    "type": .string("string"),
                    "description": .string("Human-readable connection name for display (omit when using source_query_output)"),
                ]),
                "database_type": .object([
                    "type": .string("string"),
                    "description": .string("Database type raw value: postgres, mysql, sqlite, MongoDB, supabase, convex (omit when using source_query_output)"),
                ]),
                "database_name": .object([
                    "type": .string("string"),
                    "description": .string("The database name (omit when using source_query_output). Use the database_name value from <available_connections>."),
                ]),
                "schema_name": .object([
                    "type": .string("string"),
                    "description": .string("Schema name (e.g. 'public' for PostgreSQL). Omit for MySQL/SQLite/MongoDB."),
                ]),
                "table_name": .object([
                    "type": .string("string"),
                    "description": .string("The table or collection to query (omit when using source_query_output)"),
                ]),
                "chart_type": .object([
                    "type": .string("string"),
                    "enum": .array(ChartBlockConfig.ChartType.allCases.map { JSONValue.string($0.rawValue) }),
                    "description": .string("The chart visualization type"),
                ]),
                "x_axis_column": .object([
                    "type": .string("string"),
                    "description": .string("Column name for the X axis (categories, labels, or dates)"),
                ]),
                "y_axis_columns": .object([
                    "type": .string("array"),
                    "items": .object(["type": .string("string")]),
                    "description": .string("Column names for the Y axis (numeric values/measures)"),
                ]),
                "aggregations": .object([
                    "type": .string("object"),
                    "description": .string("Optional aggregation per Y axis column. Keys are column names, values are: sum, average, count, countDistinct, min, max, none"),
                ]),
                "filters": .object([
                    "type": .string("array"),
                    "items": .object([
                        "type": .string("object"),
                        "properties": .object([
                            "field": .object(["type": .string("string")]),
                            "operator": .object([
                                "type": .string("string"),
                                "enum": .array(ChartFilterCondition.ChartFilterOperator.allCases.map { JSONValue.string($0.rawValue) }),
                            ]),
                            "value": .object(["type": .string("string")]),
                        ]),
                    ]),
                    "description": .string("Optional filters to apply to the chart data"),
                ]),
                "row_limit": .object([
                    "type": .string("integer"),
                    "description": .string("Maximum rows to fetch (default 500, max 500)"),
                ]),
            ]),
            "required": .array([
                .string("title"), .string("chart_type"),
                .string("x_axis_column"), .string("y_axis_columns"),
            ]),
        ]
    )

    private static let textToolDefinition = AnthropicToolDefinition(
        name: "create_text_block",
        description: "Creates a markdown text block in the notebook for written analysis, commentary, or section headers. Content must be prose only — NEVER include markdown tables (| col | col |). Use create_chart_block or create_single_value_block to present data.",
        inputSchema: [
            "type": .string("object"),
            "properties": .object([
                "title": .object([
                    "type": .string("string"),
                    "description": .string("A short descriptive title for the text block (e.g. 'Revenue Analysis', 'Dataset Overview')"),
                ]),
                "content": .object([
                    "type": .string("string"),
                    "description": .string("Markdown prose content (headings, paragraphs, bold/italic). Must NOT contain markdown tables — use charts or single value blocks for data."),
                ]),
            ]),
            "required": .array([.string("title"), .string("content")]),
        ]
    )

    private static let singleValueToolDefinition = AnthropicToolDefinition(
        name: "create_single_value_block",
        description: """
        Creates a single value block showing a single aggregated number (e.g. total count, sum, average). \
        Use for KPI displays like total orders, average revenue, user count, etc. \
        Always call get_table_schema first to understand available columns.
        """,
        inputSchema: [
            "type": .string("object"),
            "properties": .object([
                "title": .object([
                    "type": .string("string"),
                    "description": .string("A short title for the single value block (e.g. 'Total Orders')"),
                ]),
                "connection_keychain_id": .object([
                    "type": .string("string"),
                    "description": .string("The keychainId of the connection to use"),
                ]),
                "connection_name": .object([
                    "type": .string("string"),
                    "description": .string("Human-readable connection name for display"),
                ]),
                "database_type": .object([
                    "type": .string("string"),
                    "description": .string("Database type raw value: postgres, mysql, sqlite, MongoDB, supabase, convex"),
                ]),
                "database_name": .object([
                    "type": .string("string"),
                    "description": .string("The database name. Use the database_name value from <available_connections>."),
                ]),
                "schema_name": .object([
                    "type": .string("string"),
                    "description": .string("Schema name (e.g. 'public' for PostgreSQL). Omit for MySQL/SQLite/MongoDB."),
                ]),
                "table_name": .object([
                    "type": .string("string"),
                    "description": .string("The table or collection to aggregate"),
                ]),
                "column": .object([
                    "type": .string("string"),
                    "description": .string("The column to aggregate. Use '*' for COUNT(*)."),
                ]),
                "aggregation": .object([
                    "type": .string("string"),
                    "enum": .array(AggregationFunction.allCases.map { JSONValue.string($0.rawValue) }),
                    "description": .string("Aggregation function: sum, average, count, countDistinct, min, max, none"),
                ]),
                "label": .object([
                    "type": .string("string"),
                    "description": .string("Short subtitle label displayed below the number (1-3 words, e.g. 'Total Orders', 'Avg Revenue', 'Active Users'). Keep it concise — this is a KPI label, not a sentence."),
                ]),
                "filters": .object([
                    "type": .string("array"),
                    "items": .object([
                        "type": .string("object"),
                        "properties": .object([
                            "field": .object(["type": .string("string")]),
                            "operator": .object([
                                "type": .string("string"),
                                "enum": .array(ChartFilterCondition.ChartFilterOperator.allCases.map { JSONValue.string($0.rawValue) }),
                            ]),
                            "value": .object(["type": .string("string")]),
                        ]),
                    ]),
                    "description": .string("Optional filters to apply before aggregation"),
                ]),
            ]),
            "required": .array([
                .string("title"), .string("connection_keychain_id"), .string("connection_name"),
                .string("database_type"), .string("database_name"),
                .string("table_name"), .string("column"), .string("aggregation"),
            ]),
        ]
    )

    private static let queryToolDefinition = AnthropicToolDefinition(
        name: "create_query_block",
        description: """
        Creates a SQL query block in the notebook that displays results as an inline table. \
        Use this when you want SQL results visible in the notebook for the user to see. \
        Unlike `run_query` (which returns results only to you), this adds a persistent query cell \
        that the user can re-run and whose output can feed into chart or single value blocks.
        """,
        inputSchema: [
            "type": .string("object"),
            "properties": .object([
                "title": .object([
                    "type": .string("string"),
                    "description": .string("A short descriptive title for the query block"),
                ]),
                "connection_keychain_id": .object([
                    "type": .string("string"),
                    "description": .string("The keychainId of the connection to use"),
                ]),
                "connection_name": .object([
                    "type": .string("string"),
                    "description": .string("Human-readable connection name for display"),
                ]),
                "database_type": .object([
                    "type": .string("string"),
                    "description": .string("Database type raw value: postgres, mysql, sqlite, MongoDB, supabase, convex"),
                ]),
                "database_name": .object([
                    "type": .string("string"),
                    "description": .string("The database name. Use the database_name value from <available_connections>."),
                ]),
                "schema_name": .object([
                    "type": .string("string"),
                    "description": .string("Schema name (e.g. 'public' for PostgreSQL). Omit for MySQL/SQLite/MongoDB."),
                ]),
                "query": .object([
                    "type": .string("string"),
                    "description": .string("The SQL query to execute and display results for"),
                ]),
                "output_name": .object([
                    "type": .string("string"),
                    "description": .string("A short identifier for this query's output (e.g. 'revenue_data', 'order_status'). Other blocks can reference this output as a data source."),
                ]),
            ]),
            "required": .array([
                .string("title"), .string("connection_keychain_id"), .string("connection_name"),
                .string("database_type"), .string("database_name"), .string("query"),
            ]),
        ]
    )

    // MARK: - Update Tool Definitions

    private static func addBlockIdToSchema(_ base: AnthropicToolDefinition, name: String, description: String) -> AnthropicToolDefinition {
        let blockIdProp: [String: JSONValue] = [
            "type": .string("string"),
            "description": .string("The UUID of the existing block to modify. Get this from list_notebook_blocks or <existing_notebook_blocks>."),
        ]

        var props: [String: JSONValue] = [:]
        if case .object(let p) = base.inputSchema["properties"] {
            props = p
        }
        props["block_id"] = .object(blockIdProp)

        var required: [JSONValue] = []
        if case .array(let r) = base.inputSchema["required"] {
            required = r
        }
        required.insert(.string("block_id"), at: 0)

        return AnthropicToolDefinition(
            name: name,
            description: description,
            inputSchema: [
                "type": .string("object"),
                "properties": .object(props),
                "required": .array(required),
            ]
        )
    }

    private static let updateChartToolDefinition = addBlockIdToSchema(
        chartToolDefinition,
        name: "update_chart_block",
        description: """
        Modifies an existing chart block. Provide the block_id from list_notebook_blocks plus the complete new chart configuration. \
        The entire config is replaced — provide all fields, not just the ones you want to change. \
        Always call get_table_schema first to understand available columns before updating a chart.
        """
    )

    private static let updateSingleValueToolDefinition = addBlockIdToSchema(
        singleValueToolDefinition,
        name: "update_single_value_block",
        description: """
        Modifies an existing single value block. Provide the block_id plus the complete new configuration. \
        The entire config is replaced.
        """
    )

    private static let updateTextToolDefinition = addBlockIdToSchema(
        textToolDefinition,
        name: "update_text_block",
        description: "Replaces the content of an existing text block. Provide the block_id plus the new markdown content."
    )

    private static let updateQueryToolDefinition = addBlockIdToSchema(
        queryToolDefinition,
        name: "update_query_block",
        description: """
        Modifies an existing query block's SQL, connection, or output name. Provide the block_id plus the complete new configuration. \
        The entire config is replaced.
        """
    )
}

typealias NotebookBlockType = NotebookBlockKind
