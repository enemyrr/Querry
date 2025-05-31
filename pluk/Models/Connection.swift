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
    case mongodb = "MongoDB"
    case mysql = "mysql"
    case mariadb = "mariadb"
    
    var displayName: String {
        switch self {
        case .supabase: return "Supabase"
        case .neon: return "Neon"
        case .postgres: return "PostgreSQL"
        case .mongodb: return "MongoDB"
        case .mysql: return "MySQL"
        case .mariadb: return "MariaDB"
        }
    }
    
    var accentColor: Color {
        switch self {
        case .supabase: return Color(hex: "#3ECF8E")
        case .neon: return Color(hex: "#00E599")
        case .postgres: return Color(hex: "#336791")
        case .mysql: return Color(hex: "#00546B")
        case .mongodb: return Color(hex: "#07EB65")
        case .mariadb: return Color(hex: "#C39A6C")
        }
    }
    
    var backgroundColor: Color {
        switch self {
        case .supabase: return Color(hex: "#3ECF8E")
        case .neon: return Color(hex: "#00E599")
        case .postgres: return Color(hex: "#346791")
        case .mysql: return Color(hex: "#00546B")
        case .mongodb: return Color(hex: "#021E2C")
        case .mariadb: return Color(hex: "#C39A6C")
        }
    }
    
    var icon: String {
        switch self {
        case .supabase: return "supabase"
        case .neon: return "neon"
        case .postgres: return "postgres"
        case .mongodb: return "mongodb"
        case .mysql: return "mysql"
        case .mariadb: return "mariadb"
        }
    }
    
    var status: DatabaseStatus {
        switch self {
        case .mongodb:
            return .beta
        case .neon, .supabase, .mysql, .mariadb:
            return .comingSoon
        default:
            return .available
        }
    }
    
    var placeholderURI: String {
        switch self {
        case .supabase:
            return "postgresql://username:password@host:5432/database"
        case .neon:
            return "postgresql://username:password@host:5432/database"
        case .postgres:
            return "postgresql://username:password@localhost:5432/database"
        case .mysql:
            return "mysql://username:password@localhost:3306/database"
        case .mongodb:
            return "mongodb+srv://user:password@cluster.mongodb.net"
        case .mariadb:
            return "mariadb://username:password@localhost:3306/database"
        }
    }
    
    var category: DatabaseCategory {
        switch self {
        case .supabase, .neon:
            return .cloud
        case .postgres, .mysql, .mongodb, .mariadb:
            return .database
        }
    }
}

enum DatabaseCategory: String, CaseIterable {
    case cloud = "Cloud Providers"
    case database = "Database"
}

enum DatabaseStatus {
    case available
    case beta
    case comingSoon
    case notConnected
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

