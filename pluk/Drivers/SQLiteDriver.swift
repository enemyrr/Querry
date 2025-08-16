import Foundation
import SQLiteNIO
import NIOCore
import Logging
import Darwin

// MARK: - SQLite Wrappers
struct SQLiteDatabaseWrapper: DatabaseWrapper {
    let name: String
    let size: String?
    let tableCount: Int?
}

struct SQLiteCollectionWrapper: CollectionWrapper {
    var id: ObjectIdentifier
    let name: String
    let type: String = "table"
}

// MARK: - SQLite Driver
class SQLiteDriver: DatabaseDriver {
    typealias Database = SQLiteDatabaseWrapper
    typealias Collection = SQLiteCollectionWrapper
    
    // Store connection and event loop group for proper cleanup
    private var connection: SQLiteConnection?
    private var eventLoopGroup: MultiThreadedEventLoopGroup?
    private var isConnected = false
    
    // Connection configuration
    private var databasePath: String?
    private var threadPool: NIOThreadPool?
    private var securityScopedURL: URL? = nil
    private var databases: [SQLiteDatabaseWrapper] = []
    private var collections: [SQLiteCollectionWrapper] = []
    
    deinit {
        // Ensure cleanup happens even if disconnect wasn't called explicitly
        let connection = self.connection
        let eventLoopGroup = self.eventLoopGroup
        let threadPool = self.threadPool
        let securityScopedURL = self.securityScopedURL
        
        Task { [connection, eventLoopGroup, threadPool, securityScopedURL] in
            if let connection = connection {
                try? await connection.close()
            }
            
            if let threadPool = threadPool {
                try? await threadPool.shutdownGracefully()
            }
            
            if let eventLoopGroup = eventLoopGroup {
                try? await eventLoopGroup.shutdownGracefully()
            }
            
            // Stop accessing security-scoped resource
            securityScopedURL?.stopAccessingSecurityScopedResource()
        }
    }
    
    func connect(to connectionUri: String) async throws -> SQLiteDatabaseWrapper {
        let path = try parseConnectionString(connectionUri)
        return try await establishConnection(to: path)
    }
    
