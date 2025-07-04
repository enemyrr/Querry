import Foundation
import PostgresNIO
import NIOCore

// MARK: - PostgreSQL Wrappers
struct PostgreSQLDatabaseWrapper: DatabaseWrapper {
    let name: String
    let size: String?
    let tableCount: Int?
}

struct PostgreSQLCollectionWrapper: CollectionWrapper {
    var id: ObjectIdentifier
    let name: String
    let oid: String
    let type: String
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
    let rows: [PostgresRandomAccessRow]
    let totalCount: Int
    let rawRows: [PostgresRandomAccessRow]
    
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
    
//    // Get value for specific row and column
//    func value(row: Int, column: String) -> Any? {
//        guard row < rows.count else { return nil }
//        return rows[row].data[column]
//    }
    
    // Get column info by index
    func column(at index: Int) -> PostgreSQLColumnInfo? {
        guard index >= 0 && index < columns.count else { return nil }
        return columns[index]
    }
    
    // Get raw cell for lazy decoding - NOW RETURNS PostgresCell
       func rawCell(row: Int, column: String) -> PostgresCell? {
           guard row < rawRows.count else { return nil }
           let randomAccessRow = rawRows[row]
           
           // Check if column exists first
           guard randomAccessRow.contains(column) else { return nil }
           
           return randomAccessRow[column] // This returns PostgresCell
       }
       
       // For compatibility - decode on demand
       func value(row: Int, column: String) -> Any? {
           guard let cell = rawCell(row: row, column: column) else { return nil }
           return try? decodeValue(from: cell)
       }
       
       private func decodeValue(from cell: PostgresCell) throws -> Any? {
           guard cell.bytes != nil else { return nil }
           
           switch cell.dataType {
           case .bool: return try cell.decode(Bool.self)
           case .int2: return try cell.decode(Int16.self)
           case .int4: return try cell.decode(Int32.self)
           case .int8: return try cell.decode(Int64.self)
           case .float4: return try cell.decode(Float.self)
           case .float8: return try cell.decode(Double.self)
           case .text, .varchar, .char: return try cell.decode(String.self)
           case .timestamp, .timestamptz, .date: return try cell.decode(Date.self)
           case .uuid: return try cell.decode(UUID.self)
           case .json, .jsonb: return try cell.decode(String.self)
           case .bytea: return try cell.decode(Data.self)
           case .numeric: return try cell.decode(String.self)
           default: return try cell.decode(String.self)
           }
       }
}



// MARK: - PostgreSQL Driver
class PostgreSQLDriver: DatabaseDriver {
    func findDocuments(in collectionName: String, filter: [String : Any]) async throws -> [QueryResult] {
        throw DatabaseError.notImplemented("PostgreSQL bulk find not yet implemented")
    }
    
    typealias Database = PostgreSQLDatabaseWrapper
    typealias Collection = PostgreSQLCollectionWrapper
    
    // Store connection and event loop group for proper cleanup
    private var connection: PostgresConnection?
    private var eventLoopGroup: MultiThreadedEventLoopGroup?
    private var isConnected = false
    
