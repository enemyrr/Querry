//
//  DatabaseService.swift
//  Pluk
//
//  Created by Fauzaan on 4/11/25.
//

import Foundation
import SwiftUI

@Observable class DatabaseService {
    // MARK: - Current Connection State
    private var activeConnection: Connection?
    private var activeDriver: (any DatabaseDriver)?
    public var connectedDatabase: (any DatabaseWrapper)?
    public var currentSchema: String?

    // Public getter for database driver (needed for schema modifications)
    public var driver: (any DatabaseDriver)? {
        return activeDriver
    }

    // MARK: - Query History
    weak var queryHistoryService: QueryHistoryService?

    private func recordQueryHistory(
        query: String,
        queryType: QueryType? = nil,
        source: QuerySource,
        databaseType: DatabaseType,
        databaseName: String?,
        schemaName: String?,
        tableName: String? = nil,
        executionDurationMs: Int?,
        rowsAffected: Int? = nil,
        wasSuccessful: Bool,
        errorMessage: String? = nil
    ) {
        let service = queryHistoryService
        Task { @MainActor in
            service?.recordQuery(
                query: query,
                queryType: queryType,
                source: source,
                databaseType: databaseType,
                databaseName: databaseName,
                schemaName: schemaName,
                tableName: tableName,
                executionDurationMs: executionDurationMs,
                rowsAffected: rowsAffected,
                wasSuccessful: wasSuccessful,
                errorMessage: errorMessage
            )
        }
    }

    // MARK: - Results Cache
    private var queryCache: [String: QueryResult] = [:]
    
    // MARK: - Real-time Subscription Management
    private var activeSubscriptionTasks: [String: Task<Void, Never>] = [:]
    private var subscriptionTableNames: [String: String] = [:] // Maps tabId to tableName
    
    // MARK: - Connection Management
    func setActiveConnection(_ connection: Connection, targetDatabase: String? = nil) async throws {
        self.activeConnection = connection
        
        // Create appropriate driver
        self.activeDriver = DatabaseDriverFactory.createDriver(for: connection.databaseType)
        
        guard let driver = activeDriver else {
            throw DatabaseError.operationFailed("Failed to create database driver")
        }
        
        // Determine target database: use provided parameter, or existing connectedDatabase name, or none
        let targetDatabaseName = targetDatabase ?? self.connectedDatabase?.name
        
        // For Convex, append target database to URI if specified
        var connectionUri = connection.connectionUri
        if connection.databaseType == .convex, let targetName = targetDatabaseName {
            connectionUri += "#target=\(targetName)"
        }
        
        // Connect to database
        self.connectedDatabase = try await driver.connect(to: connectionUri)

        // For non-Convex databases, switch to target database if needed
        if connection.databaseType != .convex,
           let targetName = targetDatabaseName,
           !targetName.isEmpty,
           connectedDatabase?.name != targetName {
            try await driver.switchDatabase(to: targetName)
            // Update connectedDatabase to reflect the switch using the appropriate wrapper type
            switch connection.databaseType {
            case .postgres, .supabase:
                self.connectedDatabase = PostgreSQLDatabaseWrapper(name: targetName, size: nil, tableCount: nil)
            case .mysql:
                self.connectedDatabase = MySQLDatabaseWrapper(name: targetName, size: nil, tableCount: nil)
            case .sqlite:
                self.connectedDatabase = SQLiteDatabaseWrapper(name: targetName, size: nil, tableCount: nil)
            case .mongodb:
                // For MongoDB, get the database wrapper from the driver after switching
                if let mongoDriver = driver as? MongoDBDriver,
                   let wrapper = mongoDriver.getCurrentDatabaseWrapper() {
                    self.connectedDatabase = wrapper
                }
            default:
                break
            }
        }

        // Post notification about database connection change
        NotificationCenter.default.post(name: .connectedDatabaseChanged, object: self)
    }
    
    func setCurrentSchema(_ schema: String) {
        self.currentSchema = schema
    }
    
    func switchActiveDatabase(to database: any DatabaseWrapper) async throws {
        guard let driver = activeDriver else {
            throw DatabaseError.operationFailed("No active database driver")
        }
        
        self.connectedDatabase = database
        try await driver.switchDatabase(to: database.name)
        
        // Post notification about database switch
        NotificationCenter.default.post(name: .connectedDatabaseChanged, object: self)
    }
    
    func disconnect() async {
        // Cancel all active subscriptions (this also clears subscription caches)
        cancelAllSubscriptions()
        
        await activeDriver?.disconnect()
        activeConnection = nil
        activeDriver = nil
        connectedDatabase = nil
        clearCache()
    }
    
