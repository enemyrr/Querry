import Foundation
@preconcurrency import MySQLNIO
import NIOCore
import NIOSSL
import Logging

// MARK: - MySQL Wrappers
struct MySQLDatabaseWrapper: DatabaseWrapper {
    let name: String
    let size: String?
    let tableCount: Int?
}

struct MySQLCollectionWrapper: CollectionWrapper {
    var schema: String?
    
    var id: ObjectIdentifier
    let name: String
    let type: String = "table"
}

// MARK: - MySQL Driver
class MySQLDriver: DatabaseDriver {
    func getInformationSchema() async throws -> [InformationSchema] {
        throw DatabaseError.notImplemented("MySql driver not yet implemented")
    }
    
    private var connection: MySQLConnection?
    private var currentDatabase: String?
    private var eventLoopGroup: EventLoopGroup?
    private var connectionUri: String?
    private let logger = Logger(label: "mysql-driver")
    
    typealias Database = MySQLDatabaseWrapper
    typealias Collection = MySQLCollectionWrapper
    
    deinit {
        // Ensure connection is properly closed before deallocation
        if let connection = connection, !connection.isClosed {
            // Use a detached task to properly close the connection
            Task.detached {
                try? await connection.close().get()
            }
        }
        
        // Clean up event loop group
        if let eventLoopGroup = eventLoopGroup {
            Task.detached {
                try? await eventLoopGroup.shutdownGracefully()
            }
        }
    }
    
    // MARK: - Connection Management
    func connect(to connectionUri: String) async throws -> MySQLDatabaseWrapper {
        self.connectionUri = connectionUri
        return try await establishConnection(with: connectionUri)
    }
    
    private func establishConnection(with connectionUri: String) async throws -> MySQLDatabaseWrapper {
        let connectionInfo = try parseConnectionString(connectionUri)
        let eventLoop = try getEventLoop()
        let sslConfig = parseSSLConfiguration(from: connectionInfo.url)
        
        logger.info("Connecting to MySQL at \(connectionInfo.host):\(connectionInfo.port) (SSL: \(sslConfig.enabled ? "enabled" : "disabled"))")
        
        do {
            self.connection = try await connectToMySQL(
                connectionInfo: connectionInfo,
                sslConfig: sslConfig,
                eventLoop: eventLoop
            )
            
            if !connectionInfo.database.isEmpty {
                self.currentDatabase = connectionInfo.database
            }
            
            logger.info("Successfully connected to MySQL database")
            return MySQLDatabaseWrapper(name: connectionInfo.database, size: nil, tableCount: nil)
            
        } catch {
            logger.error("Failed to connect to MySQL: \(error)")
            throw DatabaseError.connectionFailed("Failed to connect to MySQL at \(connectionInfo.host):\(connectionInfo.port) - \(error.localizedDescription)")
        }
    }
    
    func disconnect() async {
        // Close MySQL connection first
        if let connection = connection {
            do {
                try await connection.close().get()
                logger.info("MySQL connection closed successfully")
            } catch {
                logger.warning("Error closing MySQL connection: \(error)")
            }
        }
        connection = nil
        currentDatabase = nil
        connectionUri = nil
        
        // Clean up event loop group
        if let eventLoopGroup = eventLoopGroup {
            do {
                try await eventLoopGroup.shutdownGracefully()
                logger.info("Event loop group shut down successfully")
            } catch {
                logger.warning("Error shutting down event loop group: \(error)")
            }
            self.eventLoopGroup = nil
        }
    }
    
    func reconnect() async throws {
        guard let connectionUri = self.connectionUri else {
            throw DatabaseError.configurationError("No connection URI stored for reconnection")
        }
        await disconnect()
        _ = try await establishConnection(with: connectionUri)
    }
    
    private func ensureConnected() async throws -> MySQLConnection {
        guard let connection = self.connection else {
            throw DatabaseError.notConnected("Not connected to MySQL database")
        }
        
        if connection.isClosed {
            do {
                guard let connectionUri = self.connectionUri else {
                    throw DatabaseError.configurationError("No connection URI stored for reconnection")
                }
                
                _ = try await establishConnection(with: connectionUri)
                return self.connection!
            } catch {
                throw DatabaseError.connectionFailed("Failed to reconnect to MySQL database: \(error.localizedDescription)")
            }
        }
        
        return connection
    }
    
    func getBuildInfo() async throws -> BuildInfo {
        let connection = try await ensureConnected()
        
        let rows = try await connection.simpleQuery("SELECT VERSION() as version").get()
        var version = "Unknown"
        for row in rows {
            if let versionValue = row.column("version")?.string {
                version = versionValue
                break
            }
        }
        
        return BuildInfo(version: version, databaseType: .mysql)
    }
    
