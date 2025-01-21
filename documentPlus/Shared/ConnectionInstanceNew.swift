//
//  ConnectionInstance.swift
//  DocumentPlus
//
//  Created by Fauzaan on 1/21/25.
//

import Foundation
import MongoKitten
import SwiftUI
import UniformTypeIdentifiers

@Observable
final class ConnectionInstanceNew: Identifiable {
    let id = UUID()
    let connection: Connection
    private var mongoConnection: MongoDatabase?

    // Connection state
    var isLoading = false
    var isConnected: Bool = false
    var lastError: Error?

    // UI State
    var selectedCollection: String?
    var tabs: [DatabaseTab] = []
    var selectedTab: DatabaseTab?

    // Query results cache
    private var queryCache: [String: Any] = [:]

    // Database metadata
    var databases: [MongoDatabase] = []
    var collections: [String: [MongoCollection]] = [:]

    var selectedDatabase: String? {
        didSet {
            if selectedDatabase != oldValue {
                // Load collections for new selected database
                if let dbName = selectedDatabase {
                    Task {
                        await loadCollectionsForDatabase(dbName)
                    }
                }
            }
        }
    }
    
    init(connection: Connection) {
        self.connection = connection
    }
    
    func connect() async throws {
        print("connecting again")
        guard !isConnected else { return }
        
        isLoading = true
        do {
            await DatabaseProvider.shared.setupDatabase(
                connectionString: connection.url, databaseName: connection.name
            )
            
            self.databases = await DatabaseProvider.shared
                .fetchDatabases()
            
            self.selectedDatabase = databases.first?.name
            isConnected = true
            lastError = nil
        } catch {
            lastError = error
            throw error
        }
        isLoading = false
    }
    
    func collectionsForCurrentDatabase() -> [MongoCollection] {
        guard let dbName = selectedDatabase else { return [] }
        return collections[dbName] ?? []
    }
    
    private func loadCollectionsForDatabase(_ databaseName: String) async {
        do {
            let dbCollections = await DatabaseProvider.shared.fetchCollections()
            collections[databaseName] = dbCollections
        } catch {
            lastError = error
            collections[databaseName] = []
        }
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

struct DatabaseTab: Identifiable, Equatable, Transferable, Codable {
    let id: UUID
    var name: String
    var type: TabType
    var queryState: QueryState
    var documents: [Document] = []

    
    init(name: String, type: TabType, queryState: QueryState) {
           self.id = UUID()
           self.name = name
           self.type = type
           self.queryState = queryState
    }
    
    enum TabType: Equatable, Codable {
        case browse
        case aggregate
        case schema
        case indexes
    }

    enum QueryState: Equatable, Codable {
        case idle
        case loading
        case error(String)
        case results([Document])
        
        // Custom coding implementation for QueryState
        enum CodingKeys: String, CodingKey {
            case type, error, results
        }
        
        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            switch self {
            case .idle:
                try container.encode("idle", forKey: .type)
            case .loading:
                try container.encode("loading", forKey: .type)
            case .error(let message):
                try container.encode("error", forKey: .type)
                try container.encode(message, forKey: .error)
            case .results(let documents):
                try container.encode("results", forKey: .type)
                try container.encode(documents, forKey: .results)
            }
        }
        
        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            let type = try container.decode(String.self, forKey: .type)
            switch type {
            case "idle":
                self = .idle
            case "loading":
                self = .loading
            case "error":
                let message = try container.decode(String.self, forKey: .error)
                self = .error(message)
            case "results":
                let documents = try container.decode([Document].self, forKey: .results)
                self = .results(documents)
            default:
                throw DecodingError.dataCorruptedError(forKey: .type, in: container, debugDescription: "Unknown type")
            }
        }
    }
    
    static var transferRepresentation: some TransferRepresentation {
            ProxyRepresentation(exporting: { tab in
                tab.id.uuidString
            })
        }
}

enum QueryState: Equatable, Codable {
    case idle
    case loading
    case error(String)
    case results([Document])
    
    enum CodingKeys: String, CodingKey {
        case type, error
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .idle:
            try container.encode("idle", forKey: .type)
        case .loading:
            try container.encode("loading", forKey: .type)
        case .error(let message):
            try container.encode("error", forKey: .type)
            try container.encode(message, forKey: .error)
        case .results:
            // Don't encode documents, just the state
            try container.encode("results", forKey: .type)
        }
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)
        switch type {
        case "idle":
            self = .idle
        case "loading":
            self = .loading
        case "error":
            let message = try container.decode(String.self, forKey: .error)
            self = .error(message)
        case "results":
            // Initialize with empty results when decoding
            self = .results([])
        default:
            throw DecodingError.dataCorruptedError(forKey: .type, in: container, debugDescription: "Unknown type")
        }
    }
}
