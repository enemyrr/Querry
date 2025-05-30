//
//  Connection.swift
//  Collection
//
//  Created by Fauzaan on 1/4/25.
//

import SwiftUI
import SwiftData

enum DatabaseType: String, Codable, CaseIterable {
    var id: String { rawValue }
    
    case supabase = "supabase"
    case neon = "neon"
    case postgres = "postgres"
    case mysql = "mysql"
    case mongodb = "MongoDB"
    case mariadb = "MariaDB"
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
    var color: ConnectionColor
    var environment: ConnectionEnvironment
    var url: String
    var defaultDatabase: String?
    var createdAt: Date = Date()
    var lastOpenedAt: Date = Date()
    var updatedAt: Date = Date()
    
    init(databaseType: DatabaseType, url: String, name: String, color: ConnectionColor, environment: ConnectionEnvironment, defaultDatabase: String? = nil) {
        self.name = name
        self.databaseType = databaseType
        self.url = url
        self.color = color
        self.environment = environment
        self.defaultDatabase = defaultDatabase
    }
    
    var connectionUri: String {
        if let database = defaultDatabase, !database.isEmpty {
            return "\(url)/\(database)"
        } else {
            return url
        }
    }
}

