//
//  DatabaseViewModel.swift
//  DocumentPlus
//
//  Created by Fauzaan on 1/1/25.
//
import Foundation
import MongoKitten

@MainActor
final class DatabaseViewModel: ObservableObject {
    @Published private(set) var collections: [MongoCollection] = []
    @Published private(set) var currentDocuments: [Document] = []
    @Published private(set) var error: Error?
    
    private let mongoManager: MongoManager
    
    init(mongoManager: MongoManager = .shared) {
        self.mongoManager = mongoManager
    }
    
    func setupDatabase(connectionString: String = "mongodb://localhost:27017/jurifyte", databaseName: String = "jurifyte") {
        Task {
            do {
                try await mongoManager.connect(connectionString: connectionString)
                print("connected")
                await fetchCollections()
            } catch {
                print(error)
                self.error = error
            }
        }
    }
    
    func fetchCollections() async {
        do {
            self.collections = try await mongoManager.getCollections()
        } catch {
            self.error = error
        }
    }
    
    func getDocuments(collectionName: String) async {
        do {
            self.currentDocuments = try await mongoManager.getDocuments(from: collectionName)
        } catch {
            self.error = error
        }
    }
}
