import Foundation
import PostgresNIO

// MARK: - PostgreSQL Wrappers
struct PostgreSQLDatabaseWrapper: DatabaseWrapper {
    let name: String
}

struct PostgreSQLCollectionWrapper: CollectionWrapper {
    var id: ObjectIdentifier
    let name: String
    let oid: String
}

struct PostgreSQLCell {
    public var dataType: PostgresDataType
    public var format: PostgresFormat
    public var columnName: String
    public var columnIndex: Int
    public var data: Any
}

struct PostgreSQLColumnInfo {
    let name: String
    let dataType: PostgresDataType
    let format: PostgresFormat
    let index: Int
}

struct PostgreSQLRow {
    let data: [String: Any] // Column name -> value
    let index: Int
}

struct PostgreSQLQueryResult {
    let columns: [PostgreSQLColumnInfo]
    let rows: [PostgreSQLRow]
    let totalCount: Int
    
    // Convenience computed properties
    var columnNames: [String] {
        return columns.map { $0.name }
    }
    
    var columnCount: Int {
        return columns.count
    }
    
    var rowCount: Int {
        return rows.count
    }
    
    // Get specific column info by name
    func column(named name: String) -> PostgreSQLColumnInfo? {
        return columns.first { $0.name == name }
    }
    
    // Get value for specific row and column
    func value(row: Int, column: String) -> Any? {
        guard row < rows.count else { return nil }
        return rows[row].data[column]
    }
    
    // Get column info by index
    func column(at index: Int) -> PostgreSQLColumnInfo? {
        guard index >= 0 && index < columns.count else { return nil }
        return columns[index]
    }
    
    // Get all values for a specific column
    func values(for column: String) -> [Any] {
        return rows.compactMap { $0.data[column] }
    }
    
    // Get all values for a column by index
    func values(at columnIndex: Int) -> [Any] {
        guard let columnName = column(at: columnIndex)?.name else { return [] }
        return values(for: columnName)
    }
}



// MARK: - PostgreSQL Driver
class PostgreSQLDriver: DatabaseDriver {
    func findDocuments(in collectionName: String, filter: [String : Any]) async throws -> [PostgreSQLQueryResult] {
        throw DatabaseError.notImplemented("MySQL driver not yet implemented")
    }
    
    typealias Database = PostgreSQLDatabaseWrapper
    typealias Collection = PostgreSQLCollectionWrapper
    typealias Document = [String: Any]
    typealias FormattedDocument = PostgreSQLQueryResult
    
    // Store connection and event loop group for proper cleanup
    private var connection: PostgresConnection?
    private var eventLoopGroup: MultiThreadedEventLoopGroup?
    private var isConnected = false
    
    // Connection configuration
    private var configuration: PostgresConnection.Configuration?
    private var databases: [PostgreSQLDatabaseWrapper] = []
    private var collections: [PostgreSQLCollectionWrapper] = []
    
    deinit {
        // Ensure cleanup happens even if disconnect wasn't called explicitly
        // Capture the resources we need to clean up without capturing self
        let connection = self.connection
        let eventLoopGroup = self.eventLoopGroup
        
        Task { [connection, eventLoopGroup] in
            // Clean up the connection
            if let connection = connection {
                try? await connection.close()
            }
            
            // Clean up the event loop group
            if let eventLoopGroup = eventLoopGroup {
                try? await eventLoopGroup.shutdownGracefully()
            }
        }
    }
    
    func connect(to connectionUri: String) async throws -> PostgreSQLDatabaseWrapper {
        // Parse connection URI
        let config = try parseConnectionString(connectionUri)
        self.configuration = config
        
        // Create event loop group
        let eventLoopGroup = MultiThreadedEventLoopGroup(numberOfThreads: 1)
        self.eventLoopGroup = eventLoopGroup
        
        do {
            // Create and connect to PostgreSQL
            let connection = try await PostgresConnection.connect(
                on: eventLoopGroup.next(),
                configuration: config,
                id: 1,
                logger: Logger(label: "postgres")
            )
            
            self.connection = connection
            self.isConnected = true
            
            return PostgreSQLDatabaseWrapper(name: configuration?.database ?? "Default")
        } catch let error as PSQLError {
            await cleanup()
            throw mapPSQLError(error)
        } catch {
            await cleanup()
            throw DatabaseError.connectionFailed("Failed to establish PostgreSQL connection: \(error.localizedDescription)")
        }
    }
    
