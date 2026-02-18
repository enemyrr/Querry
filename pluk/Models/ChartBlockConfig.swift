import Foundation

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
