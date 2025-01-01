//
//  mongodb.swift
//  DocumentPlus
//
//  Created by Fauzaan on 1/1/25.
//
import Foundation
import MongoKitten

final class MongoManager {
    static let shared = MongoManager()
    private var database: MongoDatabase?
    
    private init() {}
    
    func connect(connectionString: String = "mongodb://localhost:27017", databaseName: String = "test") async throws {
        // Use the full connection string if database name is included, otherwise append it
        let fullConnectionString = connectionString.contains("/") ?
        connectionString :
        "\(connectionString)/\(databaseName)"
        
        do {
            // Using connect instead of lazyConnect for immediate feedback in client apps
            self.database = try await MongoDatabase.connect(to: fullConnectionString)
            print("Successfully connected to MongoDB")
        } catch {
            print("Error connecting to MongoDB: \(error.localizedDescription)")
            throw error
        }
    }
    
    func getCollections() async throws -> [MongoCollection] {
        guard let database = database else {
            throw MongoError.databaseNotInitialized
        }
        
        return try await database.listCollections()
    }
    
    func getDocuments(from collectionName: String) async throws -> [Document] {
         guard let collection = database?[collectionName] else {
             throw MongoError.collectionNotFound
         }
         
         return try await collection.find().drain()
     }
}
