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
import SwiftData
import AIProxy

@Observable class ConnectionInstance: Identifiable {
    let id = UUID()
    let connection: Connection
    private var _databaseDriver: (any DatabaseDriver)?
    var databaseService = DatabaseService()
    var queryHistoryService: QueryHistoryService?
    
    // Public getter for database driver (needed by ConnectionService)
    var databaseDriver: (any DatabaseDriver)? {
        return _databaseDriver
    }
    
    var connectedDatabase: (any DatabaseWrapper)? {
        databaseService.connectedDatabase
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
        setupNotificationObservation()
        Task { @MainActor in
            self.setupQueryHistoryService()
        }
    }

    @MainActor
    private func setupQueryHistoryService() {
        guard let appDelegate = NSApplication.shared.delegate as? AppDelegate else { return }
        let modelContext = ModelContext(appDelegate.sharedModelContainer)
        queryHistoryService = QueryHistoryService(
            modelContext: modelContext,
            connectionKeychainId: connection.keychainId
        )
        databaseService.queryHistoryService = queryHistoryService
    }

    private func setupNotificationObservation() {
        // Listen for database service changes and repost them with self as object
        NotificationCenter.default.addObserver(
            forName: .connectedDatabaseChanged,
            object: databaseService,
            queue: .main
        ) { [weak self] _ in
            guard let self = self else { return }
            NotificationCenter.default.post(name: .connectedDatabaseChanged, object: self)
        }
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    func connect(targetDatabaseName: String? = nil) async throws {
        guard connectionStatus != .connected else { return }

        connectionStatus = .connecting

        do {
            try await databaseService.setActiveConnection(
                connection,
                targetDatabase: targetDatabaseName
            )
            connectionStatus = .connected

            do {
                let buildInfo = try await databaseService.getBuildInfo()
                connectionVersion = buildInfo?.version
            } catch {
                
            }

            await loadDatabases()
            lastError = nil
        } catch {
            lastError = error
            connectionStatus = .error
            let errorType = AnalyticsService.categorizeError(error)
            Task { @MainActor in
                AnalyticsService.shared.trackConnectionFailed(
                    databaseType: connection.databaseType,
                    errorType: errorType
                )
            }
            throw error
        }
    }

    func reconnect() async throws {
        connectionStatus = .connecting

        do {
            try await databaseService.reconnect()

            try await Task.sleep(for: .milliseconds(500))
            connectionStatus = .connected
            lastError = nil
        } catch {
            lastError = error
            connectionStatus = .error
            throw error
        }
    }

    
    func loadDatabases() async {
        do {
            let databaseList = try await databaseService.listDatabases()
            self.databases = databaseList

            // Notify that databases have been updated
            await MainActor.run {
                NotificationCenter.default.post(name: .databasesUpdated, object: self)
            }
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
                let collectionList = try await driver.listCollections(schema: nil)
                self.collections[currentDb.name] = collectionList
            }
        } catch {
            lastError = error
            debugLog("Failed to load databases and collections: \(error)")
        }
    }
    
    func loadCollectionsForCurrentDatabase(schema: String?) async throws {
        guard let database = connectedDatabase else {
            return
        }
        
        guard !database.name.isEmpty else {
              throw DatabaseError.databaseNotSelected
          }
        
        let databaseName = database.name
        
        do {
            let collectionResult = try await databaseService.listCollections(schema: schema)
            
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
    
    func renameCollection(databaseSchema: String?, from oldName: String, to newName: String) async throws {
        guard let driver = _databaseDriver else {
            throw DatabaseError.operationFailed("No active database connection")
        }

        try await driver.renameCollection(databaseSchema: databaseSchema, from: oldName, to: newName)
        updateTabName(from: oldName, to: newName)
    }

    func createCollection(withName: String) async throws {
        guard let driver = _databaseDriver else {
            throw DatabaseError.operationFailed("No active database connection")
        }

        try await driver.createCollection(named: withName)
    }
    
    // MARK: - Tab Management
    func createNewTab(name: String, filterColumn: String? = nil, filterValue: String? = nil, databaseSchema: String? = nil) {
        // Remove quotes from name if present for consistent tab naming
        var cleanName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if cleanName.hasPrefix("\"") && cleanName.hasSuffix("\"") && cleanName.count > 1 {
            cleanName = String(cleanName.dropFirst().dropLast())
        }
        
        // Check for existing tab with same table name
        if let existingTab = tabs.first(where: { $0.name == cleanName }) {
            // Check if filter parameters have actually changed
            let hasFilterChanged = existingTab.filterColumn != filterColumn ||
                                   existingTab.filterValue != filterValue

            // Update the existing tab's filter
            existingTab.filterColumn = filterColumn
            existingTab.filterValue = filterValue

            // Only force refresh if filter criteria changed
            existingTab.forceFetch = hasFilterChanged

            selectedTab = existingTab
            return
        }
        
        // Create new tab if none exists for this table
        let newTab = DatabaseTab(
            name: cleanName,
            type: .browse,
            queryState: .idle,
            filterColumn: filterColumn,
            filterValue: filterValue,
            databaseSchema: databaseSchema
        )
        tabs.append(newTab)
        
        selectedTab = newTab
    }
    
    func createSQLEditorTab(withQuery query: String? = nil) {
        let newTab = DatabaseTab(
            name: "Query Editor",
            type: .sqlEditor,
            queryState: .idle
        )
        newTab.initialQuery = query
        tabs.append(newTab)

        selectedTab = newTab
    }

    func createCanvasTab() {
        if let existingTab = tabs.first(where: { $0.type == .canvas }) {
            selectedTab = existingTab
            return
        }

        let newTab = DatabaseTab(
            name: "Schema Visualizer",
            type: .canvas,
            queryState: .idle
        )
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

    func moveTab(fromIndex: Int, toIndex: Int) {
        guard fromIndex != toIndex,
              fromIndex >= 0, fromIndex < tabs.count,
              toIndex >= 0, toIndex <= tabs.count else {
            return
        }

        var newTabs = tabs
        let tab = newTabs.remove(at: fromIndex)
        let adjustedIndex = toIndex > fromIndex ? toIndex - 1 : toIndex
        newTabs.insert(tab, at: adjustedIndex)
        tabs = newTabs
    }
    
}

enum ConnectionStatus: String {
    case connected = "Connected"
    case connecting = "Connecting"
    case disconnected = "Disconnected"
    case error = "Error"
}
