//
//  ConnectionInstance.swift
//  Collection
//
//  Created by Fauzaan on 1/21/25.
//

import Foundation
import MongoKitten
import SwiftUI

@Observable
final class ConnectionInstance: Identifiable {
    let id = UUID()
    let connection: Connection
    
    // Connection state
    var connectionStatus: ConnectionStatus = .disconnected
    var lastError: Error?
    
    // UI State
    var tabs: [DatabaseTab] = []
    var selectedTab: DatabaseTab?
    
    // Query results cache
    private var queryCache: [String: Any] = [:]
    
    // Database metadata
    var databases: [MongoDatabase] = []
    var collections: [String: [MongoCollection]] = [:]
    var database: MongoDatabase? {
        didSet {
            if let currentDatabase = database {
                let shouldUpdate = oldValue == nil || currentDatabase.name != oldValue?.name
                
                if shouldUpdate {
                    Task {
                        await loadCollectionsForDatabase(currentDatabase.name)
                        databases = try await currentDatabase.pool.listDatabases()
                    }
                }
            }
        }
    }
    
    init(connection: Connection) {
        self.connection = connection
    }
    
    func connect() async throws {
        guard connectionStatus != .connected else { return }
        
        connectionStatus = .connecting
        
        do {
            self.database = try await MongoDatabase.connect(to: connection.url)
            connectionStatus = .connected
            lastError = nil
        } catch {
            lastError = error
            connectionStatus = .error
            throw error
        }
    }
    
    func collectionsForCurrentDatabase() -> [MongoCollection] {
        guard let dbName = database else { return [] }
        return collections[dbName.name] ?? []
    }
    
    private func loadCollectionsForDatabase(_ databaseName: String) async {
        do {
            guard let database = database else {
                throw MongoError.databaseNotInitialized
            }
            
            let dbCollections = try await database.listCollections()
            let sortedCollections = dbCollections.sorted { $0.name < $1.name }
            collections[databaseName] = sortedCollections
        } catch {
            lastError = error
            collections[databaseName] = []
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
    
    func createNewTab(name: String) {
        guard !tabs.contains(where: { $0.name == name }) else {
            if let existingTab = tabs.first(where: { $0.name == name }) {
                selectedTab = existingTab
            }
            return
        }
        
        let newTab = DatabaseTab(name: name, type: .browse, queryState: .idle)
        tabs.append(newTab)
        selectedTab = newTab
    }
    
    
    func cacheDouments(tab: DatabaseTab, documents: [Document]) {
        if let index = tabs.firstIndex(where: { $0.id == tab.id }) {
            tabs[index].documents = documents
        }
    }
}

enum ConnectionStatus: String {
    case connected = "Connected"
    case connecting = "Connecting"
    case disconnected = "Disconnected"
    case error = "Error"
}