    // Connection configuration
    private var configuration: PostgresConnection.Configuration?
    private var databases: [PostgreSQLDatabaseWrapper] = []
    private var schema: [PostgreSQLDatabaseWrapper] = []
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
        return try await establishConnection(with: config)
    }

    private func establishConnection(with config: PostgresConnection.Configuration) async throws -> PostgreSQLDatabaseWrapper {
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
            
            return PostgreSQLDatabaseWrapper(name: config.database ?? "postgres", size: nil, tableCount: nil)
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
        
        await databaseSchema.removeAll()
        
        self.isConnected = false
    }
    
    private func ensureConnected() throws -> PostgresConnection {
        guard isConnected, let connection = self.connection else {
            throw DatabaseError.connectionFailed("Not connected to PostgreSQL database")
        }
        return connection
    }
    
    func switchDatabase(to databaseName: String) async throws {
        guard var config = self.configuration else {
            throw DatabaseError.configurationError("No active connection configuration")
        }
        
        // Update the configuration with the new database name
        config.database = databaseName
        
        // Disconnect from the current database
        await disconnect()
        
        // Reconnect to the new database
        _ = try await establishConnection(with: config)
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
                databases.append(PostgreSQLDatabaseWrapper(name: name, size: nil, tableCount: nil))
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
                               n.nspname AS table_schema,
                               CASE p.relkind
                                   WHEN 'r' THEN 'table'
                                   WHEN 'v' THEN 'view'
                                   ELSE 'other'
                               END AS type
                           FROM
                               pg_class AS p
                               JOIN pg_namespace AS n ON p.relnamespace = n.oid
                           WHERE
                               (p.relkind = 'r' OR p.relkind = 'v' OR p.relkind = 'p')
                               AND n.nspname = 'public'
                           """,
                           logger: Logger(label: "postgres")
            )
            
            var collections: [PostgreSQLCollectionWrapper] = []
            for try await (oid, tableName, _, type) in rows.decode((Int64, String, String, String).self) {
                collections.append(PostgreSQLCollectionWrapper(
                    id: ObjectIdentifier(NSString(string: tableName)),
                    name: tableName,
                    oid: oid.description,
                    type: type
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
        return 0
    }
    
    func findDocuments(in collectionName: String, filter: [String: Any], skip: Int, limit: Int) async throws -> QueryResult {
        return try await findDocuments(in: collectionName, filter: filter, skip: skip, limit: limit, sortBy: nil, ascending: nil)
    }
    
    func findDocuments(in collectionName: String, filter: [String: Any], skip: Int, limit: Int, sortBy: String?, ascending: Bool?) async throws -> QueryResult {
        let connection = try ensureConnected()
        let sanitizedCollectionName = try validateAndSanitizeIdentifier(collectionName)
        
        do {
            let query: PostgresQuery
            
            // Check if filter contains a raw query
            if let rawQuery = filter["rawQuery"] as? String, !rawQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                // Use the raw query directly
                query = PostgresQuery(stringLiteral: rawQuery)
            } else {
                // Build standard query with optional WHERE clause and ORDER BY clause
                let whereClause = buildWhereClause(from: filter)
                
                // Get primary key for default sorting when no sorting is provided
                let primaryKey = try await getPrimaryKeyColumn(for: String(sanitizedCollectionName.dropFirst().dropLast())) // Remove quotes
                let orderByClause = buildOrderByClause(sortBy: sortBy, ascending: ascending, primaryKey: primaryKey)
                
                var queryString = "SELECT * FROM \(sanitizedCollectionName)"
                
                if !whereClause.isEmpty {
                    queryString += " WHERE \(whereClause)"
                }
                
                if !orderByClause.isEmpty {
                    queryString += " \(orderByClause)"
                }
                
                queryString += " LIMIT \(limit) OFFSET \(skip)"
                
                query = PostgresQuery(stringLiteral: queryString)
            }
            
            let results = try await connection.query(query, logger: Logger(label: "postgres"))
            let schema = try await getSchema(for: collectionName, forceFetch: true)
            
            var convertedRows: [[String: QueryRowInfo]] = []
            var convertedRawRows: [[String: Any?]] = []
            
            for try await row in results {
                // Convert to random access row for O(1) cell access
                let randomAccessRow = row.makeRandomAccess()
                
                // Process row data in a single pass
                var processedRowData: [String: QueryRowInfo] = [:]
                var rawRowData: [String: Any?] = [:]
                
                for column in schema.columns {
                    let columnName = column.columnName
                    if randomAccessRow.contains(columnName) {
                        let cell = randomAccessRow[columnName]
                        
                        rawRowData[columnName] = cell
                        
                        // Convert to QueryRowInfo for processed row
                        do {
                            processedRowData[columnName] = try decode(from: cell)
                        } catch {
                            debugLog("extractValue: \(String(reflecting: error))")
                            processedRowData[columnName] = nil
                        }
                    } else {
                        processedRowData[columnName] = nil
                        rawRowData[columnName] = nil
                    }
                }
                
                convertedRows.append(processedRowData)
                convertedRawRows.append(rawRowData)
            }
            
            return QueryResult(
                columns: schema.columns.enumerated().map { (index, column) in
                        QueryColumnInfo(
                            name: column.columnName,
                            dataType: column.dataType,
                            format: column.formatType, 
                            index: index
                        )
                    },
                rows: convertedRows,
                totalCount: convertedRows.count,
                rawRows: convertedRawRows
            )
            
        } catch let error as PSQLError {
            debugLog(String(reflecting: error))
            throw mapPSQLError(error)
        } catch {
            throw DatabaseError.operationFailed("Failed to find documents: \(error.localizedDescription)")
        }
    }

    func createDocument(in collectionName: String, document: [String: Any]) async throws {
        let connection = try ensureConnected()
        let sanitizedCollectionName = try validateAndSanitizeIdentifier(collectionName)
        
        guard !document.isEmpty else {
            throw DatabaseError.operationFailed("Cannot insert an empty document.")
        }
        
        let schema = try await getSchema(for: collectionName)
        let columnTypes = Dictionary(uniqueKeysWithValues: schema.columns.map { ($0.columnName, $0.dataType) })
        
        // Sort keys for consistent parameter order
        let sortedKeys = document.keys.sorted()
        
        let columns = sortedKeys.map { "\"\($0)\"" }.joined(separator: ", ")
        
        // Build value placeholders with proper casting for special column types
        let valuePlaceholders = sortedKeys.enumerated().map { (index, key) in
            let parameterIndex = index + 1
            if let columnType = columnTypes[key] {
                switch columnType.lowercased() {
                case "jsonb":
                    return "to_jsonb($\(parameterIndex)::text)"
                case "json":
                    return "$\(parameterIndex)::json"
                case "money":
                    return "$\(parameterIndex)::money"
                default:
                    return "$\(parameterIndex)"
                }
            } else {
                return "$\(parameterIndex)"
            }
        }.joined(separator: ", ")
        
        let queryString = "INSERT INTO \(sanitizedCollectionName) (\(columns)) VALUES (\(valuePlaceholders))"
        
        var bindings = PostgresBindings(capacity: sortedKeys.count)
        
        // Convert values using the same logic as updateDocument
        for key in sortedKeys {
            if let value = document[key] {
//                if let convertedValue = try convertStringToPostgresType(value, columnName: key, columnTypes: columnTypes) {
//                    try bindings.append(convertedValue)
//                } else {
//                    bindings.append(Optional<String>.none)
//                }
            } else {
                bindings.append(Optional<String>.none)
            }
        }
        
        let query = PostgresQuery(unsafeSQL: queryString, binds: bindings)
        
        do {
            try await connection.query(query, logger: Logger(label: "postgres"))
        } catch let error as PSQLError {
            throw mapPSQLError(error)
        } catch {
            throw DatabaseError.operationFailed("Failed to create document: \(error.localizedDescription)")
        }
    }


    func updateDocument(in collectionName: String, id: Any, data: [String: Any]) async throws {
        let connection = try ensureConnected()
        
        guard !data.isEmpty else {
            throw DatabaseError.operationFailed("No changes detected to update")
        }
        
        guard let primaryKey = id as? PostgresCell else {
            throw DatabaseError.operationFailed("Failed to identify the primary key to update")
        }
        
        do {
            let (setClause, values) = try await buildParameterizedSetClause(dataToUpdate: data, for: collectionName)
           
            // Build the UPDATE query with parameter binding
            let queryString = """
                UPDATE \(collectionName)
                SET \(setClause)
                WHERE \(primaryKey.columnName) = $\(values.count + 1)
            """
            
            var bindings = PostgresBindings(capacity: values.count + 1)
            
            for value in values {
                if let value = value {
                    try bindings.append(value)
                } else {
                    bindings.appendNull()
                }
            }
            
            // Convert PostgresCell to PostgresData
            let postgresData = PostgresData(
                type: primaryKey.dataType,
                typeModifier: nil,
                formatCode: primaryKey.format,
                value: primaryKey.bytes
            )
            
            bindings.append(postgresData)

            // Execute the update query with parameter binding
            let query = PostgresQuery(unsafeSQL: queryString, binds: bindings)
            try await connection.query(query, logger: Logger(label: "postgres"))
        } catch let error as PSQLError {
            throw mapPSQLError(error)
        } catch let error as DatabaseError {
            throw error
        } catch {
            throw DatabaseError.operationFailed("Failed to update document: \(error.localizedDescription)")
        }
    }
    
    func decodePostgresTime(from cell: PostgresCell) -> (hour: Int, minute: Int, second: Int, microsecond: Int)? {
        guard cell.dataType == .time, var value = cell.bytes else { return nil }
        // TIME is sent as Int64 microseconds since midnight
        guard let microseconds = value.readInteger(as: Int64.self) else { return nil }
        let totalSeconds = microseconds / 1_000_000
        let hour = Int(totalSeconds / 3600)
        let minute = Int((totalSeconds % 3600) / 60)
        let second = Int(totalSeconds % 60)
        let microsecond = Int(microseconds % 1_000_000)
        return (hour, minute, second, microsecond)
    }
    
    func deleteDocument(in collectionName: String, id: Any) async throws {
        let connection = try ensureConnected()
        let sanitizedCollectionName = try validateAndSanitizeIdentifier(collectionName)
        
        guard let primaryKey = id as? PostgresCell else {
            throw DatabaseError.operationFailed("Cannot delete document without a primary key")
        }
        
        do {
            // Build the DELETE query with parameter binding
            let queryString = """
                DELETE FROM \(sanitizedCollectionName)
                WHERE \(primaryKey.columnName) = $1
            """
            
            // Create PostgresBindings and append the primary key value
            var bindings = PostgresBindings(capacity: 1)
            
            let postgresData = PostgresData(
                type: primaryKey.dataType,
                typeModifier: nil,
                formatCode: primaryKey.format,
                value: primaryKey.bytes
            )
            
            bindings.append(postgresData)
            
            // Execute the delete query with parameter binding
            let query = PostgresQuery(unsafeSQL: queryString, binds: bindings)
            try await connection.query(query, logger: Logger(label: "postgres"))
        } catch let error as PSQLError {
            throw mapPSQLError(error)
        } catch {
            throw DatabaseError.operationFailed("Failed to delete document: \(error.localizedDescription)")
        }
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
    
    
    func buildSystemPrompt(for collectionName: String) async throws -> String {
        let currentDate = Date().formatted(.iso8601)
        
        let schema = await buildSchemaPrompt(for: collectionName)
        
        return """
        You are a PostgreSQL query assistant. Your primary task is to convert natural language user queries into valid PostgreSQL SQL queries.

        Core Responsibilities: 
        - Convert the user query into a PostgreSQL SQL query.
        - Return ONLY the SQL query without explanation.
        - Optimize the query for best performance.
        - Support all PostgreSQL operators and query features.

        # Database Schema
        The current table schema is:
        \(schema)

        # Output Format
        Return ONLY the PostgreSQL SQL query.
        Do not include any explanation, preamble, or commentary.
        Format the query for readability with proper indentation.
        One-line queries are acceptable for simple filters.

        # Examples

        **Example 1:**
        **Input:** Find all users where age is greater than 30
        **Output:**
        SELECT * FROM users WHERE age > 30;

        **Example 2:**
        **Input:** Get records where status is active and created date is in the last week
        **Output:**
        SELECT * FROM records 
        WHERE status = 'active' 
        AND created_at > CURRENT_DATE - INTERVAL '7 days';

        **Example 3:**
        **Input:** Show me customers from New York or California with at least 5 orders
        **Output:**
        SELECT * FROM customers 
        WHERE (state = 'New York' OR state = 'California') 
        AND order_count >= 5;

        **Example 4:**
        **Input:** Get user with id 12345
        **Output:**
        SELECT * FROM users WHERE id = 12345;

        **Example 5:**
        **Input:** Find products containing 'laptop' in name, ordered by price descending
        **Output:**
        SELECT * FROM products 
        WHERE name ILIKE '%laptop%' 
        ORDER BY price DESC;

        # Notes
        - NEVER provide explanations or ask clarifying questions.
        - NEVER describe what the query does.
        - Use the provided schema to understand available columns and data types.
        - When user input is ambiguous, refer to the schema for proper column names.
        - Use appropriate PostgreSQL operators (=, >, <, IN, LIKE, ILIKE, etc.) based on query requirements.
        - Use ILIKE for case-insensitive string matching.
        - Use proper PostgreSQL date/time functions (CURRENT_DATE, INTERVAL, etc.).
        - Default to SELECT * unless specific columns are mentioned.
        - Include proper semicolon termination.
        - Return the SQL query as plain text only. Do NOT use code blocks, backticks, or any markdown formatting.
        - Only generate SELECT queries. Do not create UPDATE, DELETE, INSERT, or any data-modifying queries.

        Current Date: \(currentDate)
        """
    }
    
    
    private func buildSchemaPrompt(for collectionName: String) async -> String {
        do {
            let schemaResult = try await getSchema(for: collectionName)
            let columnInfo = schemaResult.columns
                .map { column in
                    let nullable = column.isNullable == "YES" ? "NULL" : "NOT NULL"
                    let defaultValue = column.columnDefault.map { " DEFAULT \($0)" } ?? ""
                    return "\(column.columnName): \(column.dataType) \(nullable)\(defaultValue)"
                }
                .joined(separator: "\n")
            
            return """
            Table: \(schemaResult.tableName)
            Schema: \(schemaResult.schemaName)
            Columns:
            \(columnInfo)
            """
        } catch {
            return "No schema found for \(collectionName)\n"
        }
    }


   
    // MARK: - Schema Cache
    
    /// Efficient composite key for schema caching
    private struct SchemaKey: Hashable {
        let schemaName: String
        let tableName: String
        
        init(_ schemaName: String, _ tableName: String) {
            self.schemaName = schemaName
            self.tableName = tableName
        }
    }
    
    /// Thread-safe schema cache with size limits
    private actor SchemaCache {
        private var cache: [SchemaKey: DatabaseSchemaResult] = [:]
        private let maxSize: Int
        private var accessOrder: [SchemaKey] = [] // For LRU eviction
        
        init(maxSize: Int = 100) {
            self.maxSize = maxSize
        }
        
        func get(_ key: SchemaKey) -> DatabaseSchemaResult? {
            guard let result = cache[key] else { return nil }
            
            // Update access order for LRU
            if let index = accessOrder.firstIndex(of: key) {
                accessOrder.remove(at: index)
            }
            accessOrder.append(key)
            
            return result
        }
        
        func set(_ key: SchemaKey, value: DatabaseSchemaResult) {
            // Remove if already exists to update access order
            if cache[key] != nil {
                if let index = accessOrder.firstIndex(of: key) {
                    accessOrder.remove(at: index)
                }
            }
            
            cache[key] = value
            accessOrder.append(key)
            
            // Enforce size limit with LRU eviction
            if cache.count > maxSize {
                let oldestKey = accessOrder.removeFirst()
                cache.removeValue(forKey: oldestKey)
            }
        }
        
        func remove(_ key: SchemaKey) {
            cache.removeValue(forKey: key)
            if let index = accessOrder.firstIndex(of: key) {
                accessOrder.remove(at: index)
            }
        }
        
        func removeAll() {
            cache.removeAll()
            accessOrder.removeAll()
        }
        
        var count: Int {
            cache.count
        }
    }
    
    func getDatabaseMetadata() async throws -> [Database] {
        guard let config = self.configuration else {
            throw DatabaseError.connectionFailed("No configuration available")
        }
        
        let connection = try ensureConnected()
        
        do {
            // Step 1: Get all database names and sizes in one efficient query
            let databaseQuery = PostgresQuery("""
                SELECT 
                    datname AS database_name,
                    pg_size_pretty(pg_database_size(datname)) AS database_size,
                    datallowconn AS allow_connections
                FROM pg_database 
                WHERE datistemplate = false
            """)
            
            let results = try await connection.query(databaseQuery, logger: Logger(label: "postgres"))
            var databaseList: [(name: String, size: String, allowConn: Bool)] = []
            
            for try await (name, size, allowConn) in results.decode((String, String, Bool).self) {
                databaseList.append((name: name, size: size, allowConn: allowConn))
            }
            
            // Step 2: Get table counts for each database concurrently
            let databases = try await withThrowingTaskGroup(of: Database.self, returning: [Database].self) { group in
                for dbInfo in databaseList {
                    group.addTask {
                        let tableCount = try await self.getTableCountForDatabase(
                            name: dbInfo.name,
                            config: config,
                            allowConnections: dbInfo.allowConn
                        )
                        
                        return Database(
                            name: dbInfo.name,
                            size: dbInfo.size,
                            tableCount: tableCount
                        )
                    }
                }
                
                var results: [Database] = []
                for try await database in group {
                    results.append(database)
                }
                
                // Sort by size (descending) to match the original query order
                return results
            }
            
            return databases.sorted { $0.name < $1.name }
        } catch let error as PSQLError {
            throw mapPSQLError(error)
        } catch {
            throw DatabaseError.operationFailed("Failed to get database metadata: \(error.localizedDescription)")
        }
    }
    
    private func getTableCountForDatabase(name: String, config: PostgresConnection.Configuration, allowConnections: Bool) async throws -> Int {
        // Skip databases that don't allow connections
        guard allowConnections else {
            return 0
        }
        
        // Create temporary configuration for this database
        var tempConfig = config
        tempConfig.database = name
        
        let eventLoopGroup = MultiThreadedEventLoopGroup(numberOfThreads: 1)
        
        do {
            let tempConnection = try await PostgresConnection.connect(
                on: eventLoopGroup.next(),
                configuration: tempConfig,
                id: Int.random(in: 1000...9999), // Random ID to avoid conflicts
                logger: Logger(label: "postgres-metadata")
            )
            
            // Get table count with optimized query
            let countQuery = try await tempConnection.query("""
                SELECT COUNT(*)::int as table_count
                FROM information_schema.tables 
                WHERE table_schema NOT IN ('information_schema', 'pg_catalog', 'pg_toast')
                AND table_type = 'BASE TABLE'
            """, logger: Logger(label: "postgres-metadata"))
            
            var tableCount = 0
            for try await (count) in countQuery.decode((Int32).self) {
                tableCount = Int(count)
                break
            }
            
            // Clean up connection
            try await tempConnection.close()
            try await eventLoopGroup.shutdownGracefully()
            
            return tableCount
            
        } catch {
            // Clean up on error
            try? await eventLoopGroup.shutdownGracefully()
            
            // Log the error but don't fail the entire operation
            debugLog("Warning: Could not get table count for database '\(name)': \(error.localizedDescription)")
            return 0
        }
    }
    
    // Cache for database schemas with performance optimizations
    private let databaseSchema = SchemaCache()

    func getSchema(for tableName: String, in schemaName: String = "public", forceFetch: Bool = false) async throws -> DatabaseSchemaResult {
        let cacheKey = SchemaKey(schemaName, tableName)
        
        if !forceFetch, let cachedSchema = await databaseSchema.get(cacheKey) {
               return cachedSchema
           }
        
        let connection = try ensureConnected()
        
        do {
            let schemaQuery = PostgresQuery("""
                SELECT
                    c.ordinal_position,
                    c.column_name,
                    c.udt_name AS data_type,
                    COALESCE(t.oid, 0)::bigint AS pg_type_oid,
                    t.typname AS pg_type_name,
                    t.typtype,  -- 'e' for enum, 'b' for base type, 'c' for composite, etc.
                    CASE 
                        WHEN t.typtype = 'e' THEN 'enum'
                        WHEN t.typtype = 'c' THEN 'composite'
                        WHEN t.typtype = 'd' THEN 'domain'
                        WHEN c.data_type = 'ARRAY' THEN 'array'
                        ELSE 'base'
                    END AS type_category,
                    COALESCE(c.numeric_precision, 0) AS numeric_precision,
                    COALESCE(c.datetime_precision, 0) AS datetime_precision,
                    COALESCE(c.numeric_scale, 0) AS numeric_scale,
                    COALESCE(c.character_maximum_length, 0) AS data_length,
                    c.is_nullable,
                    '' AS check_col,
                    '' AS check_constraint,
                    COALESCE(c.column_default, '') AS column_default,
                    '' AS foreign_key,
                    '' AS comment
                FROM
                    information_schema.columns c
                LEFT JOIN pg_type t ON t.typname = c.udt_name
                WHERE
                    c.table_name = '\(unescaped: tableName)'
                    AND c.table_schema = '\(unescaped: schemaName)'
                ORDER BY c.ordinal_position;
            """)
            
            let results = try await connection.query(schemaQuery, logger: Logger(label: "postgres"))
            var databaseSchemaInfo: [DatabaseSchemaInfo] = []
            
            for try await (ordinalPosition, columnName, dataType, pgTypeOid, _, _, _, numericPrecision, datetimePrecision, numericScale, dataLength, isNullable, check, checkConstraint, columnDefault, foreignKey, comment) in results.decode((
                            Int, String, String, Int64, String?, String?, String, Int, Int, Int, Int, String, String, String, String, String, String).self) {
                let format = PostgresDataType(UInt32(pgTypeOid))
                let schemaInfo = DatabaseSchemaInfo(
                    ordinalPosition: ordinalPosition,
                    columnName: columnName,
                    dataType: dataType,
                    formatType: format.description,
                    typeOid: Int(format.rawValue),
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
                
                databaseSchemaInfo.append(schemaInfo)
            }
            
            let schemaResult = DatabaseSchemaResult(
                tableName: tableName,
                schemaName: schemaName,
                columns: databaseSchemaInfo,
                totalCount: databaseSchemaInfo.count
            )
            
//             Cache the result for future use
            await databaseSchema.set(cacheKey, value: schemaResult)
            
            return schemaResult
            
        } catch let error as PSQLError {
            throw mapPSQLError(error)
        } catch {
            print(error.localizedDescription)
            throw DatabaseError.operationFailed("Failed to get schema: \(error.localizedDescription)")
        }
    }
    
    /// Clear the schema cache - useful when schema changes are expected
    func clearSchemaCache() async {
        await databaseSchema.removeAll()
    }
    
    /// Clear schema cache for a specific table
    func clearSchemaCache(for tableName: String, in schemaName: String = "public") async {
        let cacheKey = SchemaKey(schemaName, tableName)
        await databaseSchema.remove(cacheKey)
    }
    
    /// Get current cache statistics
    func getSchemaCacheStats() async -> (count: Int, maxSize: Int) {
        let count = await databaseSchema.count
        return (count: count, maxSize: 100)
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
        // Filter out the rawQuery key as it's not meant for WHERE clause building
        let filteredDict = filter.filter { key, _ in key != "rawQuery" }
        
        guard !filteredDict.isEmpty else { return "" }
        
        let conditions = filteredDict.map { key, value in
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
    
    private func buildOrderByClause(sortBy: String?, ascending: Bool?, primaryKey: String?) -> String {
        // If sortBy is provided, use it
        if let sortBy = sortBy, !sortBy.isEmpty {
            // Validate column name to prevent SQL injection
            do {
                let sanitizedColumn = try validateAndSanitizeColumnName(sortBy)
                let direction = ascending == false ? "DESC" : "ASC"
                return "ORDER BY \(sanitizedColumn) \(direction)"
            } catch {
                // If column validation fails, fall back to primary key if it exists
                if let primaryKey = primaryKey {
                    return "ORDER BY \(primaryKey) ASC"
                }
                return ""
            }
        } else {
            // No sorting provided, use primary key ASC as default if it exists
            if let primaryKey = primaryKey {
                return "ORDER BY \(primaryKey) ASC"
            }
            return ""
        }
    }
    
    private func buildParameterizedSetClause(dataToUpdate: [String: Any], for tableName: String, in schemaName: String = "public") async throws -> (String, [PostgresEncodable?]) {
        var setClauses: [String] = []
        var values: [PostgresEncodable?] = []
        var parameterIndex = 1
        
        // Get the schema to determine correct data types
        let schema = try await getSchema(for: tableName, in: schemaName)
        let columnTypes = Dictionary(uniqueKeysWithValues: schema.columns.map { ($0.columnName, $0.typeOid) })
        
        for (columnName, value) in dataToUpdate {
            let columnTypeString = columnTypes[columnName] ?? 0
            let columnType = PostgresDataType(UInt32(columnTypeString))
            setClauses.append("\(columnName) = $\(parameterIndex)")
            
            let convertedValue = try encode(value, columnName: columnName, columnType: columnType)
            values.append(convertedValue)
            
            parameterIndex += 1
        }
        
        return (setClauses.joined(separator: ", "), values)
    }

    
    
    private func validateAndSanitizeColumnName(_ columnName: String) throws -> String {
        let trimmed = columnName.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Check if the column name is empty
        if trimmed.isEmpty {
            throw DatabaseError.configurationError("Column name cannot be empty")
        }
        
        // PostgreSQL column name rules (similar to identifier rules)
        if trimmed.count > 63 {
            throw DatabaseError.configurationError("Column name too long (max 63 characters)")
        }
        
        // Check if it starts with letter or underscore
        guard let firstChar = trimmed.first,
              firstChar.isLetter || firstChar == "_" else {
            throw DatabaseError.configurationError("Column name must start with letter or underscore")
        }
        
        // Check for valid characters
        let validCharacters = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "_$"))
        for char in trimmed.unicodeScalars {
            if !validCharacters.contains(char) {
                throw DatabaseError.configurationError("Column name contains invalid characters")
            }
        }
        
        // Return properly quoted column name for PostgreSQL
        return "\"\(trimmed)\""
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
                        return DatabaseError.databaseNotFound("Database does not exist")
                    case "42501": // Insufficient privilege
                        return DatabaseError.authenticationFailed("Insufficient database privileges")
                    default:
                        break
                    }
                }
                
                // Use the error message from the server
                if let message = serverInfo[.message] {
                    return DatabaseError.operationFailed("ERROR: \(message)")
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
            debugLog("Regex failed for version extraction: \(error)")
        }
        
        return nil
    }
    
    // MARK: - Helper method to get primary key column
       private func getPrimaryKeyColumn(for tableName: String, in schemaName: String = "public") async throws -> String? {
           let connection = try ensureConnected()
           
           do {
               let query = PostgresQuery("""
                   SELECT a.attname
                   FROM pg_index i
                   JOIN pg_attribute a ON a.attrelid = i.indrelid AND a.attnum = ANY(i.indkey)
                   WHERE i.indrelid = '\(unescaped: schemaName).\(unescaped: tableName)'::regclass
                   AND i.indisprimary
                   ORDER BY a.attnum
                   LIMIT 1
               """)
               
               let results = try await connection.query(query, logger: Logger(label: "postgres"))
               
               for try await (columnName) in results.decode((String).self) {
                   return "\"\(columnName)\""  // Return quoted column name
               }
               
               // If no primary key is found, return nil
               return nil
               
           } catch {
               // If the query fails for any reason (e.g., table not found, permissions), return nil
               return nil
           }
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
    case databaseNotFound(String)
    case databaseNotSelected

    var errorDescription: String? {
        switch self {
        case .notImplemented(let message):
            return "Not implemented: \(message)"
        case .connectionFailed(let message):
            return "Connection failed: \(message)"
        case .operationFailed(let message):
            return message
        case .authenticationFailed(let message):
            return "Authentication failed: \(message)"
        case .configurationError(let message):
            return "Configuration error: \(message)"
        case .databaseNotFound(let message):
            return "Database: \(message)"
        case .databaseNotSelected:
            return "Database not selected"
        }
    }
}