    private func establishConnection(to path: String) async throws -> SQLiteDatabaseWrapper {
        // Preserve security-scoped URL before cleanup
        let preservedSecurityScopedURL = self.securityScopedURL
        
        // Clean up any existing connection first (but preserve security-scoped URL)
        await cleanup()
        
        // Restore the security-scoped URL after cleanup
        self.securityScopedURL = preservedSecurityScopedURL
        
        self.databasePath = path
        
        // Check if this path was resolved from a security-scoped bookmark
        let hasSecurityScopedAccess = self.securityScopedURL != nil
        
        do {
            // Create event loop group with proper lifecycle management
            let eventLoopGroup = MultiThreadedEventLoopGroup(numberOfThreads: 1)
            self.eventLoopGroup = eventLoopGroup
            
            // Create thread pool for SQLite operations
            let threadPool = NIOThreadPool(numberOfThreads: 1)
            threadPool.start()
            self.threadPool = threadPool
            
            // Determine storage type based on path
            let storage: SQLiteConnection.Storage
            if path == ":memory:" {
                storage = .memory
            } else {
                // Use the security-scoped URL if available, otherwise fall back to regular path
                let fileURL: URL
                let absolutePath: String
                
                if let securityScopedURL = self.securityScopedURL {
                    // Use the security-scoped URL directly - this is the SAME URL object that has active access
                    fileURL = securityScopedURL
                    absolutePath = securityScopedURL.path
                } else {
                    // Fall back to regular path handling
                    absolutePath = path.hasPrefix("/") ? path : FileManager.default.currentDirectoryPath + "/" + path
                    fileURL = URL(fileURLWithPath: absolutePath)
                }
                
                // Test if we can access the file and validate it's a potential SQLite file
                let fileManager = FileManager.default
                
                // Basic file validation
                if fileManager.fileExists(atPath: absolutePath) {
                    // Check if it's a directory (common mistake)
                    var isDirectory: ObjCBool = false
                    fileManager.fileExists(atPath: absolutePath, isDirectory: &isDirectory)
                    if isDirectory.boolValue {
                        throw DatabaseError.configurationError("Selected path is a directory, not a SQLite database file.\n\n→ Go to Edit Connection → Click \"Change\" → Select a .db, .sqlite, or .sqlite3 file")
                    }
                    
                    // Check file size (zip files and other archives are usually much larger)
                    if let attributes = try? fileManager.attributesOfItem(atPath: absolutePath),
                       let fileSize = attributes[.size] as? Int64 {
                        // If file is over 1GB, it's probably not a typical SQLite file
                        if fileSize > 1_000_000_000 {
                            throw DatabaseError.configurationError("Selected file is unusually large (\(ByteCountFormatter().string(fromByteCount: fileSize))).\n\nThis might not be a SQLite database file.\n\n→ Go to Edit Connection → Click \"Change\" → Select a .db, .sqlite, or .sqlite3 file")
                        }
                    }
                    
                    // Check file extension as a hint
                    let fileExtension = URL(fileURLWithPath: absolutePath).pathExtension.lowercased()
                    let validExtensions = ["db", "sqlite", "sqlite3", ""]
                    if !validExtensions.contains(fileExtension) {
                        // Allow but warn about unusual extensions
                        print("⚠️ Warning: File extension '.\(fileExtension)' is not typical for SQLite databases")
                    }
                }
                
                // The SQLite library will handle access through the security-scoped URL
                if !hasSecurityScopedAccess {
                    if !fileManager.isReadableFile(atPath: absolutePath) {
                        throw DatabaseError.configurationError("SQLite file is not accessible: \(absolutePath)\n\nFor security reasons, please:\n1. Use the folder button (📁) to select your SQLite file\n2. Or move your database to a user-accessible location like Documents folder")
                    }
                    if !fileManager.isWritableFile(atPath: absolutePath) {
                        throw DatabaseError.configurationError("SQLite file is not writable: \(absolutePath)")
                    }
                } else {
                        // Test if we can actually read the file with security-scoped access
                        do {
                            let _ = try Data(contentsOf: fileURL)
                            // Try opening a file descriptor which might work better with SQLite NIO
                            let fileDescriptor = open(absolutePath, O_RDWR)
                            if fileDescriptor != -1 {
                                close(fileDescriptor)
                            }
                        } catch {
                            // Try a different approach - test if the security-scoped access is actually working
                            if let securityScopedURL = self.securityScopedURL {
                                // Try stopping and restarting access
                                securityScopedURL.stopAccessingSecurityScopedResource()
                                if securityScopedURL.startAccessingSecurityScopedResource() {
                                    // Try reading again
                                    do {
                                        let _ = try Data(contentsOf: securityScopedURL)
                                    } catch {
                                        throw DatabaseError.configurationError("Cannot access the SQLite file. Please try selecting the file again using the folder button (📁).")
                                    }
                                } else {
                                    throw DatabaseError.configurationError("Lost access to the SQLite file. Please select the file again using the folder button (📁).")
                                }
                            }
                        }
                    }
                
                storage = .file(path: absolutePath)
            }
            
            let connection = try await SQLiteConnection.open(
                storage: storage,
                threadPool: threadPool,
                on: eventLoopGroup.next()
            )
            
            // Store connection immediately so it can be cleaned up if anything fails
            self.connection = connection
            
            do {
                let _ = try await connection.query("PRAGMA journal_mode = MEMORY")
                self.isConnected = true
                
                // Extract database name from path
                let databaseName: String
                if path == ":memory:" {
                    databaseName = "In-Memory Database"
                } else {
                    databaseName = URL(fileURLWithPath: path).lastPathComponent
                }
                
                return SQLiteDatabaseWrapper(name: databaseName, size: nil, tableCount: nil)
            } catch {
                // Connection was created but query failed - cleanup will handle closing it
                await cleanup()
                throw error
            }
            
        } catch {
            // Clean up on failure (handles cases where connection creation itself failed)
            await cleanup()
            
            if error is CancellationError {
                throw DatabaseError.connectionFailed("SQLite connection was cancelled - this might be due to app lifecycle or rapid connection changes")
            } else {
                throw DatabaseError.connectionFailed(error.localizedDescription)
            }
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
        
        if let threadPool = self.threadPool {
            try? await threadPool.shutdownGracefully()
            self.threadPool = nil
        }
        
        if let eventLoopGroup = self.eventLoopGroup {
            try? await eventLoopGroup.shutdownGracefully()
            self.eventLoopGroup = nil
        }
        
        // Stop accessing security-scoped resource
        if let securityScopedURL = self.securityScopedURL {
            securityScopedURL.stopAccessingSecurityScopedResource()
            self.securityScopedURL = nil
        }
        
        self.isConnected = false
    }
    
    private func ensureConnected() async throws -> SQLiteConnection {
        guard let connection = self.connection else {
            throw DatabaseError.connectionFailed("Not connected to SQLite database")
        }
        
        if connection.isClosed {
            guard let path = self.databasePath else {
                throw DatabaseError.configurationError("No active connection configuration")
            }
            
            _ = try await establishConnection(to: path)
            return self.connection!
        }
        
        return connection
    }
    
    func reconnect() async throws {
        await disconnect()
        if let path = self.databasePath {
            _ = try await establishConnection(to: path)
        }
    }
    
    func switchDatabase(to databaseName: String) async throws {
        // For SQLite, switching database means connecting to a different file
        await disconnect()
        _ = try await establishConnection(to: databaseName)
    }
    
    func getBuildInfo() async throws -> BuildInfo {
        let connection = try await ensureConnected()
        
        do {
            let rows = try await connection.query("SELECT sqlite_version()")
            
            var version = "Unknown"
            for row in rows {
                if let versionString = row.column("sqlite_version()")?.string {
                    version = versionString
                    break
                }
            }
            
            return BuildInfo(
                version: version,
                databaseType: DatabaseType.sqlite
            )
        } catch {
            throw DatabaseError.operationFailed("Failed to get build info: \(error.localizedDescription)")
        }
    }
    
    func listDatabases() async throws -> [SQLiteDatabaseWrapper] {
        // SQLite only has one database per file
        guard let path = self.databasePath else {
            throw DatabaseError.configurationError("No database path configured")
        }
        
        let databaseName = URL(fileURLWithPath: path).lastPathComponent
        return [SQLiteDatabaseWrapper(name: databaseName, size: nil, tableCount: nil)]
    }
    
    func getDatabaseMetadata() async throws -> [SQLiteDatabaseWrapper] {
        return try await listDatabases()
    }
    
    func listCollections() async throws -> [SQLiteCollectionWrapper] {
        let connection = try await ensureConnected()
        
        do {
            let rows = try await connection.query("""
                SELECT name, type FROM sqlite_master 
                WHERE type IN ('table', 'view') 
                AND name NOT LIKE 'sqlite_%'
                ORDER BY name
            """)
            
            var collections: [SQLiteCollectionWrapper] = []
            for row in rows {
                if let name = row.column("name")?.string,
                   let _ = row.column("type")?.string {
                    collections.append(SQLiteCollectionWrapper(
                        id: ObjectIdentifier(NSString(string: name)),
                        name: name,
                    ))
                }
            }
            
            return collections
        } catch {
            throw DatabaseError.operationFailed("Failed to list tables: \(error.localizedDescription)")
        }
    }
    
    func getDocumentCount(for collectionName: String, filter: [String: Any]) async throws -> Int {
        let connection = try await ensureConnected()
        let sanitizedTableName = try validateAndSanitizeIdentifier(collectionName)
        
        do {
            let whereClause = buildWhereClause(from: filter)
            var queryString = "SELECT COUNT(*) as count FROM \(sanitizedTableName)"
            
            if !whereClause.isEmpty {
                queryString += " WHERE \(whereClause)"
            }
            
            let rows = try await connection.query(queryString)
            
            for row in rows {
                if let count = row.column("count")?.integer {
                    return Int(count)
                }
            }
            
            return 0
        } catch {
            throw DatabaseError.operationFailed("Failed to get document count: \(error.localizedDescription)")
        }
    }
    
    func findDocuments(in collectionName: String, filter: [String: Any]) async throws -> [QueryResult] {
        let result = try await findDocuments(in: collectionName, filter: filter, skip: 0, limit: 1000)
        return [result]
    }
    
    func findDocuments(in collectionName: String, filter: [String: Any], skip: Int, limit: Int) async throws -> QueryResult {
        return try await findDocuments(in: collectionName, filter: filter, skip: skip, limit: limit, sortBy: nil, ascending: nil)
    }
    
    func findDocuments(in collectionName: String, filter: [String: Any], skip: Int, limit: Int, sortBy: String?, ascending: Bool?) async throws -> QueryResult {
        let connection = try await ensureConnected()
        let sanitizedTableName = try validateAndSanitizeIdentifier(collectionName)
        
        do {
            let queryString: String
            
            // Check if filter contains a raw query
            if let rawQuery = filter["rawQuery"] as? String, !rawQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                // Use the raw query directly
                queryString = rawQuery
            } else {
                // Build standard query with optional WHERE clause and ORDER BY clause
                let whereClause = buildWhereClause(from: filter)
                let orderByClause = buildOrderByClause(sortBy: sortBy, ascending: ascending)
                
                var standardQuery = "SELECT * FROM \(sanitizedTableName)"
                
                if !whereClause.isEmpty {
                    standardQuery += " WHERE \(whereClause)"
                }
                
                if !orderByClause.isEmpty {
                    standardQuery += " \(orderByClause)"
                }
                
                standardQuery += " LIMIT \(limit) OFFSET \(skip)"
                queryString = standardQuery
            }
            
            let rows = try await connection.query(queryString)
            
            // Get column information from the first row
            var queryColumns: [QueryColumnInfo] = []
            var convertedRows: [[String: QueryRowInfo]] = []
            var rawRows: [[String: Any?]] = []
            
            // Get column information using PRAGMA table_info if this is the first call
            if queryColumns.isEmpty && !rows.isEmpty {
                // Get column info from PRAGMA table_info
                do {
                    let schemaRows = try await connection.query("PRAGMA table_info(\(sanitizedTableName))")
                    var columnInfoMap: [String: String] = [:]
                    
                    for schemaRow in schemaRows {
                        if let columnName = schemaRow.column("name")?.string,
                           let dataType = schemaRow.column("type")?.string {
                            columnInfoMap[columnName] = dataType
                        }
                    }
                    
                    // Build QueryColumnInfo from the first row's columns
                    if let firstRow = rows.first {
                        for (columnIndex, column) in firstRow.columns.enumerated() {
                            let dataType = columnInfoMap[column.name] ?? "TEXT"
                            queryColumns.append(QueryColumnInfo(
                                name: column.name,
                                dataType: dataType,
                                format: nil,
                                index: columnIndex
                            ))
                        }
                    }
                } catch {
                    // Fallback: create columns with unknown types
                    if let firstRow = rows.first {
                        for (columnIndex, column) in firstRow.columns.enumerated() {
                            queryColumns.append(QueryColumnInfo(
                                name: column.name,
                                dataType: "TEXT", // Default fallback
                                format: nil,
                                index: columnIndex
                            ))
                        }
                    }
                }
            }
            
            for (_, row) in rows.enumerated() {
                // Process row data
                var processedRowData: [String: QueryRowInfo] = [:]
                var rawRowData: [String: Any?] = [:]
                
                for column in queryColumns {
                    let columnName = column.name
                    let sqliteColumn = row.column(columnName)
                    
                    // Store raw value - use the appropriate accessor based on the column type
                    var rawValue: Any? = nil
                    var processedValue: Any? = nil
                    
                    if let sqliteColumn = sqliteColumn {
                        // SQLite NIO provides different accessors for different types
                        if let stringValue = sqliteColumn.string {
                            rawValue = stringValue
                            processedValue = stringValue
                        } else if let intValue = sqliteColumn.integer {
                            rawValue = intValue
                            processedValue = Int(intValue)
                        } else if let doubleValue = sqliteColumn.double {
                            rawValue = doubleValue
                            processedValue = doubleValue
                        } else if let blobValue = sqliteColumn.blob {
                            rawValue = blobValue
                            processedValue = blobValue
                        } else {
                            // NULL value
                            rawValue = nil
                            processedValue = nil
                        }
                    }
                    
                    rawRowData[columnName] = rawValue
                    
                    // Convert to QueryRowInfo
                    processedRowData[columnName] = QueryRowInfo(
                        value: processedValue,
                        dataType: column.dataType,
                        format: nil
                    )
                }
                
                convertedRows.append(processedRowData)
                rawRows.append(rawRowData)
            }
            
            return QueryResult(
                columns: queryColumns,
                rows: convertedRows,
                totalCount: convertedRows.count,
                rawRows: rawRows
            )
        } catch {
            throw DatabaseError.operationFailed(error.localizedDescription)
        }
    }
    
