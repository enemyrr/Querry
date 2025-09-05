import Foundation

// MARK: - Unified Query Result Types
struct QueryColumnInfo {
    let name: String
    let dataType: String
    let format: String?
    let index: Int
}

struct QueryRowInfo {
    let value: Any?
    let dataType: String
    let format: String?
}

struct InformationSchema {
    let name: String
}

struct QueryResult {
    let columns: [QueryColumnInfo]
    let rows: [[String: QueryRowInfo]]
    let totalCount: Int
    let rawRows: [[String: Any?]]
    
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
    func value(row: Int, column: String) -> QueryRowInfo? {
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
    func reconnect() async throws
    func getBuildInfo() async throws -> BuildInfo
    func switchDatabase(to databaseName: String) async throws
    
    // Database operations
    func listDatabases() async throws -> [Database]
    func getDatabaseMetadata()  async throws -> [Database]
    func listCollections(schema: String?) async throws -> [Collection]
    
    // Collection operations
    func getDocumentCount(for collectionName: String, filter: [String: Any]) async throws -> Int
    func findDocuments(in collectionName: String, filter: [String: Any]) async throws -> [QueryResult]
    func findDocuments(in collectionName: String, filter: [String: Any], skip: Int, limit: Int) async throws -> QueryResult
    func findDocuments(in collectionName: String,  databaseSchema: String?, filter: [String: Any], skip: Int, limit: Int, sortBy: String?, ascending: Bool?) async throws -> QueryResult
    func createDocument(in collectionName: String, databaseSchema: String?, document: [String: Any]) async throws
    func updateDocument(in collectionName: String, databaseSchema: String?, id: Any, data: [String: Any]) async throws
    func deleteDocument(in collectionName: String, databaseSchema: String?, id: Any) async throws
    
    // Raw Query Execution
    func executeRawQuery(_ query: String, databaseSchema: String?) async throws -> QueryResult
    
    func getSchema(for collectionName: String, schema: String?) async throws -> DatabaseSchemaResult
    func getInformationSchema() async throws -> [InformationSchema]
    
    // Collection management
    func createCollection(named collectionName: String) async throws
    func renameCollection(databaseSchema: String?, from oldName: String, to newName: String) async throws
    func deleteCollection(named collectionName: String, databaseSchema: String?) async throws
    
    // AI Functions
    func buildSystemPrompt(for collectionName: String, databaseSchema: String?) async throws -> String
    func buildAICommandPromptSystemPrompt(_ message: String) async throws -> String
}

// MARK: - Build Info Structure
struct BuildInfo {
    let version: String
    let databaseType: DatabaseType
}

// MARK: - Database Constraint Information Structure
enum ConstraintType: String, Equatable {
    case foreignKey = "f"
    case primaryKey = "p"
    case unique = "u"
    case check = "c"
    case exclusion = "x"
    case trigger = "t"
}

struct ConstraintInfo: Equatable {
    let oid: Int64
    let name: String
    let type: ConstraintType
    let columns: [String]
    let isDeferrable: Bool
    let isDeferred: Bool
    let definition: String?
    let description: String?
    
    // Foreign key specific properties
    let referencedSchema: String?
    let referencedTable: String?
    let referencedColumns: [String]?
    let onUpdate: String?
    let onDelete: String?
    
    // Extension info
    let extensionName: String?
    
    init(
        oid: Int64 = 0,
        name: String,
        type: ConstraintType,
        columns: [String] = [],
        isDeferrable: Bool = false,
        isDeferred: Bool = false,
        definition: String? = nil,
        description: String? = nil,
        referencedSchema: String? = nil,
        referencedTable: String? = nil,
        referencedColumns: [String]? = nil,
        onUpdate: String? = nil,
        onDelete: String? = nil,
        extensionName: String? = nil
    ) {
        self.oid = oid
        self.name = name
        self.type = type
        self.columns = columns
        self.isDeferrable = isDeferrable
        self.isDeferred = isDeferred
        self.definition = definition
        self.description = description
        self.referencedSchema = referencedSchema
        self.referencedTable = referencedTable
        self.referencedColumns = referencedColumns
        self.onUpdate = onUpdate
        self.onDelete = onDelete
        self.extensionName = extensionName
    }
    
    // Convenience property for foreign key navigation
    var isForeignKey: Bool {
        return type == .foreignKey
    }
    
    // Convenience property for primary key identification
    var isPrimaryKey: Bool {
        return type == .primaryKey
    }
}

// MARK: - Schema Information Structures
struct DatabaseSchemaInfo: Equatable {
    let ordinalPosition: Int?
    let columnName: String
    let dataType: String
    let formatType: String
    let typeOid: Int
    let numericPrecision: Int?
    let datetimePrecision: Int?
    let numericScale: Int?
    let dataLength: Int?
    let isNullable: String
    let check: String
    let checkConstraint: String
    let columnDefault: String?
    let foreignKey: String
    let constraints: [ConstraintInfo]
    let comment: String?
    
    init(
        ordinalPosition: Int? = nil,
        columnName: String,
        dataType: String,
        formatType: String,
        typeOid: Int,
        numericPrecision: Int? = nil,
        datetimePrecision: Int? = nil,
        numericScale: Int? = nil,
        dataLength: Int? = nil,
        isNullable: String = "YES",
        check: String = "",
        checkConstraint: String = "",
        columnDefault: String? = nil,
        foreignKey: String = "",
        constraints: [ConstraintInfo] = [],
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
        self.constraints = constraints
        self.comment = comment
        self.typeOid = typeOid
    }
    
    // MARK: - Constraint convenience methods
    
    /// Get all foreign key constraints for this column
    var foreignKeyConstraints: [ConstraintInfo] {
        return constraints.filter { $0.type == .foreignKey }
    }
    
    /// Get the primary foreign key constraint (first one if multiple exist)
    var primaryForeignKeyConstraint: ConstraintInfo? {
        return foreignKeyConstraints.first
    }
    
    /// Get all primary key constraints for this column
    var primaryKeyConstraints: [ConstraintInfo] {
        return constraints.filter { $0.type == .primaryKey }
    }
    
    /// Check if this column has any foreign key constraints
    var hasForeignKey: Bool {
        return !foreignKeyConstraints.isEmpty
    }
    
    /// Check if this column is part of a primary key
    var isPrimaryKey: Bool {
        return !primaryKeyConstraints.isEmpty
    }
    
    /// Get all unique constraints for this column
    var uniqueConstraints: [ConstraintInfo] {
        return constraints.filter { $0.type == .unique }
    }
    
    /// Get all check constraints for this column
    var checkConstraints: [ConstraintInfo] {
        return constraints.filter { $0.type == .check }
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
    var size: String? { get }
    var tableCount: Int? { get }
}

// MARK: - Generic Collection Wrapper
protocol CollectionWrapper: Identifiable {
    var name: String { get }
    var type: String { get }
    var schema: String? { get }
}

// MARK: - Database Driver Factory
class DatabaseDriverFactory {
    static func createDriver(for databaseType: DatabaseType) -> any DatabaseDriver {
        switch databaseType {
        case .mongodb:
            return MongoDBDriver()
        case .postgres, .supabase, .convex:
            return PostgreSQLDriver()
        case .mysql:
            return MySQLDriver()
        case .sqlite:
            return SQLiteDriver()
        }
    }
} 


