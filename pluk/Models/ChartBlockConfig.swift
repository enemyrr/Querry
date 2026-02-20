import Foundation

struct ChartFilterCondition: Codable, Equatable, Identifiable {
    var id: UUID = UUID()
    var field: String
    var filterOperator: ChartFilterOperator
    var value: String

    enum ChartFilterOperator: String, Codable, CaseIterable {
        case equals = "equals"
        case notEquals = "not equals"
        case greaterThan = "greater than"
        case greaterThanOrEquals = "greater or equals"
        case lessThan = "less than"
        case lessThanOrEquals = "less than or equals"
        case like = "like"
        case isNull = "is null"
        case isNotNull = "is not null"

        var displayName: String {
            switch self {
            case .equals: "Is equal to"
            case .notEquals: "Is not equal to"
            case .greaterThan: "Greater than"
            case .greaterThanOrEquals: "Greater or equal to"
            case .lessThan: "Less than"
            case .lessThanOrEquals: "Less than or equal to"
            case .like: "Contains"
            case .isNull: "Is empty"
            case .isNotNull: "Is not empty"
            }
        }

        var needsValue: Bool {
            switch self {
            case .isNull, .isNotNull: false
            default: true
            }
        }

        var sqlOperator: String {
            switch self {
            case .equals: "="
            case .notEquals: "!="
            case .greaterThan: ">"
            case .greaterThanOrEquals: ">="
            case .lessThan: "<"
            case .lessThanOrEquals: "<="
            case .like: "ILIKE"
            case .isNull: "IS NULL"
            case .isNotNull: "IS NOT NULL"
            }
        }
    }

    var sqlFragment: String {
        let escapedField = "\"\(field)\""
        if !filterOperator.needsValue {
            return "\(escapedField) \(filterOperator.sqlOperator)"
        }
        switch filterOperator {
        case .like:
            let escaped = value.replacing("'", with: "''")
            return "\(escapedField) ILIKE '%\(escaped)%'"
        default:
            let escaped = value.replacing("'", with: "''")
            return "\(escapedField) \(filterOperator.sqlOperator) '\(escaped)'"
        }
    }

    var displaySummary: String {
        if !filterOperator.needsValue {
            return "\(field) \(filterOperator.displayName)"
        }
        return "\(field) \(filterOperator.displayName) \(value)"
    }
}

struct ChartBlockConfig: Codable {
    var connectionKeychainId: String
    var connectionName: String
    var databaseType: String
    var databaseName: String
    var schemaName: String?
    var tableName: String
    var xAxisColumn: String?
    var yAxisColumn: String?
    var chartType: ChartType = .groupedColumn
    var rowLimit: Int = 500
    var filters: [ChartFilterCondition] = []

    enum ChartType: String, Codable, CaseIterable {
        // Column (vertical)
        case groupedColumn = "bar"
        case stackedColumn
        case hundredPercentStackedColumn

        // Bar (horizontal)
        case groupedBar
        case stackedBar
        case hundredPercentStackedBar

        // Line & Area
        case line
        case stackedArea = "area"
        case hundredPercentStackedArea

        // Other
        case histogram
        case scatter
        case pie

        // Table
        case pivotTable

        var displayName: String {
            switch self {
            case .groupedColumn: "Grouped column"
            case .stackedColumn: "Stacked column"
            case .hundredPercentStackedColumn: "100% Stacked column"
            case .groupedBar: "Grouped bar"
            case .stackedBar: "Stacked bar"
            case .hundredPercentStackedBar: "100% Stacked bar"
            case .line: "Line"
            case .stackedArea: "Stacked area"
            case .hundredPercentStackedArea: "100% Stacked area"
            case .histogram: "Histogram"
            case .scatter: "Scatter"
            case .pie: "Pie"
            case .pivotTable: "Pivot table"
            }
        }
    }

    struct ChartTypeGroup {
        let title: String
        let types: [ChartType]
    }

    static let chartTypeGroups: [ChartTypeGroup] = [
        ChartTypeGroup(title: "COLUMN", types: [.groupedColumn, .stackedColumn, .hundredPercentStackedColumn]),
        ChartTypeGroup(title: "BAR", types: [.groupedBar, .stackedBar, .hundredPercentStackedBar]),
        ChartTypeGroup(title: "LINE & AREA", types: [.line, .stackedArea, .hundredPercentStackedArea]),
        ChartTypeGroup(title: "OTHER", types: [.histogram, .scatter, .pie]),
        ChartTypeGroup(title: "TABLE", types: [.pivotTable]),
    ]
}

extension NotebookBlock {
    func chartConfig() -> ChartBlockConfig? {
        guard blockType == .chart, !configJSON.isEmpty,
              let data = configJSON.data(using: .utf8) else { return nil }
        return try? Foundation.JSONDecoder().decode(ChartBlockConfig.self, from: data)
    }

    func saveChartConfig(_ config: ChartBlockConfig) {
        guard let data = try? JSONEncoder().encode(config),
              let json = String(data: data, encoding: .utf8) else { return }
        configJSON = json
        updatedAt = Date()
    }
}