    func switchDatabase(to databaseName: String) async throws {
        let connection = try await ensureConnected()
        
        _ = try await connection.simpleQuery("USE \(databaseName)").get()
        self.currentDatabase = databaseName
    }
    
    // MARK: - Database Operations
    
    func getDatabaseMetadata() async throws -> [MySQLDatabaseWrapper] {
        return try await listDatabases()
    }
    
    func listDatabases() async throws -> [MySQLDatabaseWrapper] {
        let connection = try await ensureConnected()
        
        let rows = try await connection.simpleQuery("SHOW DATABASES").get()
        var databases: [MySQLDatabaseWrapper] = []
        
        for row in rows {
            if let dbName = row.column("Database")?.string {
                // Get table count for each database
                let tableCountRows = try await connection.simpleQuery("""
                    SELECT COUNT(*) as table_count 
                    FROM information_schema.tables 
                    WHERE table_schema = '\(dbName)'
                """).get()
                var tableCount: Int? = nil
                for countRow in tableCountRows {
                    tableCount = countRow.column("table_count")?.int
                    break
                }
                
                databases.append(MySQLDatabaseWrapper(
                    name: dbName,
                    size: nil, // MySQL doesn't easily provide database size
                    tableCount: tableCount
                ))
            }
        }
        
        return databases
    }
    
    func listCollections(schema: String? = nil) async throws -> [MySQLCollectionWrapper] {
        let connection = try await ensureConnected()
        
        guard let database = currentDatabase else {
            throw DatabaseError.noDatabaseSelected("No database selected")
        }
        
        let rows = try await connection.simpleQuery("""
            SELECT table_name 
            FROM information_schema.tables 
            WHERE table_schema = '\(database)'
        """).get()
        
        var collections: [MySQLCollectionWrapper] = []
        for row in rows {
            if let tableName = row.column("TABLE_NAME")?.string {
                collections.append(MySQLCollectionWrapper(
                    id: ObjectIdentifier(NSString(string: tableName)),
                    name: tableName
                ))
            }
        }
        
        return collections
    }
    
    // MARK: - Document Operations
    
    func getDocumentCount(for collectionName: String, filter: [String: Any]) async throws -> Int {
        let connection = try await ensureConnected()
        
        let query: String
        
        // Check if filter contains filter conditions (advanced filtering)
        if let filterConditions = filter["filterConditions"] as? [FilterCondition], !filterConditions.isEmpty {
            let whereClause = buildWhereClause(from: filterConditions)
            query = "SELECT COUNT(*) as count FROM `\(collectionName)`\(whereClause)"
        } else {
            let whereClause = buildWhereClause(from: filter)
            query = "SELECT COUNT(*) as count FROM `\(collectionName)`\(whereClause)"
        }
        
        let rows = try await connection.simpleQuery(query).get()
        for row in rows {
            if let count = row.column("count")?.int {
                return count
            }
        }
        return 0
    }
    
    func findDocuments(in collectionName: String, filter: [String: Any]) async throws -> [QueryResult] {
        let result = try await findDocuments(in: collectionName, filter: filter, skip: 0, limit: 100)
        return [result]
    }
    
    func findDocuments(in collectionName: String, filter: [String: Any], skip: Int, limit: Int) async throws -> QueryResult {
        return try await findDocuments(in: collectionName, databaseSchema: nil, filter: filter, skip: skip, limit: limit, sortBy: nil, ascending: nil)
    }
    
    func findDocuments(in collectionName: String, databaseSchema: String?, filter: [String: Any], skip: Int, limit: Int, sortBy: String?, ascending: Bool?) async throws -> QueryResult {
        let connection = try await ensureConnected()
        
        let query: String
        
        // Check if filter contains a raw query
        if let rawQuery = filter["rawQuery"] as? String, !rawQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            // Use the raw query directly
            query = rawQuery
        } else if let filterConditions = filter["filterConditions"] as? [FilterCondition], !filterConditions.isEmpty {
            // Use advanced filtering with filter conditions
            let baseQuery = generateFilterQuery(from: filterConditions, tableName: collectionName)
            let orderClause = buildOrderClause(sortBy: sortBy, ascending: ascending)
            let limitClause = " LIMIT \(limit) OFFSET \(skip)"
            query = "\(baseQuery)\(orderClause)\(limitClause)"
        } else {
            // Build standard query with WHERE clause
            let whereClause = buildWhereClause(from: filter)
            let orderClause = buildOrderClause(sortBy: sortBy, ascending: ascending)
            let limitClause = " LIMIT \(limit) OFFSET \(skip)"
            
            query = "SELECT * FROM `\(collectionName)`\(whereClause)\(orderClause)\(limitClause)"
        }
        
        logger.info("Executing MySQL query: \(query)")
        
        let rows = try await connection.simpleQuery(query).get()
        
