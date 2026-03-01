import Foundation

enum NotebookBlockKind: String, Codable, CaseIterable {
    case chart
    case text
    case singleValue = "metric"

    var displayName: String {
        switch self {
        case .chart: "Chart"
        case .text: "Text"
        case .singleValue: "Single Value"
        }
    }

    var icon: String {
        switch self {
        case .chart: "chart.bar"
        case .text: "doc.text"
        case .singleValue: "numbers.rectangle"
        }
    }

    // MARK: - AI Tool Registration

    var isAICreatable: Bool {
        switch self {
        case .chart, .text, .singleValue: true
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
        }
    }

    static var allToolDefinitions: [AnthropicToolDefinition] {
        allCases.compactMap(\.toolDefinition)
    }

    static func kindForToolName(_ name: String) -> NotebookBlockKind? {
        allCases.first { $0.aiToolName == name }
    }

    // MARK: - Tool Definitions

    private static let chartToolDefinition = AnthropicToolDefinition(
        name: "create_chart_block",
        description: """
        Creates a chart visualization block in the notebook. \
        Requires knowing the connection, table, and which columns to use for axes. \
        Always call get_table_schema first to understand available columns before creating a chart.
        """,
        inputSchema: [
            "type": .string("object"),
            "properties": .object([
                "title": .object([
                    "type": .string("string"),
                    "description": .string("A short descriptive title for the chart block"),
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
                    "description": .string("The database name"),
                ]),
                "schema_name": .object([
                    "type": .string("string"),
                    "description": .string("Schema name (e.g. 'public' for PostgreSQL). Omit for MySQL/SQLite/MongoDB."),
                ]),
                "table_name": .object([
                    "type": .string("string"),
                    "description": .string("The table or collection to query"),
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
                .string("title"), .string("connection_keychain_id"), .string("connection_name"),
                .string("database_type"), .string("database_name"),
                .string("table_name"), .string("chart_type"),
                .string("x_axis_column"), .string("y_axis_columns"),
            ]),
        ]
    )

    private static let textToolDefinition = AnthropicToolDefinition(
        name: "create_text_block",
        description: "Creates a markdown text block in the notebook for titles, explanations, analysis commentary, or section headers.",
        inputSchema: [
            "type": .string("object"),
            "properties": .object([
                "content": .object([
                    "type": .string("string"),
                    "description": .string("Markdown content for the text block"),
                ]),
            ]),
            "required": .array([.string("content")]),
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
                    "description": .string("The database name"),
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
}

typealias NotebookBlockType = NotebookBlockKind