    func reconnect() async throws {
        guard let driver = activeDriver else {
            throw DatabaseError.operationFailed("No active database driver")
        }
        
        try await driver.reconnect()
    }
    
    // MARK: - Real-time Support
    
    var supportsRealTime: Bool {
        return activeConnection?.databaseType.supportsRealTime ?? false
    }
    
    func subscribeToTableChanges(
           tabId: UUID,
           tableName: String,
           schema: String?,
           filter: String?,
           limit: Int = 200,
           sortBy: String? = nil,
           ascending: Bool? = nil,
           page: Int? = nil,
           onUpdate: @escaping (QueryResult) -> Void,
           onError: @escaping (Error) -> Void
       ) async throws {
           guard let driver = activeDriver else {
               throw DatabaseError.operationFailed("No active database driver")
           }
           
           let subscriptionKey = tabId.uuidString
           
           // Cancel existing subscription for this tab if any
           if let existingTask = activeSubscriptionTasks[subscriptionKey] {
               existingTask.cancel()
               activeSubscriptionTasks.removeValue(forKey: subscriptionKey)
               
               // Clear subscription cache for the previous table
               if let previousTableName = subscriptionTableNames[subscriptionKey] {
                   activeDriver?.clearSubscriptionCache(for: previousTableName)
               }
               subscriptionTableNames.removeValue(forKey: subscriptionKey)
           }
           
           // Create new subscription task
           let subscriptionTask = Task {
               do {
                   try await driver.subscribeToCollectionChanges(
                       collectionName: tableName,
                       databaseSchema: schema,
                       filter: filter,
                       limit: limit,
                       sortBy: sortBy,
                       ascending: ascending,
                       page: page,
                       onUpdate: onUpdate,
                       onError: onError
                   )
               } catch {
                   await MainActor.run {
                       onError(error)
                   }
               }
           }
           
           activeSubscriptionTasks[subscriptionKey] = subscriptionTask
           subscriptionTableNames[subscriptionKey] = tableName
       }
       
       func cancelSubscription(forTabId tabId: UUID) {
           let subscriptionKey = tabId.uuidString
           if let task = activeSubscriptionTasks[subscriptionKey] {
               task.cancel()
               activeSubscriptionTasks.removeValue(forKey: subscriptionKey)
               
               // Clear subscription cache for this table
               if let tableName = subscriptionTableNames[subscriptionKey] {
                   activeDriver?.clearSubscriptionCache(for: tableName)
               }
               subscriptionTableNames.removeValue(forKey: subscriptionKey)
           }
       }
       
       func cancelAllSubscriptions() {
           for task in activeSubscriptionTasks.values {
               task.cancel()
           }
           
           // Clear subscription cache for all tables
           for tableName in subscriptionTableNames.values {
               activeDriver?.clearSubscriptionCache(for: tableName)
           }
           
           activeSubscriptionTasks.removeAll()
           subscriptionTableNames.removeAll()
       }
    
    // MARK: - Connectivity Test
    func testConnection(_ connection: Connection) async -> Result<Void, DatabaseError> {
        let driver = DatabaseDriverFactory.createDriver(for: connection.databaseType)
        do {
            try await driver.ping(to: connection.connectionUri)
            return .success(())
        } catch let dbError as DatabaseError {
            return .failure(dbError)
        } catch {
            return .failure(DatabaseError.connectionFailed(error.localizedDescription))
        }
    }
    
    func testConnection(databaseType: DatabaseType, uri: String) async -> Result<Void, DatabaseError> {
        let driver = DatabaseDriverFactory.createDriver(for: databaseType)
        do {
            try await driver.ping(to: uri)
            return .success(())
        } catch let dbError as DatabaseError {
            return .failure(dbError)
        } catch {
            return .failure(DatabaseError.connectionFailed(error.localizedDescription))
        }
    }
    
    // MARK: - Database Operations
    func getBuildInfo() async throws -> BuildInfo? {
        guard let driver = activeDriver else { return nil }
        return try await driver.getBuildInfo()
    }
    
    /// Get the current deployment URL (useful for Convex environments)
    func getCurrentDeploymentUrl() -> String? {
        return activeDriver?.getCurrentDeploymentUrl()
    }
    
    func listDatabases() async throws -> [any DatabaseWrapper] {
        guard let driver = activeDriver else { return [] }
        
        // Use type erasure to handle different database types
        return try await driver.listDatabases().map { $0 as any DatabaseWrapper }
    }
    
