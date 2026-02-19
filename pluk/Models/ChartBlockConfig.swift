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
    var chartType: ChartType = .bar
    var rowLimit: Int = 500
    var filters: [ChartFilterCondition] = []

    enum ChartType: String, Codable {
        case bar
    }
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
