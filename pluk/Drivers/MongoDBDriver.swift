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
    func buildSystemPrompt(for collectionName: String) async throws -> String {
        throw DatabaseError.notImplemented("MySQL driver not yet implemented")
    }
    
    func findDocuments(in collectionName: String, filter: [String : Any], skip: Int, limit: Int) async throws -> QueryResult {
        throw DatabaseError.notImplemented("MongoDB driver not yet implemented")
    }
    
    typealias Database = MongoDBWrapper
    typealias Collection = MongoCollectionWrapper
    
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
    
    func findDocuments(in collectionName: String, filter: [String: Any]) async throws -> [QueryResult] {
        guard let mongoDatabase = connectedDatabase else {
            throw MongoError.databaseNotInitialized
        }
        
        let collection = mongoDatabase[collectionName]
        
        let documents = try await collection.find().drain()
        let formattedDocs = await formatDocuments(documents, skip: 1, limit: 1)
        return [convertToQueryResult(from: formattedDocs)]
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
    
    // MARK: - Document Formatting and Conversion
    private func convertToQueryResult(from formattedDocs: [MongoKitten.Document.FormattedDocument]) -> QueryResult {
        // Create column info based on the first document's fields, or use default if empty
        var columns: [QueryColumnInfo] = []
        var rows: [[String: Any?]] = []
        var rawRows: [[String: Any?]] = []
        
        if let firstDoc = formattedDocs.first {
            // Extract column info from first document
            for (index, field) in firstDoc.fields.enumerated() {
                columns.append(QueryColumnInfo(
                    name: field.key,
                    dataType: "Mixed", // MongoDB supports mixed types
                    format: nil,
                    index: index
                ))
            }
            
            // Add _id column if not present
            if !columns.contains(where: { $0.name == "_id" }) {
                columns.insert(QueryColumnInfo(
                    name: "_id",
                    dataType: "ObjectId",
                    format: nil,
                    index: 0
                ), at: 0)
            }
        }
        
        // Convert each document to row format
        for doc in formattedDocs {
            var row: [String: Any?] = [:]
            var rawRow: [String: Any?] = [:]
            
            // Add _id field
            row["_id"] = doc.id
            rawRow["_id"] = doc.id
            
            // Add other fields
            for field in doc.fields {
                row[field.key] = field.formattedValue
                rawRow[field.key] = field.rawValue
            }
            
            rows.append(row)
            rawRows.append(rawRow)
        }
        
        return QueryResult(
            columns: columns,
            rows: rows,
            totalCount: formattedDocs.count,
            rawRows: rawRows,
            timestamp: Date()
        )
    }
    
    private func formatDocuments(_ documents: [Document], skip: Int, limit: Int) async -> [MongoKitten.Document.FormattedDocument] {
        let chunkSize = 10
        var formattedDocs: [MongoKitten.Document.FormattedDocument] = []
        
        for chunk in stride(from: 0, to: documents.count, by: chunkSize) {
            let end = min(chunk + chunkSize, documents.count)
            let documentChunk = Array(documents[chunk..<end])
            
            let formattedChunk = documentChunk.map { document in
                formatDocument(document)
            }
            
            formattedDocs.append(contentsOf: formattedChunk)
            await Task.yield()
        }
        
        return formattedDocs
    }
    
    private func formatDocument(_ document: Document) -> MongoKitten.Document.FormattedDocument {
        guard let id = document["_id"] as? ObjectId else {
            return MongoKitten.Document.FormattedDocument(id: "", fields: [], rawDocument: document)
        }
        
        let fields = document.keys.map { key in
            formatField(key: key, value: document[key])
        }
        
        return MongoKitten.Document.FormattedDocument(id: id.hexString, fields: fields, rawDocument: document)
    }
    
    private func formatField(key: String, value: Primitive?) -> MongoKitten.Document.FormattedDocument.FormattedField {
        let formatted = Document().formatValue(value)
        
        var nestedFields: [MongoKitten.Document.FormattedDocument.FormattedField]?
        if let doc = value as? Document {
            nestedFields = doc.keys.map { key in
                formatField(key: key, value: doc[key])
            }
        }
        
        return MongoKitten.Document.FormattedDocument.FormattedField(
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
