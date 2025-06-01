import Foundation
import MongoKitten
import MongoCore

// MARK: - MongoDB Wrappers
struct MongoDBWrapper: DatabaseWrapper {
    let database: MongoDatabase
    
    var name: String {
        database.name
    }
}

struct MongoCollectionWrapper: CollectionWrapper {
    var id: ObjectIdentifier
    let collection: MongoCollection
    
    var name: String {
        collection.name
    }
    
    // MARK: - Initializers
    init(collection: MongoCollection) {
        self.collection = collection
        self.id = ObjectIdentifier(collection)
    }
    
    // Alternative initializer with explicit ID (if needed)
    init(id: ObjectIdentifier, collection: MongoCollection) {
        self.id = id
        self.collection = collection
    }
    
    // MARK: - Hashable Conformance
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(name)
    }
    
    static func == (lhs: MongoCollectionWrapper, rhs: MongoCollectionWrapper) -> Bool {
        lhs.id == rhs.id && lhs.name == rhs.name
    }
}

// MARK: - MongoDB Driver
class MongoDBDriver: DatabaseDriver {
    typealias Database = MongoDBWrapper
    typealias Collection = MongoCollectionWrapper
    typealias Document = MongoKitten.Document
    
    private var connectedDatabase: MongoDatabase?
    
    func connect(to connectionUri: String) async throws -> MongoDBWrapper {
        let database = try await MongoDatabase.connect(to: connectionUri)
        self.connectedDatabase = database
        return MongoDBWrapper(database: database)
    }
    
    func disconnect() async {
        if let database = connectedDatabase,
           let cluster = database.pool as? MongoCluster {
            await cluster.disconnect()
        }
        connectedDatabase = nil
    }
    
    func getBuildInfo() async throws -> BuildInfo {
        guard let database = connectedDatabase else {
            throw MongoError.databaseNotInitialized
        }
        
        let buildInfo = try await database.getBuildInfo()
        return BuildInfo(version: buildInfo.version, databaseType: "MongoDB")
    }
    
    func listDatabases() async throws -> [MongoDBWrapper] {
        guard let database = connectedDatabase else {
            throw MongoError.databaseNotInitialized
        }
        
        let databases = try await database.pool.listDatabases()
        return databases.map { MongoDBWrapper(database: $0) }
    }
    
    func listCollections() async throws -> [MongoCollectionWrapper] {
        guard let database = connectedDatabase else {
            throw MongoError.databaseNotInitialized
        }
        
        let collections = try await database.listCollections()
        return collections.map { MongoCollectionWrapper(collection: $0) }.sorted { $0.name < $1.name }
    }
    
    func getDocumentCount(for collectionName: String, in database: MongoDBWrapper) async throws -> Int {
        let collection = database.database[collectionName]
        return try await collection.count()
    }
    
    func findDocuments(in collectionName: String, database: MongoDBWrapper, filter: [String: Any]) async throws -> [MongoKitten.Document] {
        let collection = database.database[collectionName]
//        let mongoFilter = try MongoKitten.Document(from: filter)
//        return try await collection.find(mongoFilter).drain()
        return [Document()]
    }
    
    func createDocument(in collectionName: String, database: MongoDBWrapper, document: [String: Any]) async throws {
        let collection = database.database[collectionName]
//        let mongoDocument = try MongoKitten.Document(from: document)
//        let result = try await collection.insert(mongoDocument)
//        if result.insertCount == 0 {
//            throw MongoError.invalidData
//        }
    }
    
    func updateDocument(in collectionName: String, database: MongoDBWrapper, id: Any, data: [String: Any]) async throws {
        let collection = database.database[collectionName]
        guard let objectId = id as? ObjectId else {
            throw MongoError.invalidData
        }
        
        let filter: MongoKitten.Document = ["_id": objectId]
//        let updateDoc = try MongoKitten.Document(from: data)
//        let result = try await collection.updateOne(where: filter, to: updateDoc)
        
//        if result.updatedCount == 0 {
//            throw MongoError.invalidData
//        }
    }
    
    func deleteDocument(in collectionName: String, database: MongoDBWrapper, id: Any) async throws {
        let collection = database.database[collectionName]
        guard let objectId = id as? ObjectId else {
            throw MongoError.invalidData
        }
        
        let filter: MongoKitten.Document = ["_id": objectId]
        try await collection.deleteOne(where: filter)
    }
    
    func createCollection(named collectionName: String, in database: any DatabaseWrapper) async throws {
        guard let mongoDatabase = database as? MongoDBWrapper else {
            throw MongoError.invalidWrapper
        }
        
        let createCommand: Document = ["create": collectionName]
        
        let connection = try await mongoDatabase.database.pool.next(for: .basic)
        _ = try await connection.execute(
            createCommand,
            namespace: mongoDatabase.database.commandNamespace
        )
    }
    
    func renameCollection(from oldName: String, to newName: String, in database: any DatabaseWrapper) async throws {
        guard let mongoDatabase = database as? MongoDBWrapper else {
            throw MongoError.invalidWrapper
        }
        
        let renameCommand: Document = [
            "renameCollection": "\(database.name).\(oldName)",
            "to": "\(database.name).\(newName)"
        ]
        
        let connection = try await mongoDatabase.database.pool.next(for: .basic)
        
        _ = try await connection.execute(
            renameCommand,
            namespace: .administrativeCommand
        )
    }
}

// MARK: - Dictionary to Document Extension
//extension MongoKitten.Document {
//    init(from dictionary: [String: Any]) throws {
//        var doc = MongoKitten.Document()
//        for (key, value) in dictionary {
//            doc[key] = try BSONValue(from: value)
//        }
//        self = doc
//    }
//}
//
//extension BSONValue {
//    init(from value: Any) throws {
//        switch value {
//        case let string as String:
//            self = .string(string)
//        case let int as Int:
//            self = .int32(Int32(int))
//        case let int64 as Int64:
//            self = .int64(int64)
//        case let double as Double:
//            self = .double(double)
//        case let bool as Bool:
//            self = .bool(bool)
//        case let array as [Any]:
//            let bsonArray = try array.map { try BSONValue(from: $0) }
//            self = .array(bsonArray)
//        case let dict as [String: Any]:
//            self = .document(try MongoKitten.Document(from: dict))
//        default:
//            throw MongoError.invalidData
//        }
//    }
//} 
