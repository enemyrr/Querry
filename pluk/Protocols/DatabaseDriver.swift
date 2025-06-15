import Foundation

// MARK: - Unified Query Result Types
struct QueryColumnInfo {
    let name: String
    let dataType: String
    let format: String?
    let index: Int
}

struct QueryResult {
    let columns: [QueryColumnInfo]
    let rows: [[String: Any?]]
    let totalCount: Int
    let rawRows: [[String: Any?]]
    let timestamp: Date
    
    // Convenience computed properties
    var columnNames: [String] {
        return columns.map { $0.name }
    }
    
    var columnCount: Int {
        return columns.count
    }
    
    // Get specific column info by name
    func column(named name: String) -> QueryColumnInfo? {
        return columns.first { $0.name == name }
    }
    
    // Get column info by index
    func column(at index: Int) -> QueryColumnInfo? {
        guard index >= 0 && index < columns.count else { return nil }
        return columns[index]
    }
    
    // Get value from row by column name
    func value(row: Int, column: String) -> Any? {
        guard row < rows.count else { return nil }
        return rows[row][column] ?? nil
    }
    
    // Get raw value from row by column name (for lazy decoding)
    func rawValue(row: Int, column: String) -> Any? {
        guard row < rawRows.count else { return nil }
        return rawRows[row][column] ?? nil
    }
    
    // Get raw cell for lazy decoding - compatible with PostgresCell usage
    func rawCell(row: Int, column: String) -> Any? {
        guard row < rawRows.count else { return nil }
        return rawRows[row][column] ?? nil
    }
}

// MARK: - Database Driver Protocol
protocol DatabaseDriver {
    associatedtype Database: DatabaseWrapper
    associatedtype Collection: CollectionWrapper
    
    // Connection management
    func connect(to connectionUri: String) async throws -> Database
    func disconnect() async
    func getBuildInfo() async throws -> BuildInfo
    
    // Database operations
    func listDatabases() async throws -> [Database]
    func listCollections() async throws -> [Collection]
    
    // Collection operations
    func getDocumentCount(for collectionName: String, filter: [String: Any]) async throws -> Int
    func findDocuments(in collectionName: String, filter: [String: Any]) async throws -> [QueryResult]
    func findDocuments(in collectionName: String, filter: [String: Any], skip: Int, limit: Int) async throws -> QueryResult
    func createDocument(in collectionName: String, database: Database, document: [String: Any]) async throws
    func updateDocument(in collectionName: String, database: Database, id: Any, data: [String: Any]) async throws
    func deleteDocument(in collectionName: String, database: Database, id: Any) async throws
    
    func getSchema(for collectionName: String) async throws -> DatabaseSchemaResult
    
    // Collection management
    func createCollection(named collectionName: String) async throws
    func renameCollection(from oldName: String, to newName: String) async throws
    
    // AI Functions
    func buildSystemPrompt(for collectionName: String) async throws -> String
}

// MARK: - Build Info Structure
struct BuildInfo {
    let version: String
    let databaseType: DatabaseType
}

// MARK: - Schema Information Structures
struct DatabaseSchemaInfo {
    let ordinalPosition: Int?
    let columnName: String
    let dataType: String
    let formatType: String?
    let numericPrecision: Int?
    let datetimePrecision: Int?
    let numericScale: Int?
    let dataLength: Int?
    let isNullable: String
    let check: String
    let checkConstraint: String
    let columnDefault: String?
    let foreignKey: String
    let comment: String?
    
    init(
        ordinalPosition: Int? = nil,
        columnName: String,
        dataType: String,
        formatType: String? = nil,
        numericPrecision: Int? = nil,
        datetimePrecision: Int? = nil,
        numericScale: Int? = nil,
        dataLength: Int? = nil,
        isNullable: String = "YES",
        check: String = "",
        checkConstraint: String = "",
        columnDefault: String? = nil,
        foreignKey: String = "",
        comment: String? = nil
    ) {
        self.ordinalPosition = ordinalPosition
        self.columnName = columnName
        self.dataType = dataType
        self.formatType = formatType
        self.numericPrecision = numericPrecision
        self.datetimePrecision = datetimePrecision
        self.numericScale = numericScale
        self.dataLength = dataLength
        self.isNullable = isNullable
        self.check = check
        self.checkConstraint = checkConstraint
        self.columnDefault = columnDefault
        self.foreignKey = foreignKey
        self.comment = comment
    }
}

struct DatabaseSchemaResult {
    let tableName: String
    let schemaName: String
    let columns: [DatabaseSchemaInfo]
    let totalCount: Int
    
    var columnCount: Int {
        return columns.count
    }
    
    // Get specific column info by name
    func column(named name: String) -> DatabaseSchemaInfo? {
        return columns.first { $0.columnName == name }
    }
    
    // Get columns by data type
    func columns(ofType dataType: String) -> [DatabaseSchemaInfo] {
        return columns.filter { $0.dataType == dataType }
    }
    
    // Get nullable columns
    var nullableColumns: [DatabaseSchemaInfo] {
        return columns.filter { $0.isNullable == "YES" }
    }
    
    // Get non-nullable columns
    var nonNullableColumns: [DatabaseSchemaInfo] {
        return columns.filter { $0.isNullable == "NO" }
    }
    
    // Get columns with defaults
    var columnsWithDefaults: [DatabaseSchemaInfo] {
        return columns.filter { $0.columnDefault != nil }
    }
    
    var hashValue: Int {
         var hasher = Hasher()
         for column in columns {
             hasher.combine(column.columnName)
             hasher.combine(column.dataType)
             // Add other relevant column properties if needed
         }
         return hasher.finalize()
     }
}

// MARK: - Generic Database Wrapper
protocol DatabaseWrapper {
    var name: String { get }
}

// MARK: - Generic Collection Wrapper
protocol CollectionWrapper: Identifiable {
    var name: String { get }
}

// MARK: - Database Driver Factory
class DatabaseDriverFactory {
    static func createDriver(for databaseType: DatabaseType) -> any DatabaseDriver {
        switch databaseType {
        case .mongodb:
            return MongoDBDriver()
        case .postgres, .supabase, .neon:
            return PostgreSQLDriver()
        case .mysql:
            return MySQLDriver()
        case .mariadb:
            return MariaDBDriver()
        }
    }
} 

extension DatabaseDriver {
    func performOperation<T>(
        with database: any DatabaseWrapper,
        operation: (Database) async throws -> T
    ) async throws -> T {
        guard let typedDatabase = database as? Database else {
            throw DatabaseError.operationFailed("Database type mismatch")
        }
        return try await operation(typedDatabase)
    }
}
