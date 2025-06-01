import Foundation

// MARK: - Database Driver Protocol
protocol DatabaseDriver {
    associatedtype Database: DatabaseWrapper
    associatedtype Collection: CollectionWrapper
    associatedtype Document
    associatedtype FormattedDocument
    
    // Connection management
    func connect(to connectionUri: String) async throws -> Database
    func disconnect() async
    func getBuildInfo() async throws -> BuildInfo
    
    // Database operations
    func listDatabases() async throws -> [Database]
    func listCollections() async throws -> [Collection]
    
    // Collection operations
    func getDocumentCount(for collectionName: String, filter: [String: Any]) async throws -> Int
    func findDocuments(in collectionName: String, filter: [String: Any]) async throws -> [FormattedDocument]
    func createDocument(in collectionName: String, database: Database, document: [String: Any]) async throws
    func updateDocument(in collectionName: String, database: Database, id: Any, data: [String: Any]) async throws
    func deleteDocument(in collectionName: String, database: Database, id: Any) async throws
    
    // Collection management
    func createCollection(named collectionName: String) async throws
    func renameCollection(from oldName: String, to newName: String) async throws
}

// MARK: - Build Info Structure
struct BuildInfo {
    let version: String
    let databaseType: DatabaseType
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
