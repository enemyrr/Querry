import Foundation

@Observable
@MainActor
final class SingleValueBlockViewModel {
    let block: NotebookBlock
    private weak var dataController: NotebookDataController?
    let session = ChartDriverSession()

    var config: SingleValueBlockConfig?

    // Table picker state
    var isShowingTablePicker = false
    var availableCollections: [any CollectionWrapper] = []
    var availableSchemas: [InformationSchema] = []
    var selectedPickerSchema: String?

    // Environment/deployment state (Convex)
    var availableEnvironments: [String] = []
    var selectedEnvironment: String?

    var schemaResult: DatabaseSchemaResult?

    // Single value state
    var singleValueResult: Double?
    var isLoadingSingleValue = false
    var singleValueError: String?

    // Connection state
    var isConnecting = false
    var connectionError: String?

    init(block: NotebookBlock, dataController: NotebookDataController) {
        self.block = block
        self.dataController = dataController
        self.config = block.singleValueConfig()

        if let cfg = config, !cfg.tableName.isEmpty {
            Task {
                await reconnectAndLoad(cfg)
            }
        }
    }

    // MARK: - Connection

    private func resolveConnectionUri(_ cfg: SingleValueBlockConfig) -> String? {
        dataController?.connections.first(where: { $0.keychainId == cfg.connectionKeychainId })?.connectionUri
    }

    private func reconnectAndLoad(_ cfg: SingleValueBlockConfig) async {
        guard let dbType = DatabaseType(rawValue: cfg.databaseType),
              let uri = resolveConnectionUri(cfg) else { return }
        do {
            try await session.connect(databaseType: dbType, uri: uri)

            if Self.environmentCapableTypes.contains(dbType) {
                let databases = try await session.listDatabases()
                availableEnvironments = databases.map(\.name)
                if !cfg.databaseName.isEmpty {
                    selectedEnvironment = cfg.databaseName
                }
            }

            if !cfg.databaseName.isEmpty {
                try await session.switchDatabase(to: cfg.databaseName)
            }

            try await loadSchemasAndCollections(databaseType: dbType, preferredSchema: cfg.schemaName)

            schemaResult = try await session.getSchema(tableName: cfg.tableName, schema: cfg.schemaName)
            if cfg.column != nil {
                await fetchSingleValue()
            }
        } catch {
            singleValueError = error.localizedDescription
        }
    }

    private static let environmentCapableTypes: Set<DatabaseType> = [.convex]

    func connectToSource(_ connection: Connection) async {
        isConnecting = true
        connectionError = nil
        defer { isConnecting = false }

        let uri = connection.connectionUri
        guard let dbType = DatabaseType(rawValue: connection.databaseType.rawValue) else {
            connectionError = "Unsupported database type"
            return
        }

        let draft = SingleValueBlockConfig(
            connectionKeychainId: connection.keychainId,
            connectionName: connection.name,
            databaseType: connection.databaseType.rawValue,
            databaseName: connection.defaultDatabase ?? "",
            tableName: ""
        )

        do {
            try await session.connect(databaseType: dbType, uri: uri)

            if Self.environmentCapableTypes.contains(dbType) {
                let databases = try await session.listDatabases()
                availableEnvironments = databases.map(\.name)

                let defaultDb = connection.defaultDatabase ?? ""
                let envToSelect = availableEnvironments.first(where: { $0 == defaultDb })
                    ?? availableEnvironments.first

                config = draft

                if let env = envToSelect {
                    try await session.switchDatabase(to: env)
                    selectedEnvironment = env
                    config?.databaseName = env

                    try await loadSchemasAndCollections(databaseType: dbType, preferredSchema: nil)
                }
            } else {
                if let defaultDb = connection.defaultDatabase, !defaultDb.isEmpty {
                    try? await session.switchDatabase(to: defaultDb)
                }

                try await loadSchemasAndCollections(databaseType: dbType, preferredSchema: nil)

                config = draft
            }

            persistConfig()
        } catch {
            connectionError = error.localizedDescription
        }
    }

