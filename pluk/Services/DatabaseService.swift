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
    
    // MARK: - Results Cache
    private var queryCache: [String: QueryResult] = [:]
    
    // MARK: - Connection Management
    func setActiveConnection(_ connection: Connection) async throws {
        self.activeConnection = connection
        
        // Create appropriate driver
        self.activeDriver = DatabaseDriverFactory.createDriver(for: connection.databaseType)
        
        guard let driver = activeDriver else {
            throw DatabaseError.operationFailed("Failed to create database driver")
        }
        
        // Connect to database
        self.connectedDatabase = try await driver.connect(to: connection.connectionUri)
    }
    
    func switchActiveDatabase(to database: any DatabaseWrapper) async throws {
        guard let driver = activeDriver else {
            throw DatabaseError.operationFailed("No active database driver")
        }
        
        self.connectedDatabase = database
        try await driver.switchDatabase(to: database.name)
    }
    
    func disconnect() async {
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
    
    // MARK: - Database Operations
    func getBuildInfo() async throws -> BuildInfo? {
        guard let driver = activeDriver else { return nil }
        return try await driver.getBuildInfo()
    }
    
    func listDatabases() async throws -> [any DatabaseWrapper] {
        guard let driver = activeDriver else { return [] }
        
        // Use type erasure to handle different database types
        return try await driver.listDatabases().map { $0 as any DatabaseWrapper }
    }
    
    func listCollections() async throws -> [any CollectionWrapper] {
        guard let driver = activeDriver else { return [] }
        
        return try await driver.listCollections().map { $0 as any CollectionWrapper }
    }
    
    // MARK: - Document Operations
    func findDocuments(
        in collectionName: String,
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
                filter: ["rawQuery": filter],
                skip: skip,
                limit: limit,
                sortBy: sortBy,
                ascending: ascending
            )
            
        case .mongodb:
            result = try await driver.findDocuments(
                in: collectionName,
                filter: [:],
                skip: skip,
                limit: limit
            )
        }
        
        return result
    }
    
    /// Generates a filter query from conditions using the appropriate database driver
    func generateFilterQuery(from conditions: [FilterCondition], tableName: String) -> String {
        guard let driver = activeDriver,
              let connection = activeConnection else {
            return ""
        }
        
        switch connection.databaseType {
        case .postgres, .supabase, .convex, .sqlite:
            if let postgresDriver = driver as? PostgreSQLDriver {
                return postgresDriver.generateFilterQuery(from: conditions, tableName: tableName)
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
    
    func getSchema(for collectionName: String) async throws -> DatabaseSchemaResult? {
        guard let driver = activeDriver else { return nil }
        return try await driver.getSchema(for: collectionName)
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
    
    // MARK: - Collection Management
    func createCollection(named collectionName: String) async throws {
        guard let driver = activeDriver else {
            throw DatabaseError.operationFailed("No active database connection")
        }
        
        try await driver.createCollection(named: collectionName)
        clearCache() // Clear cache after structural changes
    }
    
    func renameCollection(from oldName: String, to newName: String) async throws {
        guard let driver = activeDriver else {
            throw DatabaseError.operationFailed("No active database connection")
        }
        
        try await driver.renameCollection(from: oldName, to: newName)
        clearCache() // Clear cache after structural changes
    }
    
    // MARK: - Document Modification
    func createDocument(in collectionName: String, document: [String: Any]) async throws {
        guard let driver = activeDriver else {
            throw DatabaseError.operationFailed("No active database connection")
        }
        
        try await driver.createDocument(in: collectionName, document: document)
        
        clearDocumentCache(for: collectionName)
    }
    
    func updateDocument(in collectionName: String, id: Any, data: [String: Any]) async throws {
        guard let driver = activeDriver else {
            throw DatabaseError.operationFailed("No active database connection")
        }
        
        try await driver.updateDocument(in: collectionName, id: id, data: data)
    }
    
    func deleteDocument(in collectionName: String, id: Any) async throws {
        guard let driver = activeDriver else {
            throw DatabaseError.operationFailed("No active database connection")
        }
        
        try await driver.deleteDocument(in: collectionName, id: id)
        
        clearDocumentCache(for: collectionName)
    }
    
    // MARK: - AI Operations
    func buildSystemPrompt(for collectionName: String) async throws -> String {
        guard let driver = activeDriver else {
            throw DatabaseError.operationFailed("No active database connection")
        }
        
        return try await driver.buildSystemPrompt(for: collectionName)
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