    func listCollections(schema: String?) async throws -> [any CollectionWrapper] {
        guard let driver = activeDriver else { return [] }
        return try await driver.listCollections(schema: schema).map { $0 as any CollectionWrapper }
    }
    
    // MARK: - Document Operations
    func findDocuments(
        in collectionName: String,
        databaseSchema: String?,
        filter: String = "",
        skip: Int = 0,
        limit: Int = 300,
        sortBy: String?,
        ascending: Bool?
    ) async throws -> QueryResult {
        guard let driver = activeDriver,
              let connection = activeConnection else {
            throw DatabaseError.operationFailed("No active database connection")
        }
        
        let result: QueryResult
        
        switch connection.databaseType {
        case .postgres, .supabase, .convex, .mysql, .sqlite:
            result = try await driver.findDocuments(
                in: collectionName,
                databaseSchema: databaseSchema,
                filter: ["rawQuery": filter],
                skip: skip,
                limit: limit,
                sortBy: sortBy,
                ascending: ascending
            )
            
        case .mongodb:
            result = try await driver.findDocuments(
                in: collectionName,
                filter: ["rawQuery": filter],
                skip: skip,
                limit: limit
            )
        }
        
        return result
    }
    
    /// Generates a filter query from conditions using the appropriate database driver
    func generateFilterQuery(from conditions: [FilterCondition], tableName: String, databaseSchema: String?) -> String {
        guard let driver = activeDriver,
              let connection = activeConnection else {
            return ""
        }
        
        switch connection.databaseType {
        case .postgres, .supabase:
            if let postgresDriver = driver as? PostgreSQLDriver {
                return postgresDriver.generateFilterQuery(from: conditions, tableName: tableName, databaseSchema: databaseSchema)
            }
        case .sqlite:
            if let sqliteDriver = driver as? SQLiteDriver {
                return sqliteDriver.generateFilterQuery(from: conditions, tableName: tableName)
            }
        case .convex:
            if let convexDriver = driver as? ConvexDriver {
                return convexDriver.generateFilterQuery(from: conditions, tableName: tableName)
            }
        case .mysql:
            if let mysqlDriver = driver as? MySQLDriver {
                return mysqlDriver.generateFilterQuery(from: conditions, tableName: tableName)
            }
        case .mongodb:
            // TODO: Implement MongoDB filter generation
            return ""
        }
        
        return ""
    }
    
    func getSchema(for collectionName: String, databaseSchema: String?, forceFetch: Bool = false) async throws -> DatabaseSchemaResult? {
        guard let driver = activeDriver else { return nil }

        if forceFetch {
            await driver.clearSchemaCache(for: collectionName, schema: databaseSchema)
        }

        return try await driver.getSchema(for: collectionName, schema: databaseSchema)
    }
    
    func getInformationSchema() async throws -> [InformationSchema] {
        guard let driver = activeDriver else { return [] }
        return try await driver.getInformationSchema()
    }

    func getIndexes(for collectionName: String, databaseSchema: String?, forceFetch: Bool = false) async throws -> [DatabaseIndexInfo]? {
        guard let driver = activeDriver else { return nil }

        if forceFetch {
            await driver.clearSchemaCache(for: collectionName, schema: databaseSchema)
        }

        return try await driver.getIndexes(for: collectionName, schema: databaseSchema)
    }

    func getDocumentCount(for collectionName: String, filter: [String: Any] = [:]) async throws -> Int {
        guard let driver = activeDriver else { return 0 }
        return try await driver.getDocumentCount(for: collectionName, filter: filter)
    }
    
    func getDatabaseMetadata() async throws -> [DatabaseWrapper] {
        guard let driver = activeDriver else {
            return []
        }
        
        return try await driver.getDatabaseMetadata()
    }
    
    // MARK: - Database Management
    func createDatabase(named databaseName: String, options: CreateDatabaseOptions = .default) async throws {
        guard let driver = activeDriver,
              let connection = activeConnection else {
            throw DatabaseError.operationFailed("No active database connection")
        }

        try await driver.createDatabase(named: databaseName, options: options)
        clearCache()

        Task { @MainActor in
            AnalyticsService.shared.trackDatabaseCreated(databaseType: connection.databaseType)
        }
    }

    // MARK: - Collection Management
    func createCollection(named collectionName: String) async throws {
        guard let driver = activeDriver else {
            throw DatabaseError.operationFailed("No active database connection")
        }

        try await driver.createCollection(named: collectionName)
        clearCache() // Clear cache after structural changes
    }
    
