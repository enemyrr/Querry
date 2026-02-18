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

            if dbType != .mongodb {
                let schemas = try await session.getInformationSchema()
                availableSchemas = schemas
                let defaultSchema = schemas.first(where: { $0.name == "public" })?.name ?? schemas.first?.name
                selectedPickerSchema = defaultSchema
                availableCollections = try await session.listCollections(schema: defaultSchema)
            } else {
                availableCollections = try await session.listCollections(schema: nil)
            }

            config = draft

            if let firstTable = availableCollections.first {
                confirmTableSelection(tableName: firstTable.name)
            }
        } catch {
            connectionError = error.localizedDescription
        }
    }

    func loadCollections(schema: String?) async {
        selectedPickerSchema = schema
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
            let result = try await session.fetchTableData(
                tableName: cfg.tableName,
                schema: cfg.schemaName,
                limit: cfg.rowLimit
            )
            chartData = result.rows.compactMap { row in
                guard let xInfo = row[xCol],
                      let yInfo = row[yCol],
                      let xVal = xInfo.value.map({ "\($0)" }),
                      let yRaw = yInfo.value,
                      let yNum = toDouble(yRaw) else { return nil }
                return ChartDataPoint(x: xVal, y: yNum)
            }
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
}
