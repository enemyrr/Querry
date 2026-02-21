import Foundation

actor ChartDriverSession {
    private var driver: (any DatabaseDriver)?
    private var connectedUri: String?

    func connect(databaseType: DatabaseType, uri: String) async throws {
        if connectedUri == uri { return }
        await driver?.disconnect()
        let newDriver = DatabaseDriverFactory.createDriver(for: databaseType)
        _ = try await newDriver.connect(to: uri)
        driver = newDriver
        connectedUri = uri
    }

    func switchDatabase(to name: String) async throws {
        guard let driver else { throw ChartBlockError.notConnected }
        try await driver.switchDatabase(to: name)
    }

    func listDatabases() async throws -> [any DatabaseWrapper] {
        guard let driver else { throw ChartBlockError.notConnected }
        return try await driver.listDatabases()
    }

    func listCollections(schema: String?) async throws -> [any CollectionWrapper] {
        guard let driver else { throw ChartBlockError.notConnected }
        return try await driver.listCollections(schema: schema)
    }

    func getSchema(tableName: String, schema: String?) async throws -> DatabaseSchemaResult {
        guard let driver else { throw ChartBlockError.notConnected }
        return try await driver.getSchema(for: tableName, schema: schema)
    }

    func fetchTableData(tableName: String, schema: String?, limit: Int, filters: [ChartFilterCondition] = []) async throws -> QueryResult {
        guard let driver else { throw ChartBlockError.notConnected }

        let validFilters = filters.filter(\.isComplete)

        if validFilters.isEmpty {
            return try await driver.findDocuments(
                in: tableName,
                databaseSchema: schema,
                filter: [:],
                skip: 0,
                limit: limit,
                sortBy: nil,
                ascending: nil
            )
        }

        let whereClause = validFilters.map(\.sqlFragment).joined(separator: " AND ")
        let schemaPrefix = schema.map { "\"\($0)\"." } ?? ""
        let query = "SELECT * FROM \(schemaPrefix)\"\(tableName)\" WHERE \(whereClause) LIMIT \(limit)"
        let results = try await driver.executeRawQuery(query, databaseSchema: schema)
        return results.first ?? QueryResult(columns: [], rows: [], totalCount: 0, rawRows: [])
    }

    func fetchAggregatedData(
        tableName: String,
        schema: String?,
        dimensions: [String],
        measures: [(column: String, aggregation: AggregationFunction)],
        limit: Int,
        filters: [ChartFilterCondition] = []
    ) async throws -> QueryResult {
        guard let driver else { throw ChartBlockError.notConnected }

        let schemaPrefix = schema.map { "\"\($0)\"." } ?? ""

        var selectParts: [String] = dimensions.map { "\"\($0)\"" }
        for measure in measures {
            let expr = measure.aggregation.sqlExpression(for: measure.column)
            let alias = "\(measure.column)\(measure.aggregation.sqlAliasSuffix)"
            selectParts.append("\(expr) AS \"\(alias)\"")
        }

        var query = "SELECT \(selectParts.joined(separator: ", ")) FROM \(schemaPrefix)\"\(tableName)\""

        let validFilters = filters.filter(\.isComplete)
        if !validFilters.isEmpty {
            let whereClause = validFilters.map(\.sqlFragment).joined(separator: " AND ")
            query += " WHERE \(whereClause)"
        }

        if !dimensions.isEmpty {
            let groupBy = dimensions.map { "\"\($0)\"" }.joined(separator: ", ")
            query += " GROUP BY \(groupBy) ORDER BY \(groupBy)"
        }

        query += " LIMIT \(limit)"

        let results = try await driver.executeRawQuery(query, databaseSchema: schema)
        return results.first ?? QueryResult(columns: [], rows: [], totalCount: 0, rawRows: [])
    }

    func getInformationSchema() async throws -> [InformationSchema] {
        guard let driver else { throw ChartBlockError.notConnected }
        return try await driver.getInformationSchema()
    }

    func disconnect() async {
        await driver?.disconnect()
        driver = nil
        connectedUri = nil
    }
}

enum ChartBlockError: LocalizedError {
    case notConnected
    case invalidDatabaseType
    case noAxesConfigured

    var errorDescription: String? {
        switch self {
        case .notConnected: "Not connected to database"
        case .invalidDatabaseType: "Unsupported database type"
        case .noAxesConfigured: "Select X and Y axes to render chart"
        }
    }
}
