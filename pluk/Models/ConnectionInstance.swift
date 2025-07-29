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
    //    var connectedDatabase: (any DatabaseWrapper)?
    
    private var _databaseDriver: (any DatabaseDriver)?
    private var _databaseService = DatabaseService()
    
    // Public getter for database driver (needed by ConnectionService)
    var databaseDriver: (any DatabaseDriver)? {
        return _databaseDriver
    }
    
    var databaseService: DatabaseService? {
        return _databaseService
    }
    
    var connectedDatabase: (any DatabaseWrapper)? {
        _databaseService.connectedDatabase
    }
    
    var databaseType: DatabaseType? {
        connection.databaseType
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
    
    // UI State
    var tabs: [DatabaseTab] = []
    
    var selectedTab: DatabaseTab?
    
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
            try await _databaseService.setActiveConnection(
                connection
            )
            connectionStatus = .connected
            
            let buildInfo = try await _databaseService.getBuildInfo()
            connectionVersion = buildInfo?.version
            
            await loadDatabases()
            lastError = nil
        } catch {
            lastError = error
            connectionStatus = .error
            throw error
        }
    }
    
    func loadDatabases() async {
        do {
            let databaseList = try await _databaseService.listDatabases()
            self.databases = databaseList
        } catch {
            lastError = error
            debugLog("Failed to load databases \(error)")
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
            debugLog("Failed to load databases and collections: \(error)")
        }
    }
    
    @discardableResult
    func getSchema(for collectionName: String) async throws -> DatabaseSchemaResult? {
        let schemaResult = try await _databaseService.getSchema(for: collectionName)
        self.schema[collectionName] = schemaResult
        return schemaResult
    }
    
    func loadCollectionsForCurrentDatabase() async throws {
        guard let database = connectedDatabase else {
            return
        }
        
        guard !database.name.isEmpty else {
              throw DatabaseError.databaseNotSelected
          }
        
        let databaseName = database.name
        
        do {
            let collectionResult = try await _databaseService.listCollections()
            
            await MainActor.run {
                self.collections[databaseName] = collectionResult
            }
            
        } catch {
            await MainActor.run {
                self.collections[databaseName] = []
            }
            throw error
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
    func createNewTab(name: String, filterColumn: String? = nil, filterValue: String? = nil) {
        // Remove quotes from name if present for consistent tab naming
        var cleanName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if cleanName.hasPrefix("\"") && cleanName.hasSuffix("\"") && cleanName.count > 1 {
            cleanName = String(cleanName.dropFirst().dropLast())
        }
        
        // Check for existing tab with same table name
        if let existingTab = tabs.first(where: { $0.name == cleanName }) {
            // Update the existing tab's filter - this will now trigger SwiftUI updates
            existingTab.filterColumn = filterColumn
            existingTab.filterValue = filterValue
            existingTab.forceFetch = true
            selectedTab = existingTab
            return
        }
        
        // Create new tab if none exists for this table
        let newTab = DatabaseTab(name: cleanName, type: .browse, queryState: .idle, filterColumn: filterColumn, filterValue: filterValue)
        tabs.append(newTab)
        
        selectedTab = newTab
    }
    
    func removeTab(_ tab: DatabaseTab) {
        guard !tabs.isEmpty else { return }
        
        if let index = tabs.firstIndex(where: { $0.id == tab.id }) {
            let wasSelected = selectedTab?.id == tab.id
            tabs.remove(at: index)
            
            // Only change selection if we removed the selected tab
            if wasSelected {
                if !tabs.isEmpty {
                    // Select the tab at the same index, or the previous one if we removed the last tab
                    let newSelectedIndex = min(index, tabs.count - 1)
                    selectedTab = tabs[newSelectedIndex]
                } else {
                    selectedTab = nil
                }
            }
            // If the removed tab wasn't selected, keep the current selection
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
    
    func selectTabByIndex(_ index: Int) {
        guard index >= 0 && index < tabs.count else { return }
        selectedTab = tabs[index]
    }
    
    // MARK: - Pagination Management (direct and simple)
    
    func updateCurrentPage(_ page: Int) {
        //        guard let selectedTabId = selectedTabId,
        //              let tabIndex = tabs.firstIndex(where: { $0.id == selectedTabId }),
        //              page > 0 && page <= tabs[tabIndex].totalPages else { return }
        //
        //        tabs[tabIndex].currentPage = page
    }
    
    func updateRowsPerPage(_ count: Int) {
        //        guard let selectedTabId = selectedTabId,
        //              let tabIndex = tabs.firstIndex(where: { $0.id == selectedTabId }),
        //              count > 0 else { return }
        //
        //        tabs[tabIndex].rowsPerPage = count
        //
        //        // Recalculate pagination
        //        let totalPages = max(1, Int(ceil(Double(tabs[tabIndex].totalRows) / Double(count))))
        //        tabs[tabIndex].totalPages = totalPages
        //        tabs[tabIndex].currentPage = min(tabs[tabIndex].currentPage, totalPages)
    }
    
    func updateTotalRows(_ count: Int) {
        //        guard let selectedTabId = selectedTabId,
        //              let tabIndex = tabs.firstIndex(where: { $0.id == selectedTabId }) else { return }
        //
        //        tabs[tabIndex].totalRows = count
        //        let totalPages = max(1, Int(ceil(Double(count) / Double(tabs[tabIndex].rowsPerPage))))
        //        tabs[tabIndex].totalPages = totalPages
        //        tabs[tabIndex].currentPage = min(tabs[tabIndex].currentPage, totalPages)
    }
}

enum ConnectionStatus: String {
    case connected = "Connected"
    case connecting = "Connecting"
    case disconnected = "Disconnected"
    case error = "Error"
}