    func createDocument(in collectionName: String, document: [String: Any]) async throws {
        let connection = try await ensureConnected()
        let sanitizedTableName = try validateAndSanitizeIdentifier(collectionName)
        
        guard !document.isEmpty else {
            throw DatabaseError.operationFailed("Cannot insert an empty document.")
        }
        
        do {
            let sortedKeys = document.keys.sorted()
            let columns = sortedKeys.map { "\"\($0)\"" }.joined(separator: ", ")
            let placeholders = Array(repeating: "?", count: sortedKeys.count).joined(separator: ", ")
            
            let queryString = "INSERT INTO \(sanitizedTableName) (\(columns)) VALUES (\(placeholders))"
            
            var binds: [SQLiteData] = []
            for key in sortedKeys {
                if let value = document[key] {
                    binds.append(convertToSQLiteData(value))
                } else {
                    binds.append(.null)
                }
            }
            
            let _ = try await connection.query(queryString, binds)
        } catch {
            throw DatabaseError.operationFailed("Failed to create document: \(error.localizedDescription)")
        }
    }
    
    func updateDocument(in collectionName: String, id: Any, data: [String: Any]) async throws {
        let connection = try await ensureConnected()
        let sanitizedTableName = try validateAndSanitizeIdentifier(collectionName)
        
        guard !data.isEmpty else {
            throw DatabaseError.operationFailed("No changes detected to update")
        }
        
        do {
            // Get the primary key column name
            let primaryKeyColumn = try await getPrimaryKeyColumn(for: collectionName) ?? "rowid"
            
            let setClauses = data.keys.map { "\"\($0)\" = ?" }.joined(separator: ", ")
            let queryString = "UPDATE \(sanitizedTableName) SET \(setClauses) WHERE \(primaryKeyColumn) = ?"
            
            var binds: [SQLiteData] = []
            for (_, value) in data {
                binds.append(convertToSQLiteData(value))
            }
            binds.append(convertToSQLiteData(id))
            
            let _ = try await connection.query(queryString, binds)
        } catch {
            throw DatabaseError.operationFailed(error.localizedDescription)
        }
    }
    
