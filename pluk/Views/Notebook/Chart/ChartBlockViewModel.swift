import SwiftUI

struct ChartDataPoint: Identifiable {
    let id = UUID()
    let x: String
    let y: Double
}

@Observable
@MainActor
final class ChartBlockViewModel {
    let block: NotebookBlock
    private weak var dataController: NotebookDataController?
    let session = ChartDriverSession()

    var config: ChartBlockConfig?

    // Table picker state
    var isShowingTablePicker = false
    var availableCollections: [any CollectionWrapper] = []
    var availableSchemas: [InformationSchema] = []
    var selectedPickerSchema: String?
    var previewResult: QueryResult?
    var isLoadingPreview = false

    var schemaResult: DatabaseSchemaResult?

    // Chart state
    var chartData: [ChartDataPoint] = []
    var isLoadingChart = false
    var chartError: String?

    // Connection state
    var isConnecting = false
    var connectionError: String?

    init(block: NotebookBlock, dataController: NotebookDataController) {
        self.block = block
        self.dataController = dataController
        self.config = block.chartConfig()

        if let cfg = config, !cfg.tableName.isEmpty {
            Task {
                await reconnectAndLoad(cfg)
            }
        }
    }

    // MARK: - Connection

    private func resolveConnectionUri(_ cfg: ChartBlockConfig) -> String? {
        dataController?.connections.first(where: { $0.keychainId == cfg.connectionKeychainId })?.connectionUri
    }

    private func reconnectAndLoad(_ cfg: ChartBlockConfig) async {
        guard let dbType = DatabaseType(rawValue: cfg.databaseType),
              let uri = resolveConnectionUri(cfg) else { return }
        do {
            try await session.connect(databaseType: dbType, uri: uri)
            if !cfg.databaseName.isEmpty {
                try await session.switchDatabase(to: cfg.databaseName)
            }

            try await loadSchemasAndCollections(databaseType: dbType, preferredSchema: cfg.schemaName)

            schemaResult = try await session.getSchema(tableName: cfg.tableName, schema: cfg.schemaName)
            if cfg.xAxisColumn != nil && cfg.yAxisColumn != nil {
                await fetchChartData()
            }
        } catch {
            chartError = error.localizedDescription
        }
    }

    func connectToSource(_ connection: Connection) async {
        isConnecting = true
        connectionError = nil
        defer { isConnecting = false }

        let uri = connection.connectionUri
        guard let dbType = DatabaseType(rawValue: connection.databaseType.rawValue) else {
            connectionError = "Unsupported database type"
            return
        }

        let draft = ChartBlockConfig(
            connectionKeychainId: connection.keychainId,
            connectionName: connection.name,
            databaseType: connection.databaseType.rawValue,
            databaseName: connection.defaultDatabase ?? "",
            tableName: ""
        )

        do {
            try await session.connect(databaseType: dbType, uri: uri)
            if let defaultDb = connection.defaultDatabase, !defaultDb.isEmpty {
                try? await session.switchDatabase(to: defaultDb)
            }

            try await loadSchemasAndCollections(databaseType: dbType, preferredSchema: nil)

            config = draft

            if let firstTable = availableCollections.first {
                confirmTableSelection(tableName: firstTable.name)
            }
        } catch {
            connectionError = error.localizedDescription
        }
    }

    private func loadSchemasAndCollections(databaseType: DatabaseType, preferredSchema: String?) async throws {
        if databaseType != .mongodb {
            let schemas = try await session.getInformationSchema()
            availableSchemas = schemas
            let schema = preferredSchema ?? schemas.first(where: { $0.name == "public" })?.name ?? schemas.first?.name
            selectedPickerSchema = schema
            availableCollections = try await session.listCollections(schema: schema)
        } else {
            availableCollections = try await session.listCollections(schema: nil)
        }
    }

    func loadCollections(schema: String?) async {
        selectedPickerSchema = schema
        schemaResult = nil
        chartData = []
        chartError = nil
        if var cfg = config {
            cfg.tableName = ""
            cfg.schemaName = schema
            cfg.xAxisColumn = nil
            cfg.yAxisColumn = nil
            config = cfg
            persistConfig()
        }
        do {
            availableCollections = try await session.listCollections(schema: schema)
        } catch {
            connectionError = error.localizedDescription
        }
    }

    func loadPreview(tableName: String) async {
        isLoadingPreview = true
        defer { isLoadingPreview = false }
        do {
            previewResult = try await session.fetchTableData(
                tableName: tableName,
                schema: selectedPickerSchema,
                limit: 50
            )
        } catch {
            connectionError = error.localizedDescription
        }
    }

    func confirmTableSelection(tableName: String) {
        guard var cfg = config else { return }
        cfg.tableName = tableName
        cfg.schemaName = selectedPickerSchema
        cfg.xAxisColumn = nil
        cfg.yAxisColumn = nil
        config = cfg
        schemaResult = nil
        chartData = []
        chartError = nil
        isShowingTablePicker = false
        previewResult = nil
        persistConfig()
        Task { await loadSchemaForConfig() }
    }

    // MARK: - Schema

    private func loadSchemaForConfig() async {
        guard let cfg = config, !cfg.tableName.isEmpty else { return }
        do {
            schemaResult = try await session.getSchema(tableName: cfg.tableName, schema: cfg.schemaName)
        } catch {
            chartError = error.localizedDescription
        }
    }

    // MARK: - Column classification