    func switchEnvironment(_ environmentName: String) async {
        selectedEnvironment = environmentName
        availableCollections = []
        availableSchemas = []
        selectedPickerSchema = nil
        schemaResult = nil
        singleValueResult = nil
        singleValueError = nil

        if var cfg = config {
            cfg.databaseName = environmentName
            cfg.tableName = ""
            cfg.schemaName = nil
            cfg.column = nil
            config = cfg
            persistConfig()
        }

        do {
            try await session.switchDatabase(to: environmentName)
            let dbType = config.flatMap { DatabaseType(rawValue: $0.databaseType) } ?? .convex
            try await loadSchemasAndCollections(databaseType: dbType, preferredSchema: nil)
        } catch {
            connectionError = error.localizedDescription
        }
    }

    private static let schemaCapableTypes: Set<DatabaseType> = [.postgres, .supabase, .convex, .mysql]

    private func loadSchemasAndCollections(databaseType: DatabaseType, preferredSchema: String?) async throws {
        if Self.schemaCapableTypes.contains(databaseType) {
            let schemas = try await session.getInformationSchema()
            availableSchemas = schemas
            let schema = preferredSchema ?? schemas.first(where: { $0.name == "public" })?.name ?? schemas.first?.name
            selectedPickerSchema = schema
            availableCollections = try await session.listCollections(schema: schema)
        } else {
            availableSchemas = []
            selectedPickerSchema = nil
            availableCollections = try await session.listCollections(schema: nil)
        }
    }

    func loadCollections(schema: String?) async {
        selectedPickerSchema = schema
        schemaResult = nil
        singleValueResult = nil
        singleValueError = nil
        if var cfg = config {
            cfg.tableName = ""
            cfg.schemaName = schema
            cfg.column = nil
            config = cfg
            persistConfig()
        }
        do {
            availableCollections = try await session.listCollections(schema: schema)
        } catch {
            connectionError = error.localizedDescription
        }
    }

    func confirmTableSelection(tableName: String) {
        guard var cfg = config else { return }
        cfg.tableName = tableName
        cfg.schemaName = selectedPickerSchema
        cfg.column = nil
        config = cfg
        schemaResult = nil
        singleValueResult = nil
        singleValueError = nil
        persistConfig()
        Task { await loadSchemaForConfig() }
    }

    // MARK: - Schema

    private func loadSchemaForConfig() async {
        guard let cfg = config, !cfg.tableName.isEmpty else { return }
        do {
            schemaResult = try await session.getSchema(tableName: cfg.tableName, schema: cfg.schemaName)
        } catch {
            singleValueError = error.localizedDescription
        }
    }

    // MARK: - Column & Aggregation

    func setColumn(_ column: String) {
        config?.column = column
        if let dataType = schemaResult?.columns.first(where: { $0.columnName == column })?.dataType {
            config?.aggregation = AggregationFunction.defaultAggregation(for: dataType)
        }
        persistConfig()
        triggerFetchIfReady()
    }

    func setAggregation(_ agg: AggregationFunction) {
        config?.aggregation = agg
        persistConfig()
        triggerFetchIfReady()
    }

    func setLabel(_ label: String) {
        config?.label = label.isEmpty ? nil : label
        persistConfig()
    }

    private func triggerFetchIfReady() {
        guard config?.column != nil else { return }
        Task { await fetchSingleValue() }
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

    var validColumnNames: Set<String> {
        Set(schemaResult?.columns.map(\.columnName) ?? [])
    }

    func isFilterFieldValid(_ filter: ChartFilterCondition) -> Bool {
        validColumnNames.contains(filter.field)
    }

    // MARK: - Data Fetching

    func fetchSingleValue() async {
        guard let cfg = config,
              let column = cfg.column else {
            singleValueError = "Select a column to display"
            return
        }
        isLoadingSingleValue = true
        singleValueError = nil
        defer { isLoadingSingleValue = false }
        do {
            let validFilters = cfg.filters.filter { $0.isComplete && isFilterFieldValid($0) }
            singleValueResult = try await session.fetchSingleValue(
                tableName: cfg.tableName,
                schema: cfg.schemaName,
                column: column,
                aggregation: cfg.aggregation,
                filters: validFilters
            )
        } catch {
            singleValueError = error.localizedDescription
        }
    }

    // MARK: - Persistence

    private func persistConfig() {
        guard let cfg = config else { return }
        block.saveSingleValueConfig(cfg)
        dataController?.updateBlock(block)
    }

    // MARK: - Cleanup

    func cleanup() async {
        await session.disconnect()
    }
}
