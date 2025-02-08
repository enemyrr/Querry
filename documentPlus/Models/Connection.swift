//
//  Connection.swift
//  DocumentPlus
//
//  Created by Fauzaan on 1/4/25.
//

import SwiftUI
import SwiftData

enum DatabaseType: String, Codable {
    case mongodb = "MongoDB"
}

enum ConnectionEnvironment: String, CaseIterable, Codable {
    case local = "Local"
    case testing = "Testing"
    case development = "Development"
    case staging = "Staging"
    case production = "Production"
}


@Model
final class Connection {
    var name: String
    var databaseType: DatabaseType
    var color: Optional<String>
    var environment: Optional<ConnectionEnvironment>
    var url: String
    var createdAt: Date = Date()
    var lastOpenedAt: Date = Date()
    var updatedAt: Date = Date()
    
    init(databaseType: DatabaseType, url: String, name: String, color: Optional<String> = nil, environment: Optional<ConnectionEnvironment>) {
        self.name = name
        self.databaseType = databaseType
        self.url = url
        self.color = color
        self.environment = environment
    }
}

