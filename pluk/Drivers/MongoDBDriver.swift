import Foundation
import MongoKitten
import MongoCore

// MARK: - MongoDB Wrappers
struct MongoDBWrapper: DatabaseWrapper {
    let database: MongoDatabase
    
    var name: String {
        database.name
    }
    var size: String? {
        return nil
    }
    var tableCount: Int? {
        return nil
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
    func getDatabaseMetadata() async throws -> [MongoDBWrapper] {
        throw DatabaseError.notImplemented("MySQL driver not yet implemented")
    }
    
    func findDocuments(in collectionName: String, filter: [String : Any]) async throws -> [QueryResult] {
        throw DatabaseError.notImplemented("MySQL driver not yet implemented")
    }
    
    func buildSystemPrompt(for collectionName: String) async throws -> String {
        throw DatabaseError.notImplemented("MySQL driver not yet implemented")
    }
    
    typealias Database = MongoDBWrapper
    typealias Collection = MongoCollectionWrapper
    
    private var connectedDatabase: MongoDatabase?
    
    func connect(to connectionUri: String) async throws -> MongoDBWrapper {
        let database = try await MongoDatabase.connect(to: connectionUri)
        self.connectedDatabase = database
        return MongoDBWrapper(database: database)
    }
    
    func switchDatabase(to databaseName: String) async throws {
        guard let connectedDatabase = connectedDatabase else {
            throw MongoError.databaseNotInitialized
        }
        
        let newDb = connectedDatabase.pool[databaseName]
        self.connectedDatabase = newDb
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
        return BuildInfo(version: buildInfo.version, databaseType: DatabaseType.mongodb)
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
    
    func getDocumentCount(for collectionName: String, filter: [String: Any]) async throws -> Int {
        guard let mongoDatabase = connectedDatabase else {
            throw MongoError.databaseNotInitialized
        }
        
        let collection = mongoDatabase[collectionName]
        return try await collection.count()
    }
    
    
    func findDocuments(in collectionName: String, filter: [String : Any], skip: Int, limit: Int) async throws -> QueryResult {
        return try await findDocuments(in: collectionName, filter: filter, skip: skip, limit: limit, sortBy: nil, ascending: nil)
    }
    
    func findDocuments(in collectionName: String, filter: [String: Any], skip: Int, limit: Int, sortBy: String?, ascending: Bool?) async throws -> QueryResult {
        guard let mongoDatabase = connectedDatabase else {
            throw MongoError.databaseNotInitialized
        }
        
        let collection = mongoDatabase[collectionName]
        var query = collection.find().skip(skip).limit(limit)
        
        // Add sorting if specified
        if let sortBy = sortBy {
            let sortOrder: Int32 = ascending == false ? -1 : 1
            query = query.sort([sortBy: sortOrder])
        }
        
        var convertedRows: [[String: QueryRowInfo]] = []
        
        for try await document in query {
            let formattedDoc = formatDocument(document)
            let convertedRow = convertFormattedDocumentToRow(formattedDoc)
            
            convertedRows.append(convertedRow)
        }
        
        return QueryResult(
            columns: [],
            rows: convertedRows,
            totalCount: convertedRows.count,
            rawRows: [],
        )
    }
    
    
    
    func createDocument(in collectionName: String, document: [String: Any]) async throws {
        guard let mongoDatabase = connectedDatabase else {
            throw MongoError.databaseNotInitialized
        }
        
        let collection = mongoDatabase[collectionName]
        //        let mongoDocument = try MongoKitten.Document(from: document)
        //        let result = try await collection.insert(mongoDocument)
        //        if result.insertCount == 0 {
        //            throw MongoError.invalidData
        //        }
    }
    
    func updateDocument(in collectionName: String, id: Any, data: [String: Any]) async throws {
        guard let mongoDatabase = connectedDatabase else {
            throw MongoError.databaseNotInitialized
        }
        
        let collection = mongoDatabase[collectionName]
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
    
    func deleteDocument(in collectionName: String, id: Any) async throws {
        guard let mongoDatabase = connectedDatabase else {
            throw MongoError.databaseNotInitialized
        }
        
        let collection = mongoDatabase[collectionName]
        guard let objectId = id as? ObjectId else {
            throw MongoError.invalidData
        }
        
        let filter: MongoKitten.Document = ["_id": objectId]
        try await collection.deleteOne(where: filter)
    }
    
    func createCollection(named collectionName: String) async throws {
        guard let mongoDatabase = connectedDatabase else {
            throw MongoError.databaseNotInitialized
        }
        
        let createCommand: Document = ["create": collectionName]
        
        let connection = try await mongoDatabase.pool.next(for: .basic)
        _ = try await connection.execute(
            createCommand,
            namespace: mongoDatabase.commandNamespace
        )
    }
    
    func renameCollection(from oldName: String, to newName: String) async throws {
        guard let database = connectedDatabase else {
            throw MongoError.databaseNotInitialized
        }
        
        let from = database[oldName]
        //        try await from.rename(to: newName)
    }
    
    func getSchema(for collectionName: String) async throws -> DatabaseSchemaResult {
        throw DatabaseError.notImplemented("MongoDB schema introspection not yet implemented")
    }
    
    // MARK: - Helper Methods
    
    private func convertFormattedDocumentToRow(_ formattedDoc: Document.FormattedDocument) -> [String: QueryRowInfo] {
        var row: [String: QueryRowInfo] = [:]
        
        // Add the document ID
        row["_id"] = QueryRowInfo(value: formattedDoc.id, dataType: "ObjectId", format: nil)
        
        // Convert each formatted field to display value
        for field in formattedDoc.fields {
            if field.key == "_id" {
                // Already handled above
                continue
            }
            
            row[field.key] = QueryRowInfo(value: field.formattedValue, dataType: field.formattedValue.type, format: nil)
        }
        
        return row
    }
    
    private func formatDocument(_ document: Document) -> Document.FormattedDocument {
        guard let id = document["_id"] as? ObjectId else {
            return Document.FormattedDocument(id: "", fields: [], rawDocument: document)
        }
        
        let fields = document.keys.map { key in
            formatField(key: key, value: document[key])
        }
        
        return Document.FormattedDocument(id: id.hexString, fields: fields, rawDocument: document)
    }
    
    private func formatField(key: String, value: Primitive?) -> Document.FormattedDocument.FormattedField {
        let formatted = Document().formatValue(value)
        
        var nestedFields: [Document.FormattedDocument.FormattedField]?
        if let doc = value as? Document {
            nestedFields = doc.keys.map { key in
                formatField(key: key, value: doc[key])
            }
        }
        
        return Document.FormattedDocument.FormattedField(
            key: key,
            formattedValue: formatted,
            rawValue: value ?? "nil",
            nestedFields: nestedFields
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