    func deleteDocument(in collectionName: String, id: Any) async throws {
        let connection = try await ensureConnected()
        let sanitizedTableName = try validateAndSanitizeIdentifier(collectionName)
        
        do {
            let primaryKeyColumn = try await getPrimaryKeyColumn(for: collectionName) ?? "rowid"
            
            let queryString = "DELETE FROM \(sanitizedTableName) WHERE \(primaryKeyColumn) = ?"
            let binds = [convertToSQLiteData(id)]
            
            let _ = try await connection.query(queryString, binds)
        } catch {
            throw DatabaseError.operationFailed(error.localizedDescription)
        }
    }
    
    func createCollection(named collectionName: String) async throws {
        throw DatabaseError.notImplemented("SQLite create collection not yet implemented")
    }
    
    func renameCollection(from oldName: String, to newName: String) async throws {
        throw DatabaseError.notImplemented("SQLite rename collection not yet implemented")
    }
    
    func getSchema(for collectionName: String) async throws -> DatabaseSchemaResult {
        let connection = try await ensureConnected()
        let sanitizedTableName = try validateAndSanitizeIdentifier(collectionName)
        
        do {
            let rows = try await connection.query("PRAGMA table_info(\(sanitizedTableName))")
            
            // Fetch foreign key information
            let foreignKeyRows = try await connection.query("PRAGMA foreign_key_list(\(sanitizedTableName))")
            var foreignKeyMap: [String: String] = [:]
            var foreignKeyConstraints: [String: ConstraintInfo] = [:]
            
            for fkRow in foreignKeyRows {
                if let fromColumn = fkRow.column("from")?.string,
                   let toTable = fkRow.column("table")?.string,
                   let toColumn = fkRow.column("to")?.string {
                    foreignKeyMap[fromColumn] = "\(toTable)(\(toColumn))"
                    
                    // Create detailed constraint info for foreign key navigation
                    let constraintInfo = ConstraintInfo(
                        name: "FK_\(fromColumn)_\(toTable)_\(toColumn)",
                        type: .foreignKey,
                        columns: [fromColumn],
                        referencedTable: toTable,
                        referencedColumns: [toColumn]
                    )
                    foreignKeyConstraints[fromColumn] = constraintInfo
                }
            }
            
            var schemaInfo: [DatabaseSchemaInfo] = []
            
            for row in rows {
                guard let columnName = row.column("name")?.string,
                      let dataType = row.column("type")?.string,
                      let notNull = row.column("notnull")?.integer,
                      let primaryKey = row.column("pk")?.integer else {
                    continue
                }
                
                let isNullable = notNull == 0 ? "YES" : "NO"
                let defaultValue = row.column("dflt_value")?.string
                let foreignKey = foreignKeyMap[columnName] ?? ""
                
                var constraints: [ConstraintInfo] = []
                if primaryKey == 1 {
                    constraints.append(ConstraintInfo(name: "PRIMARY", type: .primaryKey))
                }
                if let fkConstraint = foreignKeyConstraints[columnName] {
                    constraints.append(fkConstraint)
                }
                
                let schema = DatabaseSchemaInfo(
                    ordinalPosition: Int(row.column("cid")?.integer ?? 0),
                    columnName: columnName,
                    dataType: dataType,
                    formatType: dataType,
                    typeOid: 0, // SQLite doesn't have type OIDs
                    numericPrecision: nil,
                    datetimePrecision: nil,
                    numericScale: nil,
                    dataLength: nil,
                    isNullable: isNullable,
                    check: "",
                    checkConstraint: "",
                    columnDefault: defaultValue,
                    foreignKey: foreignKey,
                    constraints: constraints,
                    comment: nil
                )
                
                schemaInfo.append(schema)
            }
            
            return DatabaseSchemaResult(
                tableName: collectionName,
                schemaName: "main",
                columns: schemaInfo,
                totalCount: schemaInfo.count
            )
        } catch {
            throw DatabaseError.operationFailed("Failed to get schema: \(error.localizedDescription)")
        }
    }
    
