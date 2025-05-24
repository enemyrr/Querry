//
//  DatabaseService.swift
//  Pluk
//
//  Created by Fauzaan on 4/11/25.
//

import Foundation
import MongoKitten
import MongoCore

class DatabaseService {
    private let database: MongoDatabase
    
    init(database: MongoDatabase) {
        self.database = database
    }
    
    // MARK: - Collection Operations
    func listCollections() async throws -> [MongoCollection] {
        let collections = try await database.listCollections()
        return collections.sorted { $0.name < $1.name }
    }
    
    // MARK: - Document Operations
    func getDocumentCount(for collectionName: String) async throws -> Int {
        let collection = database[collectionName]
        return try await collection.count()
    }
    
    func findDocuments(in collectionName: String,
                       filter: Document = [:],
                       skip: Int? = nil,
                       limit: Int? = nil) async throws -> [Document] {
        let collection = database[collectionName]
        var query = collection.find(filter)
        
        if let skip = skip {
            query = query.skip(skip)
        }
        
        if let limit = limit {
            query = query.limit(limit)
        }
        
        var documents: [Document] = []
        for try await document in query {
            documents.append(document)
        }
        return documents
    }
    
    func createDocument(_ document: Document, in collectionName: String) async throws {
        let collection = database[collectionName]
        let result = try await collection.insert(document)
        if result.insertCount == 0 {
            throw MongoError.invalidData
        }
    }
    
    func updateDocument(in collectionName: String,
                        withId id: ObjectId,
                        withData document: Document) async throws {
        let collection = database[collectionName]
        let result = try await collection.updateOne(
            where: ["_id": id],
            to: document
        )
        
        if result.updatedCount == 0 {
            throw MongoError.invalidData
        }
    }
    
    func deleteDocument(from collectionName: String, withId id: ObjectId) async throws {
        let collection = database[collectionName]
        try await collection.deleteOne(where: ["_id": id])
    }
    
    func createCollection(_ collectionName: String) async throws {
        let createCommand: Document = ["create": collectionName]
        
        let connection = try await database.pool.next(for: .basic)
        _ = try await connection.execute(
            createCommand,
            namespace: database.commandNamespace
        )
    }
    
    func renameCollection(from oldName: String, to newName: String) async throws {
        let renameCommand: Document = [
            "renameCollection": "\(database.name).\(oldName)",
            "to": "\(database.name).\(newName)"
        ]
        
        let connection = try await database.pool.next(for: .basic)
        
        _ = try await connection.execute(
            renameCommand,
            namespace: .administrativeCommand
        )
    }
    
    func getBuildInfo() async throws -> BuildInfo {
        return try await database.getBuildInfo()
    }
}