    func disconnect() async {
        await cleanup()
    }
    
    private func cleanup() async {
        if let connection = self.connection {
            try? await connection.close()
            self.connection = nil
        }
        
        if let eventLoopGroup = self.eventLoopGroup {
            try? await eventLoopGroup.shutdownGracefully()
            self.eventLoopGroup = nil
        }
        
        self.isConnected = false
    }
    
    private func ensureConnected() throws -> PostgresConnection {
        guard isConnected, let connection = self.connection else {
            throw DatabaseError.connectionFailed("Not connected to PostgreSQL database")
        }
        return connection
    }
    
    func getBuildInfo() async throws -> BuildInfo {
        let connection = try ensureConnected()
        do {
            let rows = try await connection.query("SELECT version()", logger: Logger(label: "postgres"))
            
            var fullVersionString = "Unknown"
            
            for try await (versionString) in rows.decode((String).self) {
                fullVersionString = versionString
            }
            
            guard let version = extractVersionNumber(from: fullVersionString) else {
                throw DatabaseError.operationFailed("Failed to extract build version")
            }
            
            return BuildInfo(
                version: version,
                databaseType: DatabaseType.postgres
            )
        } catch let error as PSQLError {
            throw mapPSQLError(error)
        } catch {
            throw DatabaseError.operationFailed("Failed to get build info: \(error.localizedDescription)")
        }
    }
    
    func listDatabases() async throws -> [PostgreSQLDatabaseWrapper] {
        let connection = try ensureConnected()
        
        do {
            let rows = try await connection.query(
                "SELECT datname FROM pg_database WHERE datistemplate = false",
                logger: Logger(label: "postgres")
            )
            
            var databases: [PostgreSQLDatabaseWrapper] = []
            
            for try await (name) in rows.decode((String).self) {
                databases.append(PostgreSQLDatabaseWrapper(name: name))
            }
            
            return databases
        } catch let error as PSQLError {
            throw mapPSQLError(error)
        } catch {
            throw DatabaseError.operationFailed("Failed to list databases: \(error.localizedDescription)")
        }
    }
    
    func listCollections() async throws -> [PostgreSQLCollectionWrapper] {
        let connection = try ensureConnected()
        
        do {
            let rows = try await connection.query("""
                           SELECT
                               p.oid::bigint AS oid,
                               p.relname AS table_name,
                               n.nspname AS table_schema
                           FROM
                               pg_class AS p
                               JOIN pg_namespace AS n ON p.relnamespace = n.oid
                           WHERE
                               (p.relkind = 'r'
                               OR p.relkind = 'v'
                               OR p.relkind = 'p')
                               AND n.nspname = 'public'
                           """,
                           logger: Logger(label: "postgres")
            )
            
            for try await (oid, tableName, _) in rows.decode((Int64, String, String).self) {
                self.collections.append(PostgreSQLCollectionWrapper(
                    id: ObjectIdentifier(NSString(string: tableName)),
                    name: tableName,
                    oid: oid.description
                ))
            }
            
            
            return collections
        } catch let error as PSQLError {
            throw mapPSQLError(error)
        } catch {
            throw DatabaseError.operationFailed("Failed to list tables: \(error.localizedDescription)")
        }
    }
    
    func getDocumentCount(for collectionName: String, filter: [String: Any]) async throws -> Int {
        return 1
    }
    
