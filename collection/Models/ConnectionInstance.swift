//
//  ConnectionInstance.swift
//  Collection
//
//  Created by Fauzaan on 1/21/25.
//

import Foundation
import MongoKitten
import SwiftUI
import AIProxy

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
    
    func findQueryBuilder(from collectionName: String, filter: Document = [:]) throws -> FindQueryBuilder {
        guard let collection = database?[collectionName] else {
            throw MongoError.collectionNotFound
        }
        
        return collection.find(filter)
    }
    
    // Parse a dictionary-like string into a Document
    private func parseFilterDictionary(_ dictString: String) -> Document {
        var document = Document()
        
        // Split by commas not inside nested structures
        let pairs = splitOutsideNested(dictString, separator: ",")
        
        for pair in pairs {
            // Split each pair by colon
            let keyValue = splitOutsideNested(pair, separator: ":")
            
            if keyValue.count >= 2 {
                let key = keyValue[0].trimmingCharacters(in: .whitespacesAndNewlines)
                    .replacingOccurrences(of: "\"", with: "")
                
                // Join the rest in case there are colons in the value
                let valueString = keyValue[1...].joined(separator: ":")
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                
                document[key] = parseValue(valueString)
            }
        }
        
        return document
    }
    
    // Split a string by a separator, but only when the separator is outside nested structures
    private func splitOutsideNested(_ string: String, separator: Character) -> [String] {
        var result: [String] = []
        var current = ""
        var bracketCount = 0
        var squareBracketCount = 0
        var inString = false
        
        for char in string {
            if char == "\"" && (current.last != "\\") {
                inString = !inString
            }
            
            if !inString {
                if char == "(" {
                    bracketCount += 1
                } else if char == ")" {
                    bracketCount -= 1
                } else if char == "[" {
                    squareBracketCount += 1
                } else if char == "]" {
                    squareBracketCount -= 1
                }
            }
            
            if char == separator && bracketCount == 0 && squareBracketCount == 0 && !inString {
                result.append(current.trimmingCharacters(in: .whitespacesAndNewlines))
                current = ""
            } else {
                current.append(char)
            }
        }
        
        if !current.isEmpty {
            result.append(current.trimmingCharacters(in: .whitespacesAndNewlines))
        }
        
        return result
    }
    
    // Parse a value string into a Primitive
    private func parseValue(_ valueString: String) -> Primitive {
        let trimmed = valueString.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Handle string literals
        if trimmed.hasPrefix("\"") && trimmed.hasSuffix("\"") {
            return String(trimmed.dropFirst().dropLast())
        }
        
        // Handle numbers
        if let intValue = Int(trimmed) {
            return intValue
        }
        
        if let doubleValue = Double(trimmed) {
            return doubleValue
        }
        
        // Handle boolean
        if trimmed == "true" {
            return true
        }
        if trimmed == "false" {
            return false
        }
        
        // Handle Date
        if trimmed.contains("Date()") {
            return Date()
        }
        
        // Handle nested dictionaries
        if trimmed.hasPrefix("[") && trimmed.hasSuffix("]") {
            // Check if it's an array or a dictionary
            let content = String(trimmed.dropFirst().dropLast())
                .trimmingCharacters(in: .whitespacesAndNewlines)
            
            // If it contains a colon outside quotes, it's likely a dictionary
//            if content.contains(":") {
//                return parseFilterDictionary(content)
//            } else {
//                // It's an array
//                let elements = splitOutsideNested(content, separator: ",")
//                return elements.map { parseValue($0) }
//            }
        }
        
        // Default
        return trimmed
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
