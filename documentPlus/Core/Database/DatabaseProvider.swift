//
//  DatabaseViewModel.swift
//  DocumentPlus
//
//  Created by Fauzaan on 1/1/25.
//
import Foundation
import MongoKitten
import SwiftUI

@MainActor
final class DatabaseProvider: ObservableObject {
    static let shared = DatabaseProvider()
    
    @Published private(set) var collections: [MongoCollection] = []
    @Published private(set) var databases: [MongoDatabase] = []
    @Published private(set) var error: Error?
    @Published private(set) var isConnected: Bool = false
    
    private let mongoManager: MongoManager = .shared
    
    func setupDatabase(connectionString: String, databaseName: String = "jurifyte") async {
        do {
            try await mongoManager.connect(connectionString: connectionString)
            isConnected = true
        } catch {
            print(error)
            self.error = error
        }
    }
    
    func fetchCollections() async -> [MongoCollection] {
        do {
            self.collections = try await mongoManager.getCollections().sorted { $0.name < $1.name }
        } catch {
            self.error = error
        }
        
        return self.collections
    }
    
    func fetchDatabases() async -> [MongoDatabase] {
        do {
            self.databases = try await mongoManager.getDatabases()
        } catch {
            self.error = error
        }
        
        return self.databases
    }

    func findQueryBuilder(byCollectionName collectionName: String) -> FindQueryBuilder? {
        do {
            return try mongoManager
                .findQueryBuilder(from: collectionName)
        } catch {
            self.error = error
        }
        
        return nil
    }
}
