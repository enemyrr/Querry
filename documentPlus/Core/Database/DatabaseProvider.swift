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
    
    func getDocuments(byCollectionName collectionName: String) async -> [Document] {
        let documents = try? await mongoManager
            .getDocuments(from: collectionName)
        
        // Get first value
        let firstValue = documents?.first?["totalSpent"]
//        print(firstValue.isNegative)
        return documents ?? []
    }
}
