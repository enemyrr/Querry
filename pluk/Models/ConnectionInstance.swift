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
    private var _databaseDriver: (any DatabaseDriver)?
    var connectedDatabase: (any DatabaseWrapper)?
    
    // Public getter for database driver (needed by ConnectionService)
    var databaseDriver: (any DatabaseDriver)? {
        return _databaseDriver
    }
    
    // Generic collections and databases storage
    var collections: [String: [any CollectionWrapper]] = [:]
    var databases: [any DatabaseWrapper] = []
    
    var documents: [String: PostgreSQLQueryResult] = [:]
    var schema: [String: DatabaseSchemaResult] = [:]
    
    // Legacy MongoDB support - these will be deprecated gradually
    var database: MongoDatabase?
    
    // Connection state
    var connectionStatus: ConnectionStatus = .connecting
    var connectionVersion: String?
    var lastError: Error?
    
    @ObservationIgnored
    var documentViewModels: [UUID: DocumentListModel] = [:]
    
    // UI State
    var tabs: [DatabaseTab] = []
    private var selectedTabId: UUID?
    
    var selectedTab: DatabaseTab? {
        get {
            guard let selectedTabId = selectedTabId else { return nil }
            return tabs.first { $0.id == selectedTabId }
        }
        set {
            selectedTabId = newValue?.id
        }
    }
    
    var isLoadingAnimation: Bool = true
    var isLoading = true
    var error: Error?
    var lastFetchTimestamp: Date = Date()
    
    init(connection: Connection) {
        self.connection = connection
    }
    
    func processDatabaseCollections(previousDatabase: MongoDatabase?) async {
        guard let currentDatabase = database else { return }
        
        let shouldUpdate = previousDatabase == nil || currentDatabase.name != previousDatabase?.name
        
        if shouldUpdate {
            do {
                //                let collections = try await databaseService?.listCollections()
                //                self.collections[currentDatabase.name] = collections
                
                let result = try await currentDatabase.pool.listDatabases()
                await MainActor.run {
                    //                    self.databases = result
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
            _databaseDriver = DatabaseDriverFactory.createDriver(for: connection.databaseType)
            
            guard let driver = _databaseDriver else {
                throw DatabaseError.operationFailed("Failed to create database driver")
            }
            
            // Connect and store the database
            connectedDatabase = try await driver.connect(to: connection.connectionUri)
            connectionStatus = .connected
            
            do {
                let buildInfo = try await driver.getBuildInfo()
                connectionVersion = buildInfo.version
            } catch {
                // Non-critical error, continue with connection
                print("Could not get build info: \(error)")
            }
            
            // Load databases and collections
            await loadDatabasesAndCollections()
            
            lastError = nil
        } catch {
            lastError = error
            connectionStatus = .error
            throw error
        }
    }
    
    private func loadDatabasesAndCollections() async {
        guard let driver = _databaseDriver else { return }
        
        do {
            // Load databases
            let databaseList = try await driver.listDatabases()
            await MainActor.run {
                self.databases = databaseList
            }
            
            // Load collections for current database
            if let currentDb = connectedDatabase {
                let collectionList = try await driver.listCollections()
                self.collections[currentDb.name] = collectionList
            }
        } catch {
            lastError = error
            print("Failed to load databases and collections: \(error)")
        }
    }
    
    @discardableResult
    func getSchema(for collectionName: String) async throws {
        guard let driver = _databaseDriver else { return }
        
        let schemaResult = try await driver.getSchema(for: collectionName)
        
        self.schema[collectionName] = schemaResult
        
        // Load collections for current database
//        if let currentDb = connectedDatabase {
//            let collectionList = try await driver.listCollections()
//            self.collections[currentDb.name] = collectionList
//        }
        
    }
    
    func loadCollectionsForCurrentDatabase() async {
        guard let driver = _databaseDriver,
              let currentDatabase = connectedDatabase else { return }
        
        do {
            let collectionList = try await driver.listCollections()
            self.collections[currentDatabase.name] = collectionList
        } catch {
            lastError = error
            collections[currentDatabase.name] = []
        }
    }
    
    
    /// Fetch documents from a collection
    /// - Parameter collectionName: The name of the collection to fetch from
    /// - Returns: Array of documents from the collection
    func fetchDocuments(from collectionName: String, filter: String = "") async throws {
        guard let driver = _databaseDriver, let selectedTab else {
            throw DatabaseError.operationFailed("No active database connection")
        }
        
        await MainActor.run {
            self.error = nil
            self.isLoading = true
            self.isLoadingAnimation = true
        }
        
        switch connection.databaseType {
        case .mongodb:
            // For MongoDB, use the legacy MongoDB methods until we refactor them
            guard let collection = self.database?[collectionName] else {
                throw MongoError.collectionNotFound
            }
            
            let cursor = collection.find()
            _ = try await cursor.drain()
            
            // Update documents for MongoDB (if needed)
            await MainActor.run {
                self.lastFetchTimestamp = Date()
                self.isLoading = false
                
                Task { @MainActor in
                    try? await Task.sleep(for: .milliseconds(800))
                    self.isLoadingAnimation = false
                }
            }
            
        case .postgres, .supabase, .neon:
            let rows = try await driver.findDocuments(
                in: collectionName,
                filter: ["rawQuery": filter],
                skip: selectedTab.skip,
                limit: selectedTab.limit
            ) as? PostgreSQLQueryResult
            
            await MainActor.run {
                self.documents[collectionName] = rows
                updateTotalRows(documents.count)
                self.lastFetchTimestamp = Date()
                self.isLoading = false
                
                Task { @MainActor in
                    try? await Task.sleep(for: .milliseconds(800))
                    self.isLoadingAnimation = false
                }
            }
            
        default:
            throw DatabaseError.operationFailed("Unsupported database type for document fetching")
        }
    }
    
    
    // Legacy MongoDB methods - these will be gradually refactored
    func findQueryBuilder(from collectionName: String) throws -> FindQueryBuilder {
        guard connection.databaseType == .mongodb,
              let collection = database?[collectionName] else {
            throw MongoError.collectionNotFound
        }
        
        return collection.find()
    }
    
    func findQueryBuilder(from collectionName: String, filter: Document = [:]) throws -> FindQueryBuilder {
        guard connection.databaseType == .mongodb,
              let collection = database?[collectionName] else {
            throw MongoError.collectionNotFound
        }
        
        return collection.find(filter)
    }
    
    func deleteDocumentBy(fromCollection collectionName: String, withId id: ObjectId) async throws {
        guard let driver = _databaseDriver,
              let database = connectedDatabase else {
            throw DatabaseError.operationFailed("No active database connection")
        }
        
        do {
            //            try await driver.deleteDocument(in: collectionName, database: database, id: id)
        } catch {
            lastError = error
            throw error
        }
    }
    
    func updateDocument(fromCollection collectionName: String, withId id: ObjectId, withData: String) async throws {
        guard let driver = _databaseDriver,
              let database = connectedDatabase else {
            throw DatabaseError.operationFailed("No active database connection")
        }
        
        do {
            // Parse JSON string to dictionary
            guard let data = withData.data(using: .utf8),
                  let documentDict = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                throw DatabaseError.operationFailed("Invalid JSON data")
            }
            
            //            try await driver.updateDocument(in: collectionName, database: database, id: id, data: documentDict)
        } catch {
            lastError = error
            throw error
        }
    }
    
    func createDocument(withDocument: Document) async throws {
        guard let collectionName = selectedTab?.name,
              let driver = _databaseDriver,
              let database = connectedDatabase else {
            throw DatabaseError.operationFailed("No active database connection or collection")
        }
        
        do {
            // Convert MongoDB Document to generic dictionary
            var documentDict: [String: Any] = [:]
            for (key, value) in withDocument {
                documentDict[key] = value
            }
            
            //            try await driver.createDocument(in: collectionName, database: database, document: documentDict)
        } catch {
            throw error
        }
    }
    
    func renameCollection(from oldName: String, to newName: String) async throws {
        guard let driver = _databaseDriver else {
            throw DatabaseError.operationFailed("No active database connection")
        }
        
        do {
            try await driver.renameCollection(from: oldName, to: newName)
            updateTabName(from: oldName, to: newName)
        } catch {
            throw error
        }
    }
    
    func createCollection(withName: String) async throws {
        guard let driver = _databaseDriver else {
            throw DatabaseError.operationFailed("No active database connection")
        }
        
        do {
            try await driver.createCollection(named: withName)
        } catch {
            throw error
        }
    }
    
    // MARK: - Tab Management
    func createNewTab(name: String) {
        if let existingTab = tabs.first(where: { $0.name == name }) {
            selectedTabId = existingTab.id
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
    
    func updateTabName(from oldName: String, to newName: String) {
        if let tabIndex = tabs.firstIndex(where: { $0.name == oldName }) {
            tabs[tabIndex].name = newName
            
            if selectedTab?.name == oldName {
                selectedTab = tabs[tabIndex]
            }
        }
    }
    
    func selectTab(_ tab: DatabaseTab) {
        selectedTabId = tab.id
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
    
    // MARK: - Pagination Management (direct and simple)
    
    func updateCurrentPage(_ page: Int) {
        guard let selectedTabId = selectedTabId,
              let tabIndex = tabs.firstIndex(where: { $0.id == selectedTabId }),
              page > 0 && page <= tabs[tabIndex].totalPages else { return }
        
        tabs[tabIndex].currentPage = page
    }
    
    func updateRowsPerPage(_ count: Int) {
        guard let selectedTabId = selectedTabId,
              let tabIndex = tabs.firstIndex(where: { $0.id == selectedTabId }),
              count > 0 else { return }
        
        tabs[tabIndex].rowsPerPage = count
        
        // Recalculate pagination
        let totalPages = max(1, Int(ceil(Double(tabs[tabIndex].totalRows) / Double(count))))
        tabs[tabIndex].totalPages = totalPages
        tabs[tabIndex].currentPage = min(tabs[tabIndex].currentPage, totalPages)
    }
    
    func updateTotalRows(_ count: Int) {
        guard let selectedTabId = selectedTabId,
              let tabIndex = tabs.firstIndex(where: { $0.id == selectedTabId }) else { return }
        
        tabs[tabIndex].totalRows = count
        let totalPages = max(1, Int(ceil(Double(count) / Double(tabs[tabIndex].rowsPerPage))))
        tabs[tabIndex].totalPages = totalPages
        tabs[tabIndex].currentPage = min(tabs[tabIndex].currentPage, totalPages)
    }
}

enum ConnectionStatus: String {
    case connected = "Connected"
    case connecting = "Connecting"
    case disconnected = "Disconnected"
    case error = "Error"
}