    func findDocuments(in collectionName: String, filter: [String: Any]) async throws -> PostgreSQLQueryResult {
        let startTime = CFAbsoluteTimeGetCurrent()
        let connection = try ensureConnected()
        
        // Validate and sanitize the collection name to prevent SQL injection
        let sanitizedCollectionName = try validateAndSanitizeIdentifier(collectionName)
        
        do {
            // Use proper identifier quoting for PostgreSQL
            let query = "SELECT * FROM \(sanitizedCollectionName)"
            let results = try await connection.query(PostgresQuery(unsafeSQL: query), logger: Logger(label: "postgres"))
            
            var columns: [PostgreSQLColumnInfo] = []
            var rows: [PostgreSQLRow] = []
            var rowIndex = 0
            
            for try await row in results {
                var rowData: [String: Any] = [:]
                
                if columns.isEmpty {
                    var columnIndex = 0
                    for cell in row {
                        let columnInfo = PostgreSQLColumnInfo(
                            name: cell.columnName,
                            dataType: cell.dataType,
                            format: cell.format,
                            index: columnIndex
                        )
                        columns.append(columnInfo)
                        columnIndex += 1
                    }
                }
                
                // Extract row data
                for cell in row {
                    let columnName = cell.columnName
                    let value = try extractValue(from: cell)
                    rowData[columnName] = value
                }
                
                let postgresRow = PostgreSQLRow(data: rowData, index: rowIndex)
                rows.append(postgresRow)
                rowIndex += 1
            }
            
            let endTime = CFAbsoluteTimeGetCurrent()
            let executionTime = endTime - startTime
            print("⏱️ Query execution time: \(String(format: "%.3f", executionTime)) seconds")
            print("📊 Fetched \(rows.count) rows")
            
            return PostgreSQLQueryResult(
                columns: columns,
                rows: rows,
                totalCount: rows.count
            )
            
        } catch let error as PSQLError {
            throw mapPSQLError(error)
        } catch {
            throw DatabaseError.operationFailed("Failed to find documents: \(error.localizedDescription)")
        }
    }
    
    func createDocument(in collectionName: String, database: PostgreSQLDatabaseWrapper, document: [String: Any]) async throws {
        throw DatabaseError.notImplemented("MySQL driver not yet implemented")
    }
    
    private func extractValue(from cell: PostgresCell) throws -> Any? {
        // Check if the cell is null
        if cell.bytes == nil {
            return nil
        }
        
        // Extract value based on PostgreSQL data type
        switch cell.dataType {
        case .bool:
            return try cell.decode(Bool.self)
        case .int2:
            return try cell.decode(Int16.self)
        case .int4:
            return try cell.decode(Int32.self)
        case .int8:
            return try cell.decode(Int64.self)
        case .float4:
            return try cell.decode(Float.self)
        case .float8:
            return try cell.decode(Double.self)
        case .text, .varchar, .char:
            return try cell.decode(String.self)
        case .timestamp, .timestamptz:
            return try cell.decode(Date.self)
        case .date:
            return try cell.decode(Date.self)
        case .uuid:
            return try cell.decode(UUID.self)
        case .json, .jsonb:
            // For JSON types, decode as String first, then you can parse as needed
            let jsonString = try cell.decode(String.self)
            return jsonString
        case .bytea:
            return try cell.decode(Data.self)
        case .numeric:
            // PostgreSQL NUMERIC/DECIMAL - decode as Decimal or String
            return try cell.decode(String.self)
        default:
            // For unknown types, try to decode as String
            return try cell.decode(String.self)
        }
    }
    
    func updateDocument(in collectionName: String, database: PostgreSQLDatabaseWrapper, id: Any, data: [String: Any]) async throws {
        throw DatabaseError.notImplemented("MySQL driver not yet implemented")
    }
    
    func deleteDocument(in collectionName: String, database: PostgreSQLDatabaseWrapper, id: Any) async throws {
        throw DatabaseError.notImplemented("MySQL driver not yet implemented")
    }
    
    func createCollection(named collectionName: String) async throws {
        throw DatabaseError.notImplemented("MySQL driver not yet implemented")
    }
    
    func renameCollection(from oldName: String, to newName: String) async throws {
        throw DatabaseError.notImplemented("MySQL driver not yet implemented")
    }
    
    func getSchema(for collectionName: String) async throws -> DatabaseSchemaResult {
        return try await getSchema(for: collectionName, in: "public")
    }
    