        logger.info("MySQL query returned \(rows.count) rows")
        
        // Get column information
        let columns = try await getColumnInfo(for: collectionName)
        
        // Convert rows to the expected format
        var queryRows: [[String: QueryRowInfo]] = []
        var rawRows: [[String: Any?]] = []
        
        for row in rows {
            var queryRow: [String: QueryRowInfo] = [:]
            var rawRow: [String: Any?] = [:]
            
            for column in columns {
                let columnName = column.name
                if let mysqlData = row.column(columnName) {
                    // Store the raw MySQLData for compatibility with update operations
                    rawRow[columnName] = mysqlData.mysqlData
                    
                    // Convert to QueryRowInfo for processed row
                    do {
                        queryRow[columnName] = try decode(from: mysqlData)
                    } catch {
                        logger.warning("Failed to decode column \(columnName): \(error)")
                        queryRow[columnName] = QueryRowInfo(value: nil, dataType: column.dataType, format: nil)
                    }
                } else {
                    queryRow[columnName] = QueryRowInfo(value: nil, dataType: column.dataType, format: nil)
                    rawRow[columnName] = nil
                }
            }
            
            queryRows.append(queryRow)
            rawRows.append(rawRow)
        }
        
        // Use the actual count of returned rows, not a separate database query
        let totalCount = queryRows.count
        
