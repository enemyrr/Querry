//
//  DatabaseViewModel.swift
//  DocumentPlus
//
//  Created by Fauzaan on 1/1/25.
//
import Foundation
import MongoKitten
import SwiftUI

struct ProcessedDocument {
    let originalDocument: Document
    let formattedValues: [String: String]
    let valueColors: [String: Color]
    
    static func processDocument(_ document: Document) -> ProcessedDocument {
        var formattedValues: [String: String] = [:]
        var valueColors: [String: Color] = [:]
        
        for key in document.keys {
            formattedValues[key] = formatValue(document[key], key: key)
            valueColors[key] = getValueColor(document[key])
        }
        
        return ProcessedDocument(
            originalDocument: document,
            formattedValues: formattedValues,
            valueColors: valueColors
        )
    }
    
    // Move the formatting logic here
    private static func formatValue(_ value: Primitive?, key: String) -> String {
        guard let value = value else { return "null" }
        
        switch value {
        case let objectId as ObjectId:
            return "ObjectId('\(objectId.hexString)')"
        case let array as [Primitive]:
            return "Array (\(array.count))"
        case let date as Date:
            return date.ISO8601Format()
        case let bool as Bool:
            return bool.description
        case let doc as Document:
            return "Document {\(doc.count) fields}"
        case let double as Double:
            return String(double)
        case let int as Int32:
            return String(int)
        case let int as Int:
            return String(int)
        case let string as String:
            return string
        default:
            return String(describing: value)
        }
    }
    
    private static func getValueColor(_ value: Primitive?) -> Color {
        guard let value = value else { return .gray }
        
        switch value {
        case is Int, is Int32, is Int64, is Double:
            return .blue
        case is String:
            return .orange
        case is Bool:
            return .green
        case is [Primitive]:
            return .gray
        case is Document:
            return .purple
        case is Date:
            return .blue
        case is ObjectId:
            return .orange
        default:
            return .white
        }
    }
}

@MainActor
final class DatabaseProvider: ObservableObject {
    static let shared = DatabaseProvider()
    
    @Published private(set) var collections: [MongoCollection] = []
    @Published private(set) var currentDocuments: [ProcessedDocument] = []
    @Published private(set) var error: Error?
    @Published private(set) var isConnected: Bool = false
    
    private let mongoManager: MongoManager = .shared
    
    func setupDatabase(connectionString: String = "mongodb://localhost:27017/jurifyte", databaseName: String = "jurifyte") async {
        do {
            try await mongoManager.connect(connectionString: connectionString)
            isConnected = true
        } catch {
            print(error)
            self.error = error
        }
    }
    
    func fetchCollections() async -> [MongoCollection] {
        do {
            self.collections = try await mongoManager.getCollections()
        } catch {
            print(self.error)
            self.error = error
        }
        
        return self.collections
    }
    
    func getDocuments(collectionName: String) async {
        do {
            let documents = try await mongoManager.getDocuments(from: collectionName)
            self.currentDocuments = documents.map { ProcessedDocument.processDocument($0) }
        } catch {
            self.error = error
        }
    }
    
    func getDocumentsAsync(byCollectionName collectionName: String) async -> [ProcessedDocument] {
        let documents = try? await mongoManager
            .getDocuments(from: collectionName)
            .map { ProcessedDocument.processDocument($0) }
        
        return documents ?? []
    }
}