    func buildSystemPrompt(for collectionName: String) async throws -> String {
        let currentDate = Date().formatted(.iso8601)
        let schema = await buildSchemaPrompt(for: collectionName)
        
        return """
        You are a SQLite query assistant. Your primary task is to convert natural language user queries into valid SQLite SQL queries.
        
        Core Responsibilities: 
        - Convert the user query into a SQLite SQL query.
        - Return ONLY the SQL query without explanation.
        - Optimize the query for best performance.
        - Support all SQLite operators and query features.
        
        # Database Schema
        The current table schema is:
        \(schema)
        
        # Output Format
        Return ONLY the SQLite SQL query.
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
        AND created_at > datetime('now', '-7 days');
        
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
        WHERE name LIKE '%laptop%' 
        ORDER BY price DESC;
        
        # Notes
        - NEVER provide explanations or ask clarifying questions.
        - NEVER describe what the query does.
        - Use the provided schema to understand available columns and data types.
        - When user input is ambiguous, refer to the schema for proper column names.
        - Use appropriate SQLite operators (=, >, <, IN, LIKE, GLOB, etc.) based on query requirements.
        - Use LIKE for pattern matching.
        - Use proper SQLite date/time functions (datetime(), date(), etc.).
        - Default to SELECT * unless specific columns are mentioned.
        - Include proper semicolon termination.
        - Return the SQL query as plain text only. Do NOT use code blocks, backticks, or any markdown formatting.
        - Only generate SELECT queries. Do not create UPDATE, DELETE, INSERT, or any data-modifying queries.
        
        Current Date: \(currentDate)
        """
    }
    