    var measureColumns: [DatabaseSchemaInfo] {
        schemaResult?.columns.filter { isNumericType($0.dataType) } ?? []
    }

    var dimensionColumns: [DatabaseSchemaInfo] {
        schemaResult?.columns.filter { !isNumericType($0.dataType) } ?? []
    }

    func isNumericColumn(_ col: DatabaseSchemaInfo) -> Bool {
        isNumericType(col.dataType)
    }

    var validColumnNames: Set<String> {
        Set(schemaResult?.columns.map(\.columnName) ?? [])
    }

    func isFilterFieldValid(_ filter: ChartFilterCondition) -> Bool {
        validColumnNames.contains(filter.field)
    }

    // MARK: - Axis Config

    func setXAxis(_ column: String) {
        config?.xAxisColumn = column
        persistConfig()
        triggerFetchIfReady()
    }

    func setYAxis(_ column: String) {
        config?.yAxisColumn = column
        persistConfig()
        triggerFetchIfReady()
    }

    private func triggerFetchIfReady() {
        guard config?.xAxisColumn != nil, config?.yAxisColumn != nil else { return }
        Task { await fetchChartData() }
    }

    // MARK: - Filters

    func addFilter(_ filter: ChartFilterCondition) {
        config?.filters.append(filter)
        persistConfig()
        triggerFetchIfReady()
    }

    func updateFilter(_ filter: ChartFilterCondition) {
        guard let index = config?.filters.firstIndex(where: { $0.id == filter.id }) else { return }
        config?.filters[index] = filter
        persistConfig()
        triggerFetchIfReady()
    }

    func removeFilter(id: UUID) {
        config?.filters.removeAll { $0.id == id }
        persistConfig()
        triggerFetchIfReady()
    }

    func removeAllFilters() {
        config?.filters.removeAll()
        persistConfig()
        triggerFetchIfReady()
    }

    // MARK: - Data Fetching

    func fetchChartData() async {
        guard let cfg = config,
              let xCol = cfg.xAxisColumn,
              let yCol = cfg.yAxisColumn else {
            chartError = ChartBlockError.noAxesConfigured.localizedDescription
            return
        }
        isLoadingChart = true
        chartError = nil
        defer { isLoadingChart = false }
        do {
            let effectiveLimit = min(cfg.rowLimit, 200)
            let result = try await session.fetchTableData(
                tableName: cfg.tableName,
                schema: cfg.schemaName,
                limit: effectiveLimit,
                filters: cfg.filters.filter { isFilterFieldValid($0) }
            )
            let points: [ChartDataPoint] = result.rows.compactMap { (row: [String: QueryRowInfo]) -> ChartDataPoint? in
                guard let xInfo = row[xCol],
                      let yInfo = row[yCol],
                      let xRaw = xInfo.value,
                      let yRaw = yInfo.value,
                      let yNum = toDouble(yRaw) else { return nil }
                return ChartDataPoint(x: String(describing: xRaw), y: yNum)
            }
            chartData = reduceChartData(points, maxPoints: 160)
        } catch {
            chartError = error.localizedDescription
        }
    }

    // MARK: - Persistence

    private func persistConfig() {
        guard let cfg = config else { return }
        block.saveChartConfig(cfg)
        dataController?.updateBlock(block)
    }

    // MARK: - Cleanup

    func cleanup() async {
        await session.disconnect()
    }

    // MARK: - Helpers

    private func isNumericType(_ type: String) -> Bool {
        let lower = type.lowercased()
        return lower.contains("int") || lower.contains("float") ||
               lower.contains("double") || lower.contains("decimal") ||
               lower.contains("numeric") || lower.contains("real") ||
               lower.contains("number") || lower.contains("serial") ||
               lower.contains("money")
    }

    private func toDouble(_ value: Any) -> Double? {
        switch value {
        case let d as Double: return d
        case let i as Int: return Double(i)
        case let i as Int64: return Double(i)
        case let i as Int32: return Double(i)
        case let f as Float: return Double(f)
        case let s as String: return Double(s)
        case let d as Decimal: return NSDecimalNumber(decimal: d).doubleValue
        default: return nil
        }
    }

    private func reduceChartData(_ points: [ChartDataPoint], maxPoints: Int) -> [ChartDataPoint] {
        guard points.count > maxPoints, maxPoints > 1 else { return points }

        var orderedKeys: [String] = []
        var sumsByKey: [String: Double] = [:]

        for point in points {
            if sumsByKey[point.x] == nil {
                orderedKeys.append(point.x)
            }
            sumsByKey[point.x, default: 0] += point.y
        }

        if orderedKeys.count <= maxPoints {
            return orderedKeys.compactMap { key in
                guard let total = sumsByKey[key] else { return nil }
                return ChartDataPoint(x: key, y: total)
            }
        }

        return downsample(points: points, maxPoints: maxPoints)
    }

    private func downsample(points: [ChartDataPoint], maxPoints: Int) -> [ChartDataPoint] {
        guard points.count > maxPoints, maxPoints > 1 else { return points }
        let step = Double(points.count - 1) / Double(maxPoints - 1)
        var reduced: [ChartDataPoint] = []
        reduced.reserveCapacity(maxPoints)

        for i in 0..<maxPoints {
            let rawIndex = Int(Double(i) * step)
            let index = min(max(rawIndex, 0), points.count - 1)
            reduced.append(points[index])
        }

        return reduced
    }
}