    func renameCollection(databaseSchema: String?, from oldName: String, to newName: String) async throws {
        guard let driver = activeDriver else {
            throw DatabaseError.operationFailed("No active database connection")
        }
        
        try await driver.renameCollection(databaseSchema: databaseSchema, from: oldName, to: newName)
        clearCache() // Clear cache after structural changes
    }
    
    func deleteCollection(named collectionName: String, databaseSchema: String?) async throws {
        guard let driver = activeDriver else {
            throw DatabaseError.operationFailed("No active database connection")
        }
        
        try await driver.deleteCollection(named: collectionName, databaseSchema: databaseSchema)
        clearCache() // Clear cache after structural changes
    }
    
    // MARK: - Document Modification
    func createDocument(in collectionName: String, databaseSchema: String?, document: [String: Any]) async throws {
        guard let driver = activeDriver,
              let connection = activeConnection else {
            throw DatabaseError.operationFailed("No active database connection")
        }

        let startTime = ContinuousClock.now
        let documentDescription = "INSERT INTO \(collectionName) - \(document.keys.joined(separator: ", "))"

        do {
            try await driver.createDocument(in: collectionName, databaseSchema: databaseSchema, document: document)

            let duration = startTime.duration(to: .now)
            let durationMs = Int(duration.components.seconds * 1000 + duration.components.attoseconds / 1_000_000_000_000_000)

            recordQueryHistory(
                query: documentDescription,
                queryType: .insert,
                source: .documentCreate,
                databaseType: connection.databaseType,
                databaseName: connectedDatabase?.name,
                schemaName: databaseSchema,
                tableName: collectionName,
                executionDurationMs: durationMs,
                rowsAffected: 1,
                wasSuccessful: true
            )

            Task { @MainActor in
                AnalyticsService.shared.trackDocumentCreated(databaseType: connection.databaseType)
            }

            clearDocumentCache(for: collectionName)
        } catch {
            let duration = startTime.duration(to: .now)
            let durationMs = Int(duration.components.seconds * 1000 + duration.components.attoseconds / 1_000_000_000_000_000)

            recordQueryHistory(
                query: documentDescription,
                queryType: .insert,
                source: .documentCreate,
                databaseType: connection.databaseType,
                databaseName: connectedDatabase?.name,
                schemaName: databaseSchema,
                tableName: collectionName,
                executionDurationMs: durationMs,
                wasSuccessful: false,
                errorMessage: error.localizedDescription
            )

            throw error
        }
    }

    func updateDocument(in collectionName: String, databaseSchema: String?, id: Any, data: [String: Any]) async throws {
        guard let driver = activeDriver,
              let connection = activeConnection else {
            throw DatabaseError.operationFailed("No active database connection")
        }

        let startTime = ContinuousClock.now
        let documentDescription = "UPDATE \(collectionName) SET \(data.keys.joined(separator: ", ")) WHERE id = \(id)"

        do {
            try await driver.updateDocument(in: collectionName, databaseSchema: databaseSchema, id: id, data: data)

            let duration = startTime.duration(to: .now)
            let durationMs = Int(duration.components.seconds * 1000 + duration.components.attoseconds / 1_000_000_000_000_000)

            recordQueryHistory(
                query: documentDescription,
                queryType: .update,
                source: .documentUpdate,
                databaseType: connection.databaseType,
                databaseName: connectedDatabase?.name,
                schemaName: databaseSchema,
                tableName: collectionName,
                executionDurationMs: durationMs,
                rowsAffected: 1,
                wasSuccessful: true
            )

            Task { @MainActor in
                AnalyticsService.shared.trackDocumentUpdated(databaseType: connection.databaseType)
            }
        } catch {
            let duration = startTime.duration(to: .now)
            let durationMs = Int(duration.components.seconds * 1000 + duration.components.attoseconds / 1_000_000_000_000_000)

            recordQueryHistory(
                query: documentDescription,
                queryType: .update,
                source: .documentUpdate,
                databaseType: connection.databaseType,
                databaseName: connectedDatabase?.name,
                schemaName: databaseSchema,
                tableName: collectionName,
                executionDurationMs: durationMs,
                wasSuccessful: false,
                errorMessage: error.localizedDescription
            )

            throw error
        }
    }

