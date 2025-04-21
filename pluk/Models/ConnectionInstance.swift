//
//  ConnectionInstance.swift
//  Collection
//
//  Created by Fauzaan on 1/21/25.
//

import Foundation
import MongoKitten
import MongoCore
import SwiftUI
import AIProxy

@Observable class ConnectionInstance: Identifiable {
    let id = UUID()
    let connection: Connection
    private var databaseService: DatabaseService?
    
    var collections: [String: [MongoCollection]] = [:]
    var databases: [MongoDatabase] = []
    var database: MongoDatabase? {
        didSet {
            if let db = database {
                databaseService = DatabaseService(database: db)
                Task { await processDatabaseCollections(previousDatabase: oldValue) }
            }
        }
    }

    // Connection state
    var connectionStatus: ConnectionStatus = .connecting
    var connectionVersion: String?
    var lastError: Error?
    
    var documentViewModels: [UUID: DocumentListModel] = [:]
    
    // UI State
    var tabs: [DatabaseTab] = []
    var selectedTab: DatabaseTab?
    
    init(connection: Connection) {
        self.connection = connection
    }
    
    func viewModel(for tab: DatabaseTab) -> DocumentListModel {
        if let existing = documentViewModels[tab.id] {
            return existing
        } else {
            let newModel = DocumentListModel(instance: self, databaseService: databaseService)
            documentViewModels[tab.id] = newModel
            return newModel
        }
    }
    
    func processDatabaseCollections(previousDatabase: MongoDatabase?) async {
        guard let currentDatabase = database else { return }
        
        let shouldUpdate = previousDatabase == nil || currentDatabase.name != previousDatabase?.name
        
        if shouldUpdate {
            do {
                let collections = try await databaseService?.listCollections()
                self.collections[currentDatabase.name] = collections
                
                let result = try await currentDatabase.pool.listDatabases()
                await MainActor.run {
                    self.databases = result
                }
            } catch {
                lastError = error
                collections[currentDatabase.name] = []
            }
        }
    }
    
    func connect() async throws {
        guard connectionStatus != .connected else { return }
        
        connectionStatus = .connecting
        
        do {
            self.database = try await MongoDatabase.connect(to: connection.url)
            connectionStatus = .connected
            
            if let databaseService = self.databaseService {
                do {
                    let buildInfo = try await databaseService.getBuildInfo()
                    connectionVersion = buildInfo.version
                }
            }
            lastError = nil
        } catch {
            lastError = error
            connectionStatus = .error
            throw error
        }
    }
    
    func loadCollectionsForCurrentDatabase() async {
        guard let currentDatabase = database else { return }
        
        do {
            let collections = try await databaseService?.listCollections()
            self.collections[currentDatabase.name] = collections
            
            let result = try await currentDatabase.pool.listDatabases()
            await MainActor.run {
                self.databases = result
            }
        } catch {
            lastError = error
            collections[currentDatabase.name] = []
        }
    }
    
    
    func getDocumentCount(for collectionName: String) async throws -> Int {
        guard let collection = database?[collectionName] else {
            throw MongoError.collectionNotFound
        }
        
        do {
            let count = try await collection.count()
            return count
        } catch {
            lastError = error
            throw error
        }
    }
    
    func findQueryBuilder(from collectionName: String) throws -> FindQueryBuilder {
        guard let collection = database?[collectionName] else {
            throw MongoError.collectionNotFound
        }
        
        return collection.find()
    }
    
    func findQueryBuilder(from collectionName: String, filter: Document = [:]) throws -> FindQueryBuilder {
        guard let collection = database?[collectionName] else {
            throw MongoError.collectionNotFound
        }
        
        return collection.find(filter)
    }
    
    func deleteDocumentBy(fromCollection collectionName: String, withId id: ObjectId) async throws {
        guard let collection = database?[collectionName] else {
            throw MongoError.collectionNotFound
        }
        
        do {
            // Create a filter document with the _id field matching the provided ObjectId
            let filter: Document = ["_id": id]
            
            // Execute the delete operation
            try await collection.deleteOne(where: filter)
        } catch {
            lastError = error
            throw error
        }
    }
    
    func updateDocument(fromCollection collectionName: String, withId id: ObjectId, withData: String) async throws {
        guard let collection = database?[collectionName] else {
            throw MongoError.collectionNotFound
        }
        
        do {
            let documentToUpdate = try Document(fromJSON: withData)
            let updateResult = try await collection.updateOne(where: ["_id": id], to: documentToUpdate)
            if updateResult.updatedCount == 0 {
                throw MongoError.invalidData
            }
        } catch {
            lastError = error
            throw error
        }
    }
    
    
    func createDocument(withDocument: Document) async throws {
        guard let collectionName = selectedTab?.name else {
            throw MongoError.collectionNotFound
        }
        
        guard let collection = database?[collectionName] else {
            throw MongoError.collectionNotFound
        }
        
        do {
            let createResult = try await collection.insert(withDocument)
            if createResult.insertCount == 0 {
                throw MongoError.invalidData
            }
        } catch {
            throw error
        }
    }
    
    func createCollection(withName: String) async throws {
        do {
            try await databaseService?.createCollection(withName)
        } catch {
            throw error
        }
    }
    
    // MARK: - Tab Management
    func createNewTab(name: String) {
        if let existingTab = tabs.first(where: { $0.name == name }) {
            selectedTab = existingTab
            return
        }
        
        let newTab = DatabaseTab(name: name, type: .browse, queryState: .idle)
        tabs.append(newTab)
        
        selectedTab = newTab
    }
    
    func removeTab(_ tab: DatabaseTab) {
        guard !tabs.isEmpty else { return }
        
        if let index = tabs.firstIndex(where: { $0.id == tab.id }) {
            let newSelectedIndex = max(0, index - 1)
            tabs.remove(at: index)
            
            if !tabs.isEmpty {
                selectedTab = tabs[newSelectedIndex]
            } else {
                selectedTab = nil
            }
        }
    }
    
    func selectTab(_ tab: DatabaseTab) {
        selectedTab = tab
    }
    
    func nextTab(_ currentTab: DatabaseTab) {
        if let currentIndex = tabs.firstIndex(where: { $0.id == currentTab.id }),
           currentIndex < tabs.count - 1 {
            selectedTab = tabs[currentIndex + 1]
        }
    }
    
    func previousTab(_ currentTab: DatabaseTab) {
        if let currentIndex = tabs.firstIndex(where: { $0.id == currentTab.id }),
           currentIndex > 0 {
            selectedTab = tabs[currentIndex - 1]
        }
    }
}

enum ConnectionStatus: String {
    case connected = "Connected"
    case connecting = "Connecting"
    case disconnected = "Disconnected"
    case error = "Error"
}