        return QueryResult(
            columns: columns,
            rows: queryRows,
            totalCount: totalCount,
            rawRows: rawRows
        )
    }
    
    func createDocument(in collectionName: String, databaseSchema: String?, document: [String: Any]) async throws {
        let connection = try await ensureConnected()
        
        let columns = document.keys.map { "`\($0)`" }.joined(separator: ", ")
        let placeholders = document.keys.map { _ in "?" }.joined(separator: ", ")
        let values = Array(document.values)
        
        let query = "INSERT INTO `\(collectionName)` (\(columns)) VALUES (\(placeholders))"
        
        // Use direct parameter array approach
        _ = try await connection.query(query, values.map(convertToMySQLBindable)).get()
    }
    
    func updateDocument(in collectionName: String, databaseSchema: String?, id: Any, data: [String: Any]) async throws {
        let connection = try await ensureConnected()
        
        guard !data.isEmpty else {
            throw DatabaseError.operationFailed("No changes detected to update")
        }
        
        let bindableId = try decodeAndConvertToBindable(id)
        
        // Get the primary key column name for this table
        let primaryKeyColumn = try await getPrimaryKeyColumn(for: collectionName) ?? "id"
        
        let setClauses = data.keys.map { "`\($0)` = ?" }.joined(separator: ", ")
        let values = Array(data.values) + [bindableId]
        
        let query = "UPDATE `\(collectionName)` SET \(setClauses) WHERE `\(primaryKeyColumn)` = ?"
        
        // Use direct parameter array approach
        _ = try await connection.query(query, values.map(convertToMySQLBindable)).get()
    }
    
    func deleteDocument(in collectionName: String, databaseSchema: String?, id: Any) async throws {
        let connection = try await ensureConnected()
        
        do {
            let primaryKeyColumn = try await getPrimaryKeyColumn(for: collectionName) ?? "id"
            let query = "DELETE FROM `\(collectionName)` WHERE `\(primaryKeyColumn)` = ?"
            
            // Use the helper function to decode and convert the id
            let bindableId = try decodeAndConvertToBindable(id)
            _ = try await connection.query(query, [bindableId]).get()
        } catch {
            throw DatabaseError.operationFailed(error.localizedDescription)
        }
    }
    
    func executeRawQuery(_ query: String, databaseSchema: String?) async throws -> QueryResult {
        let connection = try await ensureConnected()
        
        do {
            let results = try await connection.simpleQuery(query).get()
            
            // Process results similar to findDocuments method
            var queryColumns: [QueryColumnInfo] = []
            var convertedRows: [[String: QueryRowInfo]] = []
            var convertedRawRows: [[String: Any?]] = []
            var columnsInitialized = false
            
            // Process each row and extract column info from first row
            for row in results {
                // Extract column information from first row
                if !columnsInitialized {
                    var columnIndex = 0
                    // Get column names from the column definitions
                    for columnDef in row.columnDefinitions {
                        let cleanedDataType = String(describing: columnDef.columnType)
                            .replacingOccurrences(of: "MYSQL_TYPE_", with: "")
                            .lowercased()
                        
                        queryColumns.append(QueryColumnInfo(
                            name: columnDef.name,
                            dataType: cleanedDataType,
                            format: nil,
                            index: columnIndex
                        ))
                        columnIndex += 1
                    }
                    columnsInitialized = true
                }
                
                var processedRowData: [String: QueryRowInfo] = [:]
                var rawRowData: [String: Any?] = [:]
                
                for column in queryColumns {
                    let columnName = column.name
                    if let mysqlData = row.column(columnName) {
                        // Store the raw MySQLData for compatibility with update operations
                        rawRowData[columnName] = mysqlData
                        
                        // Convert to QueryRowInfo for processed row
                        do {
                            processedRowData[columnName] = try decode(from: mysqlData)
                        } catch {
                            logger.warning("Failed to decode column \(columnName): \(error)")
                            processedRowData[columnName] = QueryRowInfo(value: nil, dataType: column.dataType, format: nil)
                        }
                    } else {
                        processedRowData[columnName] = QueryRowInfo(value: nil, dataType: column.dataType, format: nil)
                        rawRowData[columnName] = nil
                    }
                }
                
                convertedRows.append(processedRowData)
                convertedRawRows.append(rawRowData)
            }
            
            return QueryResult(
                columns: queryColumns,
                rows: convertedRows,
                totalCount: convertedRows.count,
                rawRows: convertedRawRows
            )
            
        } catch {
            throw DatabaseError.operationFailed("Failed to execute raw query: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Collection Management
    
    func createCollection(named collectionName: String) async throws {
        throw DatabaseError.notImplemented("Support for creating tables not yet implemented")
//        let connection = try await ensureConnected()
//        
//        let query = """
//            CREATE TABLE `\(collectionName)` (
//                id INT AUTO_INCREMENT PRIMARY KEY,
//                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
//                updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
//            )
//        """
//        
//        _ = try await connection.simpleQuery(query).get()
    }
    
    func renameCollection(databaseSchema: String?, from oldName: String, to newName: String) async throws {
        let connection = try await ensureConnected()
        
        let query = "RENAME TABLE `\(oldName)` TO `\(newName)`"
        
        _ = try await connection.simpleQuery(query).get()
    }
    
    func deleteCollection(named collectionName: String, databaseSchema: String?) async throws {
        let connection = try await ensureConnected()
        
        let query = "DROP TABLE `\(collectionName)`"
        
        _ = try await connection.simpleQuery(query).get()
    }
    
    func getSchema(for collectionName: String, schema: String?) async throws -> DatabaseSchemaResult {
        let connection = try await ensureConnected()
        
        guard let database = currentDatabase else {
            throw DatabaseError.noDatabaseSelected("No database selected")
        }
        
        let rows = try await connection.simpleQuery("""
            SELECT 
                c.ORDINAL_POSITION,
                c.COLUMN_NAME,
                c.DATA_TYPE,
                c.COLUMN_TYPE,
                c.IS_NULLABLE,
                c.COLUMN_DEFAULT,
                c.COLUMN_COMMENT,
                -- Foreign key constraint information
                fk.CONSTRAINT_NAME,
                fk.REFERENCED_TABLE_SCHEMA,
                fk.REFERENCED_TABLE_NAME,
                fk.REFERENCED_COLUMN_NAME,
                fk.UPDATE_RULE,
                fk.DELETE_RULE
            FROM information_schema.COLUMNS c
            LEFT JOIN (
                SELECT DISTINCT
                    kcu.CONSTRAINT_NAME,
                    kcu.COLUMN_NAME,
                    kcu.REFERENCED_TABLE_SCHEMA,
                    kcu.REFERENCED_TABLE_NAME,
                    kcu.REFERENCED_COLUMN_NAME,
                    rc.UPDATE_RULE,
                    rc.DELETE_RULE
                FROM information_schema.KEY_COLUMN_USAGE kcu
                JOIN information_schema.REFERENTIAL_CONSTRAINTS rc 
                    ON kcu.CONSTRAINT_NAME = rc.CONSTRAINT_NAME 
                    AND kcu.CONSTRAINT_SCHEMA = rc.CONSTRAINT_SCHEMA
                WHERE kcu.TABLE_SCHEMA = '\(database)' 
                    AND kcu.TABLE_NAME = '\(collectionName)'
                    AND kcu.REFERENCED_TABLE_NAME IS NOT NULL
            ) fk ON fk.COLUMN_NAME = c.COLUMN_NAME
            WHERE c.TABLE_SCHEMA = '\(database)' AND c.TABLE_NAME = '\(collectionName)'
            ORDER BY c.ORDINAL_POSITION
        """).get()
        
        var columns: [DatabaseSchemaInfo] = []
        
        for row in rows {
            let columnName = row.column("COLUMN_NAME")?.string ?? ""
            let dataType = row.column("DATA_TYPE")?.string ?? ""
            let columnType = row.column("COLUMN_TYPE")?.string ?? ""
            let ordinalPosition = row.column("ORDINAL_POSITION")?.int
            let isNullable = row.column("IS_NULLABLE")?.string ?? "YES"
            let columnDefault = row.column("COLUMN_DEFAULT")?.string
            let comment = row.column("COLUMN_COMMENT")?.string
            
            // Foreign key information
            let constraintName = row.column("CONSTRAINT_NAME")?.string
            let referencedSchema = row.column("REFERENCED_TABLE_SCHEMA")?.string
            let referencedTable = row.column("REFERENCED_TABLE_NAME")?.string
            let referencedColumn = row.column("REFERENCED_COLUMN_NAME")?.string
            let updateRule = row.column("UPDATE_RULE")?.string
            let deleteRule = row.column("DELETE_RULE")?.string
            
            // Build constraint info if foreign key data exists
            var columnConstraints: [ConstraintInfo] = []
            var foreignKey = ""
            
            if let constraintName = constraintName,
               let referencedSchema = referencedSchema,
               let referencedTable = referencedTable,
               let referencedColumn = referencedColumn {
                
                let constraintInfo = ConstraintInfo(
                    oid: 0,
                    name: constraintName,
                    type: .foreignKey,
                    columns: [columnName],
                    isDeferrable: false,
                    isDeferred: false,
                    definition: nil,
                    description: nil,
                    referencedSchema: referencedSchema,
                    referencedTable: referencedTable,
                    referencedColumns: [referencedColumn],
                    onUpdate: updateRule?.lowercased() ?? "no action",
                    onDelete: deleteRule?.lowercased() ?? "no action",
                    extensionName: nil
                )
                
                columnConstraints.append(constraintInfo)
                foreignKey = constraintName
            }
            
            columns.append(DatabaseSchemaInfo(
                ordinalPosition: ordinalPosition,
                columnName: columnName,
                dataType: dataType,
                formatType: columnType,
                typeOid: 0, // MySQL doesn't use OIDs like PostgreSQL
                numericPrecision: 0,
                datetimePrecision: 0,
                numericScale: 0,
                dataLength: 0,
                isNullable: isNullable,
                check: "",
                checkConstraint: "",
                columnDefault: columnDefault,
                foreignKey: foreignKey,
                constraints: columnConstraints,
                comment: comment
            ))
        }
        return DatabaseSchemaResult(
            tableName: collectionName,
            schemaName: database,
            columns: columns,
            totalCount: columns.count
        )
    }
    
    // MARK: - AI Functions
    
    func buildAICommandPromptSystemPrompt(_ message: String) async throws -> String {
        let currentDate = Date().formatted(.iso8601)
        
        // Get all available tables/collections with error handling
        var tablesList = ""
        do {
            let collections = try await listCollections(schema: nil)
            tablesList = collections.map { "- \($0.name) (\($0.type))" }.joined(separator: "\n")
        } catch {
            tablesList = "No tables available (connection error)"
        }
        
        return """
        You are a MySQL query assistant designed for CMD+K quick actions. You help users generate, modify, or fix SQL queries based on their natural language requests.

        ## Core Responsibilities
        - Generate new MySQL SQL queries from natural language descriptions
        - Modify existing queries based on user requests
        - Fix syntax errors or logical issues in existing queries
        - Provide clear, optimized, and readable SQL code

        ## Available Tables
        The database contains the following tables:
        \(tablesList)

        ## Context Handling
        You will receive one of these contexts:
        1. **New Query Request**: User asks to create a query from scratch
        2. **Query Modification**: User provides existing query and asks for changes
        3. **Query Fix**: User provides broken query and asks for fixes

        ## Output Format Rules

        ### For New Queries:
        - Start with a comment describing what the query does
        - Follow with the SQL query
        - Use proper formatting and indentation
        - Include semicolon termination

        ### For Query Modifications:
        - Return only the modified SQL query
        - No commentary unless the change is complex
        - Maintain original formatting style when possible

        ### For Query Fixes:
        - Return only the corrected SQL query
        - No explanation of what was wrong

        ## Examples

        **Example 1 - New Query:**
        **Input:** "Get all active users from the last month"
        **Output:**
        ```sql
        -- Retrieve all active users who were created in the last 30 days
        SELECT * FROM users 
        WHERE status = 'active' 
        AND created_at >= DATE_SUB(CURDATE(), INTERVAL 30 DAY);
        ```

        **Example 2 - Query Modification:**
        **Input:** "Add ordering by name to this query: SELECT * FROM products WHERE price > 100;"
        **Output:**
        ```sql
        SELECT * FROM products 
        WHERE price > 100 
        ORDER BY name ASC;
        ```

        **Example 3 - Query Fix:**
        **Input:** "Fix this query: SELECT * FROM user WHERE age > 30 AND"
        **Output:**
        ```sql
        SELECT * FROM users WHERE age > 30;
        ```

        ## Query Guidelines
        - Use table names from the provided list
        - Default to SELECT * unless specific columns mentioned
        - Use appropriate MySQL operators (=, >, <, IN, LIKE, etc.)
        - Use LIKE for case-insensitive string matching
        - Use proper MySQL date/time functions (CURDATE(), DATE_SUB(), INTERVAL, etc.)
        - Optimize for readability and performance
        - Handle ambiguous requests by making reasonable assumptions based on available tables

        ## Formatting Rules
        - Return SQL as plain text (no markdown code blocks)
        - Use consistent indentation (2 or 4 spaces)
        - Capitalize SQL keywords (SELECT, FROM, WHERE, etc.)
        - Use single quotes for string literals
        - Include proper semicolon termination
        - For multi-line queries, break at logical points (SELECT, FROM, WHERE, ORDER BY, etc.)

        ## Error Handling
        - If a table name doesn't exist in the list, suggest the closest match
        - If the request is unclear, make reasonable assumptions
        - For complex requests requiring schema knowledge, use common column names (id, name, created_at, updated_at, status, etc.)

        IMPORTANT: If you need detailed schema information about specific tables, use the get_table_schema tool.
        
        Current Date: \(currentDate)
        """
    }
    
    func buildSystemPrompt(for collectionName: String, databaseSchema: String?) async throws -> String {
        let currentDate = Date().formatted(.iso8601)
        
        let schema = await buildSchemaPrompt(for: collectionName)
        
        return """
        You are a MySQL query assistant. Your primary task is to convert natural language user queries into valid MySQL SQL queries.
        
        Core Responsibilities: 
        - Convert the user query into a MySQL SQL query.
        - Return ONLY the SQL query without explanation.
        - Optimize the query for best performance.
        - Support all MySQL operators and query features.
        
        # Database Schema
        The current table schema is:
        \(schema)
        
        # Output Format
        Return ONLY the MySQL SQL query.
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
        AND created_at > DATE_SUB(CURDATE(), INTERVAL 7 DAY);
        
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
        - Use appropriate MySQL operators (=, >, <, IN, LIKE, etc.) based on query requirements.
        - Use LIKE for case-insensitive string matching (MySQL is case-insensitive by default).
        - Use proper MySQL date/time functions (CURDATE(), DATE_SUB(), INTERVAL, etc.).
        - Default to SELECT * unless specific columns are mentioned.
        - Include proper semicolon termination.
        - Return the SQL query as plain text only. Do NOT use code blocks, backticks, or any markdown formatting.
        - Only generate SELECT queries. Do not create UPDATE, DELETE, INSERT, or any data-modifying queries.
        
        Current Date: \(currentDate)
        """
    }
    
    private func buildSchemaPrompt(for collectionName: String) async -> String {
        do {
            let schemaResult = try await getSchema(for: collectionName, schema: nil)
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
    
    // MARK: - Connection Helper Methods
    
    private struct ConnectionInfo {
        let host: String
        let port: Int
        let username: String
        let password: String?
        let database: String
        let url: URL
    }
    
    private struct SSLConfiguration {
        let enabled: Bool
        let required: Bool
        let tlsConfiguration: TLSConfiguration?
    }
    
    private func parseConnectionString(_ connectionUri: String) throws -> ConnectionInfo {
        guard let url = URL(string: connectionUri) else {
            throw DatabaseError.invalidConnectionString("Invalid MySQL connection URI")
        }
        
        let host = url.host ?? "localhost"
        let port = url.port ?? 3306
        let username = url.user ?? "root"
        let password = url.password?.isEmpty == false ? url.password : nil
        let database = String(url.path.dropFirst()) // Remove leading "/"
        
        return ConnectionInfo(
            host: host,
            port: port,
            username: username,
            password: password,
            database: database,
            url: url
        )
    }
    
    private func getEventLoop() throws -> EventLoop {
        if eventLoopGroup == nil {
            eventLoopGroup = MultiThreadedEventLoopGroup(numberOfThreads: 1)
        }
        
        guard let eventLoop = eventLoopGroup?.next() else {
            throw DatabaseError.connectionFailed("Failed to create event loop")
        }
        
        return eventLoop
    }
    
    private func parseSSLConfiguration(from url: URL) -> SSLConfiguration {
        var enabled = false
        var required = false
        var tlsConfiguration: TLSConfiguration? = nil
        
        // Parse SSL mode from query parameters
        if let query = url.query {
            let queryItems = URLComponents(string: "?\(query)")?.queryItems ?? []
            
            for item in queryItems where item.name.lowercased() == "sslmode" {
                if let value = item.value?.lowercased() {
                    switch value {
                    case "require", "true", "1":
                        enabled = true
                        required = true
                        var config = TLSConfiguration.makeClientConfiguration()
                        config.certificateVerification = .none
                        tlsConfiguration = config
                        
                    case "disable", "false", "0":
                        enabled = false
                        required = false
                        tlsConfiguration = nil
                        
                    case "prefer":
                        enabled = true
                        required = false
                        var config = TLSConfiguration.makeClientConfiguration()
                        config.certificateVerification = .none
                        tlsConfiguration = config
                        
                    default:
                        // Unknown SSL mode, default to prefer (safe fallback)
                        enabled = true
                        required = false
                        var config = TLSConfiguration.makeClientConfiguration()
                        config.certificateVerification = .none
                        tlsConfiguration = config
                    }
                }
                break
            }
        } else {
            // Default: enable SSL for caching_sha2_password compatibility
            enabled = true
            required = false
            var config = TLSConfiguration.makeClientConfiguration()
            config.certificateVerification = .none
            tlsConfiguration = config
        }
        
        return SSLConfiguration(
            enabled: enabled,
            required: required,
            tlsConfiguration: tlsConfiguration
        )
    }
    
    private func connectToMySQL(
        connectionInfo: ConnectionInfo,
        sslConfig: SSLConfiguration,
        eventLoop: EventLoop
    ) async throws -> MySQLConnection {
        
        if sslConfig.enabled {
            // Try SSL connection first
            do {
                return try await performConnection(
                    connectionInfo: connectionInfo,
                    tlsConfiguration: sslConfig.tlsConfiguration,
                    eventLoop: eventLoop
                )
            } catch {
                // If SSL is required, don't fall back
                if sslConfig.required {
                    throw error
                }
                
                // Otherwise, try without SSL
                logger.warning("SSL connection failed, trying without SSL")
                return try await performConnection(
                    connectionInfo: connectionInfo,
                    tlsConfiguration: nil,
                    eventLoop: eventLoop
                )
            }
        } else {
            // Connect without SSL
            return try await performConnection(
                connectionInfo: connectionInfo,
                tlsConfiguration: nil,
                eventLoop: eventLoop
            )
        }
    }
    
    private func performConnection(
        connectionInfo: ConnectionInfo,
        tlsConfiguration: TLSConfiguration?,
        eventLoop: EventLoop
    ) async throws -> MySQLConnection {
        
        // Determine server hostname for SNI (avoid IP addresses)
        let serverHostname: String? = {
            guard tlsConfiguration != nil else { return nil }
            let host = connectionInfo.host
            return (host == "127.0.0.1" || host == "::1" || host.contains(":")) ? nil : host
        }()
        
        return try await MySQLConnection.connect(
            to: .makeAddressResolvingHost(connectionInfo.host, port: connectionInfo.port),
            username: connectionInfo.username,
            database: connectionInfo.database,
            password: connectionInfo.password,
            tlsConfiguration: tlsConfiguration,
            serverHostname: serverHostname,
            logger: logger,
            on: eventLoop
        ).get()
    }
    
    // MARK: - Helper Methods
    
    private func buildWhereClause(from filter: [String: Any]) -> String {
        // Check if this is a filter conditions array (new advanced filtering)
        if let filterConditions = filter["filterConditions"] as? [FilterCondition], !filterConditions.isEmpty {
            return buildWhereClause(from: filterConditions)
        }
        
        // Filter out special keys not meant for WHERE clause building
        let filteredDict = filter.filter { key, _ in 
            !["rawQuery", "filterConditions"].contains(key)
        }
        
        guard !filteredDict.isEmpty else { return "" }
        
        let conditions = filteredDict.map { key, value in
            let escapedKey = "`\(key)`"
            if let stringValue = value as? String {
                let escapedValue = stringValue.replacingOccurrences(of: "'", with: "\\'")
                return "\(escapedKey) = '\(escapedValue)'"
            } else {
                return "\(escapedKey) = \(value)"
            }
        }.joined(separator: " AND ")
        
        return " WHERE \(conditions)"
    }
    
    private func buildOrderClause(sortBy: String?, ascending: Bool?) -> String {
        guard let sortBy = sortBy, !sortBy.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return ""
        }
        let direction = ascending == false ? "DESC" : "ASC"
        return " ORDER BY `\(sortBy)` \(direction)"
    }
    
    private func getColumnInfo(for tableName: String) async throws -> [QueryColumnInfo] {
        let connection = try await ensureConnected()
        
        guard let database = currentDatabase else {
            throw DatabaseError.noDatabaseSelected("No database selected")
        }
        
        let rows = try await connection.simpleQuery("""
            SELECT 
                ORDINAL_POSITION,
                COLUMN_NAME,
                DATA_TYPE
            FROM information_schema.COLUMNS 
            WHERE TABLE_SCHEMA = '\(database)' AND TABLE_NAME = '\(tableName)'
            ORDER BY ORDINAL_POSITION
        """).get()
        
        var columns: [QueryColumnInfo] = []
        
        for (index, row) in rows.enumerated() {
            let columnName = row.column("COLUMN_NAME")?.string ?? ""
            let dataType = row.column("DATA_TYPE")?.string ?? ""
            
            columns.append(QueryColumnInfo(
                name: columnName,
                dataType: dataType,
                format: nil,
                index: index
            ))
        }
        
        return columns
    }
    
    
    // MARK: - Helper method to get primary key column
    private func getPrimaryKeyColumn(for tableName: String, in databaseName: String? = nil) async throws -> String? {
        let connection = try await ensureConnected()
        
        let database = databaseName ?? currentDatabase ?? "mysql"
        
        do {
            let query = """
                SELECT COLUMN_NAME
                FROM information_schema.KEY_COLUMN_USAGE
                WHERE TABLE_SCHEMA = '\(database)'
                AND TABLE_NAME = '\(tableName)'
                AND CONSTRAINT_NAME = 'PRIMARY'
                ORDER BY ORDINAL_POSITION
                LIMIT 1
            """
            
            let rows = try await connection.simpleQuery(query).get()
            
            for row in rows {
                if let columnName = row.column("COLUMN_NAME")?.string {
                    return columnName
                }
            }
            
            return nil
        } catch {
            // If the query fails for any reason (e.g., table not found, permissions), return nil
            return nil
        }
    }
    
    // MARK: - Helper methods for foreign keys
    private func getTableOid(schema: String, table: String) async throws -> Int64? {
        // MySQL doesn't use OIDs, but we can return a hash of the table identifier for compatibility
        let identifier = "\(schema).\(table)"
        return Int64(identifier.hashValue)
    }
    
    private func mapConstraintAction(_ action: String?) -> String {
        guard let action = action else { return "no action" }
        
        switch action.lowercased() {
        case "restrict": return "restrict"
        case "cascade": return "cascade"
        case "set null": return "set null"
        case "set default": return "set default"
        case "no action": return "no action"
        default: return "no action"
        }
    }
    
    // MARK: - MySQL Foreign Key Information
    func getForeignKeyConstraints(for tableName: String, in databaseName: String? = nil) async throws -> [ConstraintInfo] {
        let connection = try await ensureConnected()
        let database = databaseName ?? currentDatabase ?? "mysql"
        
        let rows = try await connection.simpleQuery("""
            SELECT DISTINCT
                kcu.CONSTRAINT_NAME,
                kcu.COLUMN_NAME,
                kcu.REFERENCED_TABLE_SCHEMA,
                kcu.REFERENCED_TABLE_NAME,
                kcu.REFERENCED_COLUMN_NAME,
                rc.UPDATE_RULE,
                rc.DELETE_RULE
            FROM information_schema.KEY_COLUMN_USAGE kcu
            JOIN information_schema.REFERENTIAL_CONSTRAINTS rc 
                ON kcu.CONSTRAINT_NAME = rc.CONSTRAINT_NAME 
                AND kcu.CONSTRAINT_SCHEMA = rc.CONSTRAINT_SCHEMA
            WHERE kcu.TABLE_SCHEMA = '\(database)' 
                AND kcu.TABLE_NAME = '\(tableName)'
                AND kcu.REFERENCED_TABLE_NAME IS NOT NULL
            ORDER BY kcu.CONSTRAINT_NAME, kcu.ORDINAL_POSITION
        """).get()
        
        var constraints: [ConstraintInfo] = []
        
        for row in rows {
            guard let constraintName = row.column("CONSTRAINT_NAME")?.string,
                  let columnName = row.column("COLUMN_NAME")?.string,
                  let referencedSchema = row.column("REFERENCED_TABLE_SCHEMA")?.string,
                  let referencedTable = row.column("REFERENCED_TABLE_NAME")?.string,
                  let referencedColumn = row.column("REFERENCED_COLUMN_NAME")?.string else {
                continue
            }
            
            let updateRule = row.column("UPDATE_RULE")?.string
            let deleteRule = row.column("DELETE_RULE")?.string
            
            let constraintInfo = ConstraintInfo(
                oid: 0,
                name: constraintName,
                type: .foreignKey,
                columns: [columnName],
                isDeferrable: false, // MySQL doesn't support deferrable constraints
                isDeferred: false,
                definition: nil,
                description: "Foreign key constraint on \(columnName) referencing \(referencedSchema).\(referencedTable).\(referencedColumn)",
                referencedSchema: referencedSchema,
                referencedTable: referencedTable,
                referencedColumns: [referencedColumn],
                onUpdate: mapConstraintAction(updateRule),
                onDelete: mapConstraintAction(deleteRule),
                extensionName: nil
            )
            
            constraints.append(constraintInfo)
        }
        
        return constraints
    }
}