    func deleteDocument(in collectionName: String, databaseSchema: String?, id: Any) async throws {
        guard let driver = activeDriver,
              let connection = activeConnection else {
            throw DatabaseError.operationFailed("No active database connection")
        }

        let startTime = ContinuousClock.now
        let documentDescription = "DELETE FROM \(collectionName) WHERE id = \(id)"

        do {
            try await driver.deleteDocument(in: collectionName, databaseSchema: databaseSchema, id: id)

            let duration = startTime.duration(to: .now)
            let durationMs = Int(duration.components.seconds * 1000 + duration.components.attoseconds / 1_000_000_000_000_000)

            recordQueryHistory(
                query: documentDescription,
                queryType: .delete,
                source: .documentDelete,
                databaseType: connection.databaseType,
                databaseName: connectedDatabase?.name,
                schemaName: databaseSchema,
                tableName: collectionName,
                executionDurationMs: durationMs,
                rowsAffected: 1,
                wasSuccessful: true
            )

            Task { @MainActor in
                AnalyticsService.shared.trackDocumentDeleted(databaseType: connection.databaseType)
            }

            clearDocumentCache(for: collectionName)
        } catch {
            let duration = startTime.duration(to: .now)
            let durationMs = Int(duration.components.seconds * 1000 + duration.components.attoseconds / 1_000_000_000_000_000)

            recordQueryHistory(
                query: documentDescription,
                queryType: .delete,
                source: .documentDelete,
                databaseType: connection.databaseType,
                databaseName: connectedDatabase?.name,
                schemaName: databaseSchema,
                tableName: collectionName,
                executionDurationMs: durationMs,
                wasSuccessful: false,
                errorMessage: error.localizedDescription
            )

            throw error
        }
    }
    
    // MARK: - Raw Query Execution
    func executeRawQuery(_ query: String, databaseSchema: String? = nil) async throws -> [QueryResult] {
        guard let driver = activeDriver,
              let connection = activeConnection else {
            throw DatabaseError.operationFailed("No active database connection")
        }

        let schemaToUse = databaseSchema ?? currentSchema
        let startTime = ContinuousClock.now

        do {
            let results = try await driver.executeRawQuery(query, databaseSchema: schemaToUse)
            let duration = startTime.duration(to: .now)
            let durationMs = Int(duration.components.seconds * 1000 + duration.components.attoseconds / 1_000_000_000_000_000)

            let totalRows = results.reduce(0) { $0 + $1.rows.count }

            recordQueryHistory(
                query: query,
                source: .sqlEditor,
                databaseType: connection.databaseType,
                databaseName: connectedDatabase?.name,
                schemaName: schemaToUse,
                executionDurationMs: durationMs,
                rowsAffected: totalRows,
                wasSuccessful: true
            )

            let queryType = AnalyticsService.detectQueryType(from: query)
            Task { @MainActor in
                AnalyticsService.shared.trackQueryExecuted(
                    databaseType: connection.databaseType,
                    queryType: queryType,
                    executionTimeMs: durationMs,
                    rowCount: totalRows,
                    success: true
                )
            }

            return results
        } catch {
            let duration = startTime.duration(to: .now)
            let durationMs = Int(duration.components.seconds * 1000 + duration.components.attoseconds / 1_000_000_000_000_000)

            recordQueryHistory(
                query: query,
                source: .sqlEditor,
                databaseType: connection.databaseType,
                databaseName: connectedDatabase?.name,
                schemaName: schemaToUse,
                executionDurationMs: durationMs,
                wasSuccessful: false,
                errorMessage: error.localizedDescription
            )

            let errorCategory = AnalyticsService.categorizeError(error)
            Task { @MainActor in
                AnalyticsService.shared.trackQueryFailed(
                    databaseType: connection.databaseType,
                    errorCategory: errorCategory
                )
            }

            throw error
        }
    }
    
    // MARK: - AI Operations
    func buildSystemPrompt(for collectionName: String, databaseSchema: String?) async throws -> String {
        guard let driver = activeDriver else {
            throw DatabaseError.operationFailed("No active database connection")
        }
        
        return try await driver.buildSystemPrompt(for: collectionName, databaseSchema: databaseSchema)
    }
    
    // MARK: - AI Operations
    func buildAICommandPromptSystemPrompt(_ message: String) async throws -> String {
        guard let driver = activeDriver else {
            throw DatabaseError.operationFailed("No active database connection")
        }
        
        return try await driver.buildAICommandPromptSystemPrompt(message)
    }
    
    // MARK: - Cache Management
    private func clearCache() {
        queryCache.removeAll()
    }
    
    private func clearDocumentCache(for collectionName: String) {
        let keysToRemove = queryCache.keys.filter { $0.hasPrefix(collectionName) }
        keysToRemove.forEach { queryCache.removeValue(forKey: $0) }
    }
    
    // MARK: - Getters for Current State
    var currentConnection: Connection? { activeConnection }
    var currentDatabase: (any DatabaseWrapper)? { connectedDatabase }
    var isConnected: Bool { activeDriver != nil && connectedDatabase != nil }
}