    func getSchema(for tableName: String, in schemaName: String = "public") async throws -> DatabaseSchemaResult {
        guard let tableInfo = collections.first(where: { $0.name == tableName }) else {
            throw DatabaseError.configurationError("Database not found")
        }
        
        let connection = try ensureConnected()
        
        do {
            // First try a simpler query without the pg_attribute join to avoid aclitem issues
            let schemaQuery = PostgresQuery(unsafeSQL: """
                SELECT
                    ordinal_position,
                    column_name,
                    udt_name AS data_type,
                    data_type AS format_type,
                    COALESCE(numeric_precision, 0) AS numeric_precision,
                    COALESCE(datetime_precision, 0) AS datetime_precision,
                    COALESCE(numeric_scale, 0) AS numeric_scale,
                    COALESCE(character_maximum_length, 0) AS data_length,
                    is_nullable,
                    '' AS check_col,
                    '' AS check_constraint,
                    COALESCE(column_default, '') AS column_default,
                    '' AS foreign_key,
                    '' AS comment
                FROM
                    information_schema.columns
                WHERE
                    table_name = '\(tableName)'
                    AND table_schema = '\(schemaName)'
                ORDER BY ordinal_position;
            """)
            
            let results = try await connection.query(schemaQuery, logger: Logger(label: "postgres"))
            
            var schemaColumns: [DatabaseSchemaInfo] = []
            
            for try await (ordinalPosition, columnName, dataType, formatType, numericPrecision, datetimePrecision, numericScale, dataLength, isNullable, check, checkConstraint, columnDefault, foreignKey, comment) in results.decode((Int, String, String, String, Int, Int, Int, Int, String, String, String, String, String, String).self) {
                let schemaInfo = DatabaseSchemaInfo(
                    ordinalPosition: ordinalPosition,
                    columnName: columnName,
                    dataType: dataType,
                    formatType: formatType,
                    numericPrecision: numericPrecision,
                    datetimePrecision: datetimePrecision,
                    numericScale: numericScale,
                    dataLength: dataLength,
                    isNullable: isNullable,
                    check: check,
                    checkConstraint: checkConstraint,
                    columnDefault: columnDefault,
                    foreignKey: foreignKey,
                    comment: comment
                )
                
                schemaColumns.append(schemaInfo)
            }
            
            return DatabaseSchemaResult(
                tableName: tableName,
                schemaName: schemaName,
                columns: schemaColumns,
                totalCount: schemaColumns.count
            )
            
        } catch let error as PSQLError {
            throw mapPSQLError(error)
        } catch {
            print(String(reflecting: error))
            throw DatabaseError.operationFailed("Failed to get schema: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Helper Methods
    private func parseConnectionString(_ urlString: String) throws -> PostgresConnection.Configuration {
        guard let url = URL(string: urlString),
              let host = url.host else {
            throw DatabaseError.configurationError("Invalid PostgreSQL URL format")
        }
        
        let port = url.port ?? 5432
        let username = url.user ?? "postgres"
        let password = url.password ?? ""
        let database = String(url.path.dropFirst()) // Remove leading "/"
        
        // Validate required fields
        if username.isEmpty {
            throw DatabaseError.configurationError("Username is required")
        }
        
        if database.isEmpty {
            throw DatabaseError.configurationError("Database name is required")
        }
        
        return PostgresConnection.Configuration(
            host: host,
            port: port,
            username: username,
            password: password.isEmpty ? nil : password,
            database: database,
            tls: .disable // You might want to make this configurable
        )
    }
    
    private func validateAndSanitizeIdentifier(_ identifier: String) throws -> String {
        // Remove whitespace and validate the identifier
        let trimmed = identifier.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Check if the identifier is empty
        if trimmed.isEmpty {
            throw DatabaseError.configurationError("Identifier cannot be empty")
        }
        
        // PostgreSQL identifier rules:
        // - Must start with a letter or underscore
        // - Can contain letters, digits, underscores, and dollar signs
        // - Maximum length is 63 characters
        
        if trimmed.count > 63 {
            throw DatabaseError.configurationError("Identifier too long (max 63 characters)")
        }
        
        // Check if it starts with letter or underscore
        guard let firstChar = trimmed.first,
              firstChar.isLetter || firstChar == "_" else {
            throw DatabaseError.configurationError("Identifier must start with letter or underscore")
        }
        
        // Check for valid characters
        let validCharacters = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "_$"))
        for char in trimmed.unicodeScalars {
            if !validCharacters.contains(char) {
                throw DatabaseError.configurationError("Identifier contains invalid characters")
            }
        }
        
        // Return properly quoted identifier for PostgreSQL
        // Use double quotes to preserve case and handle reserved words
        return "\"\(trimmed)\""
    }
    
    private func buildWhereClause(from filter: [String: Any]) -> String {
        guard !filter.isEmpty else { return "" }
        
        let conditions = filter.map { key, value in
            if let stringValue = value as? String {
                return "\(key) = '\(stringValue)'"
            } else if let numberValue = value as? NSNumber {
                return "\(key) = \(numberValue)"
            } else {
                return "\(key) = '\(value)'"
            }
        }
        
        return conditions.joined(separator: " AND ")
    }
    
    private func mapPSQLError(_ error: PSQLError) -> DatabaseError {
        // Check the specific error code first
        switch error.code {
        case .authMechanismRequiresPassword:
            return DatabaseError.authenticationFailed("Password required for authentication")
        case .unsupportedAuthMechanism:
            return DatabaseError.authenticationFailed("Unsupported authentication mechanism")
        case .saslError:
            return DatabaseError.authenticationFailed("SASL authentication failed")
        case .connectionError:
            return DatabaseError.connectionFailed("Cannot connect to PostgreSQL server")
        case .serverClosedConnection:
            return DatabaseError.connectionFailed("Server closed the connection")
        case .clientClosedConnection:
            return DatabaseError.connectionFailed("Client connection was closed")
        case .server:
            // For server errors, check the server info for more specific error details
            if let serverInfo = error.serverInfo {
                // Check SQL state for authentication errors
                if let sqlState = serverInfo[.sqlState] {
                    switch sqlState {
                    case "28000", "28P01": // Invalid authorization specification / Invalid password
                        return DatabaseError.authenticationFailed("Invalid username or password")
                    case "3D000": // Invalid catalog name (database does not exist)
                        return DatabaseError.connectionFailed("Database does not exist")
                    case "42501": // Insufficient privilege
                        return DatabaseError.authenticationFailed("Insufficient database privileges")
                    default:
                        break
                    }
                }
                
                // Use the error message from the server
                if let message = serverInfo[.message] {
                    return DatabaseError.operationFailed("PostgreSQL server error: \(message)")
                }
            }
            return DatabaseError.operationFailed("PostgreSQL server error")
        default:
            // For debugging, you can use: String(reflecting: error) to see full error details
            return DatabaseError.operationFailed("PostgreSQL error: \(error.code)")
        }
    }
    
    private func extractVersionNumber(from fullVersion: String) -> String? {
        let pattern = #"PostgreSQL\s+(\d+(?:\.\d+)*)"#
        
        do {
            let regex = try NSRegularExpression(pattern: pattern, options: [])
            let nsString = fullVersion as NSString
            let results = regex.matches(in: fullVersion, options: [], range: NSRange(location: 0, length: nsString.length))
            
            if let match = results.first,
               match.numberOfRanges > 1 {
                let versionRange = match.range(at: 1)
                return nsString.substring(with: versionRange)
            }
        } catch {
            print("Regex failed for version extraction: \(error)")
        }
        
        return nil
    }
}

// MARK: - Utility Extensions

extension PostgreSQLDriver {
    /// Helper function to add timeout to async operations
    private func withTimeout<T>(seconds: TimeInterval, operation: @escaping () async throws -> T) async throws -> T? {
        try await withThrowingTaskGroup(of: T?.self) { group in
            group.addTask {
                try await operation()
            }
            
            group.addTask {
                try await Task.sleep(for: .seconds(seconds))
                return nil
            }
            
            if let result = try await group.next() {
                group.cancelAll()
                return result
            } else {
                group.cancelAll()
                return nil
            }
        }
    }
}

// MARK: - Database Error
enum DatabaseError: Error, LocalizedError {
    case notImplemented(String)
    case connectionFailed(String)
    case operationFailed(String)
    case authenticationFailed(String)
    case configurationError(String)
    
    var errorDescription: String? {
        switch self {
        case .notImplemented(let message):
            return "Not implemented: \(message)"
        case .connectionFailed(let message):
            return "Connection failed: \(message)"
        case .operationFailed(let message):
            return "Operation failed: \(message)"
        case .authenticationFailed(let message):
            return "Authentication failed: \(message)"
        case .configurationError(let message):
            return "Configuration error: \(message)"
        }
    }
}