    // MARK: - Helper Methods
    
    private func parseConnectionString(_ connectionString: String) throws -> String {
        // Check if this is a security-scoped bookmark
        if let (bookmarkData, _) = BookmarkManager.shared.decodeBookmark(connectionString) {
            do {
                // Resolve the bookmark to get URL
                let url = try BookmarkManager.shared.resolveBookmark(bookmarkData)
                
                // Start accessing security-scoped resource (will persist for connection duration)
                if url.startAccessingSecurityScopedResource() {
                    self.securityScopedURL = url // Store for cleanup later
                    return url.path
                } else {
                    throw DatabaseError.configurationError("File access permission expired. Please select the file again using the folder button (📁) to grant fresh access.")
                }
            } catch let error as BookmarkError {
                switch error {
                case .staleBookmark, .accessDenied:
                    throw DatabaseError.configurationError("Cannot access the database file.\n\n→ Go to Edit Connection → Click \"Change\" → Select the file again")
                default:
                    throw DatabaseError.configurationError("File access error: \(error.localizedDescription)\n\n→ Go to Edit Connection → Click \"Change\" → Select the file again")
                }
            } catch {
                throw DatabaseError.configurationError("Cannot access the selected SQLite file.\n\n→ Go to Edit Connection → Click \"Change\" → Select the file again")
            }
        }
        
        // Handle other formats
        if connectionString.hasPrefix("sqlite://") {
            let path = String(connectionString.dropFirst(9)) // Remove "sqlite://"
            return path.isEmpty ? ":memory:" : path
        } else if connectionString.hasPrefix("file:") {
            return String(connectionString.dropFirst(5)) // Remove "file:"
        } else {
            // Assume it's a direct file path
            return connectionString
        }
    }
    
