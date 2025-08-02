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
        case .mongodb: return Color(hex: "#00ED64")
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
        case .postgres: return "postgres.pdf"
        case .mongodb: return "database.mongodb"
        case .mysql: return "mysql"
        case .mariadb: return "mariadb"
        }
    }
    
    var foregroundColor: Color {
        switch self {
        case .supabase: return Color(hex: "#3ECF8E")
        case .neon: return Color(hex: "#00E599")
        case .postgres: return Color(hex: "#FFFFFF")
        case .mysql: return Color(hex: "#00546B")
        case .mongodb: return Color(hex: "#00ED64")
        case .mariadb: return Color(hex: "#C39A6C")
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
    
    var dataModelType: DataModelType {
            switch self {
            case .mongodb:
                return .noSQL
            case .supabase, .neon, .postgres, .mysql, .mariadb:
                return .sql
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

enum DataModelType: String, CaseIterable {
    case sql = "SQL"
    case noSQL = "NoSQL"
    
    var description: String {
        switch self {
        case .sql:
            return "Structured data with predefined schema and relationships"
        case .noSQL:
            return "Flexible data models without fixed schema requirements"
        }
    }
}

@Model
final class Connection {
    var name: String
    var databaseType: DatabaseType
    var color: ConnectionColor
    var environment: ConnectionEnvironment
    var url: String?
    var defaultDatabase: String?
    var createdAt: Date = Date()
    var lastOpenedAt: Date = Date()
    var updatedAt: Date = Date()
    
    // New individual connection fields (optional for backward compatibility)
    var hostname: String?
    var port: String?
    var username: String?
    var password: String?
    var sslMode: String?
    
    init(databaseType: DatabaseType, url: String, name: String, color: ConnectionColor, environment: ConnectionEnvironment, defaultDatabase: String? = nil) {
        self.name = name
        self.databaseType = databaseType
        self.url = url
        self.color = color
        self.environment = environment
        self.defaultDatabase = defaultDatabase
    }
    
    // New initializer for field-based connections
    init(databaseType: DatabaseType, name: String, color: ConnectionColor, environment: ConnectionEnvironment, hostname: String, port: String, username: String, password: String? = nil, database: String? = nil, sslMode: String? = "prefer") {
        self.name = name
        self.databaseType = databaseType
        self.color = color
        self.environment = environment
        self.defaultDatabase = database
        
        // Store individual fields
        self.hostname = hostname
        self.port = port
        self.username = username
        self.password = password
        self.sslMode = sslMode
        
        // Set URL to nil for field-based connections (moving away from URL storage)
        self.url = nil
    }
    
    var connectionUri: String {
        // If we have individual fields, construct URI from them (new approach)
        if let hostname = hostname, !hostname.isEmpty,
           let port = port, !port.isEmpty,
           let username = username, !username.isEmpty {
            return constructURIFromFields()
        }
        
        // Fallback to legacy URI construction (backward compatibility)
        if let database = defaultDatabase, !database.isEmpty {
            return "\(String(describing: url))/\(database)"
        } else {
            return url ?? ""
        }
    }
    
    private func constructURIFromFields() -> String {
        guard let hostname = hostname, let port = port, let username = username else {
            return url ?? ""
        }
        
        var components = URLComponents()
        
        switch databaseType {
        case .postgres, .supabase, .neon:
            components.scheme = "postgresql"
        case .mysql, .mariadb:
            components.scheme = "mysql"
        case .mongodb:
            components.scheme = "mongodb"
        }
        
        components.host = hostname.isEmpty ? "localhost" : hostname
        components.port = Int(port) ?? (databaseType == .mysql || databaseType == .mariadb ? 3306 : 5432)
        components.user = username.isEmpty ? nil : username
        components.password = password?.isEmpty == true ? nil : password
        
        // Add database path
        if let database = defaultDatabase, !database.isEmpty {
            components.path = "/\(database)"
        }
        
        // Add SSL mode for PostgreSQL databases
        if (databaseType == .postgres || databaseType == .supabase || databaseType == .neon),
           let sslMode = sslMode, sslMode != "prefer" {
            components.queryItems = [URLQueryItem(name: "sslmode", value: sslMode)]
        }
        
        return components.url?.absoluteString ?? url ?? ""
    }
    
    // Helper method to check if connection uses new field-based approach
    var usesFieldBasedConnection: Bool {
        return hostname != nil && port != nil && username != nil
    }
    
    // Helper method to populate fields from existing URL (for migration)
    func populateFieldsFromURL() {
        guard let urlComponents = URLComponents(string: url ?? "") else { return }
        
        self.hostname = urlComponents.host
        self.port = urlComponents.port?.description
        self.username = urlComponents.user
        self.password = urlComponents.password
        
        // Parse database from path
        let path = urlComponents.path
        if !path.isEmpty && path != "/" {
            self.defaultDatabase = String(path.dropFirst()) // Remove leading "/"
        }
        
        // Parse SSL mode from query parameters (for PostgreSQL)
        if databaseType == .postgres || databaseType == .supabase || databaseType == .neon {
            if let queryItems = urlComponents.queryItems {
                for item in queryItems {
                    if item.name.lowercased() == "sslmode" {
                        self.sslMode = item.value ?? "prefer"
                        break
                    }
                }
            }
            if sslMode == nil {
                sslMode = "prefer" // Default value
            }
        }
    }
}

