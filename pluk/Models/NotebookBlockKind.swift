import Foundation
import AIProxy

enum NotebookBlockKind: String, Codable, CaseIterable {
    case chart
    case text

    var displayName: String {
        switch self {
        case .chart: "Chart"
        case .text: "Text"
        }
    }

    var icon: String {
        switch self {
        case .chart: "chart.bar"
        case .text: "doc.text"
        }
    }

    // MARK: - AI Tool Registration

    var isAICreatable: Bool {
        switch self {
        case .chart, .text: true
        }
    }

    var aiToolName: String? {
        guard isAICreatable else { return nil }
        return "create_\(rawValue)_block"
    }

    var openAITool: OpenAICreateResponseRequestBody.Tool? {
        guard isAICreatable else { return nil }
        switch self {
        case .chart: return Self.openAIChartTool
        case .text: return Self.openAITextTool
        }
    }

    static var allOpenAITools: [OpenAICreateResponseRequestBody.Tool] {
        allCases.compactMap(\.openAITool)
    }

    static func kindForToolName(_ name: String) -> NotebookBlockKind? {
        allCases.first { $0.aiToolName == name }
    }

    // MARK: - OpenAI Tool Definitions

    private static let openAIChartTool: OpenAICreateResponseRequestBody.Tool = .function(
        OpenAICreateResponseRequestBody.FunctionTool(
            name: "create_chart_block",
            parameters: [
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
                        "enum": .array(ChartBlockConfig.ChartType.allCases.map { AIProxyJSONValue.string($0.rawValue) }),
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
                                    "enum": .array(ChartFilterCondition.ChartFilterOperator.allCases.map { AIProxyJSONValue.string($0.rawValue) }),
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
            ],
            strict: false,
            description: """
            Creates a chart visualization block in the notebook. \
            Requires knowing the connection, table, and which columns to use for axes. \
            Always call get_table_schema first to understand available columns before creating a chart.
            """
        )
    )

    private static let openAITextTool: OpenAICreateResponseRequestBody.Tool = .function(
        OpenAICreateResponseRequestBody.FunctionTool(
            name: "create_text_block",
            parameters: [
                "type": .string("object"),
                "properties": .object([
                    "content": .object([
                        "type": .string("string"),
                        "description": .string("Markdown content for the text block"),
                    ]),
                ]),
                "required": .array([.string("content")]),
            ],
            strict: false,
            description: "Creates a markdown text block in the notebook for titles, explanations, analysis commentary, or section headers."
        )
    )
}

typealias NotebookBlockType = NotebookBlockKind
