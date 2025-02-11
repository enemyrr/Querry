//
//  DatabaseTab.swift
//  Collection
//
//  Created by Fauzaan on 1/22/25.
//

import Foundation
import SwiftUI
import MongoKitten

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