    private func validateAndSanitizeIdentifier(_ identifier: String) throws -> String {
        let trimmed = identifier.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if trimmed.isEmpty {
            throw DatabaseError.configurationError("Identifier cannot be empty")
        }
        
        // SQLite identifiers are case-insensitive and can contain letters, digits, underscores
        let validCharacters = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "_"))
        for char in trimmed.unicodeScalars {
            if !validCharacters.contains(char) {
                throw DatabaseError.configurationError("Identifier contains invalid characters")
            }
        }
        
        return "\"\(trimmed)\""
    }
    
    private func buildWhereClause(from filter: [String: Any]) -> String {
        let filteredDict = filter.filter { key, _ in key != "rawQuery" }
        guard !filteredDict.isEmpty else { return "" }
        
        let conditions = filteredDict.map { key, value in
            if let stringValue = value as? String {
                return "\"\(key)\" = '\(stringValue)'"
            } else if let numberValue = value as? NSNumber {
                return "\"\(key)\" = \(numberValue)"
            } else {
                return "\"\(key)\" = '\(value)'"
            }
        }
        
        return conditions.joined(separator: " AND ")
    }
    
    private func buildOrderByClause(sortBy: String?, ascending: Bool?) -> String {
        guard let sortBy = sortBy, !sortBy.isEmpty else { return "" }
        
        let direction = ascending == false ? "DESC" : "ASC"
        return "ORDER BY \"\(sortBy)\" \(direction)"
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
    
    private func getPrimaryKeyColumn(for tableName: String) async throws -> String? {
        let connection = try await ensureConnected()
        let sanitizedTableName = try validateAndSanitizeIdentifier(tableName)
        
        do {
            let rows = try await connection.query("PRAGMA table_info(\(sanitizedTableName))")
            
            for row in rows {
                if let primaryKey = row.column("pk")?.integer,
                   primaryKey == 1,
                   let columnName = row.column("name")?.string {
                    return "\"\(columnName)\""
                }
            }
            
            return nil
        } catch {
            return nil
        }
    }
    
    private func convertToSQLiteData(_ value: Any) -> SQLiteData {
        if let intValue = value as? Int {
            return .integer(intValue)
        } else if let int64Value = value as? Int64 {
            return .integer(Int(int64Value))
        } else if let doubleValue = value as? Double {
            return .float(doubleValue)
        } else if let floatValue = value as? Float {
            return .float(Double(floatValue))
        } else if let stringValue = value as? String {
            return .text(stringValue)
        } else if let dataValue = value as? Data {
            // Convert Data to ByteBuffer for SQLite NIO
            let allocator = ByteBufferAllocator()
            var buffer = allocator.buffer(capacity: dataValue.count)
            buffer.writeBytes(dataValue)
            return .blob(buffer)
        } else if let boolValue = value as? Bool {
            return .integer(boolValue ? 1 : 0)
        } else {
            return .text(String(describing: value))
        }
    }
}
