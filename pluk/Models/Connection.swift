//
//  Connection.swift
//  Collection
//
//  Created by Fauzaan on 1/4/25.
//

import SwiftUI
import SwiftData

enum DatabaseType: String, Codable, CaseIterable, Sendable {
    var id: String { rawValue }
    
    case convex = "convex"
    case supabase = "supabase"
    // case neon = "neon"
    case postgres = "postgres"
    case mongodb = "MongoDB"
    case sqlite = "sqlite"
    case mysql = "mysql"
    
    var displayName: String {
        switch self {
        case .convex: return "Convex"
        case .supabase: return "Supabase"
        // case .neon: return "Neon"
        case .postgres: return "PostgreSQL"
        case .mongodb: return "MongoDB"
        case .mysql: return "MySQL"
        case .sqlite: return "SQLite"
        }
    }
    
    var accentColor: Color {
        switch self {
        case .convex: return Color(hex: "#8D2676")
        case .supabase: return Color(hex: "#3ECF8E")
        // case .neon: return Color(hex: "#00E599")
        case .postgres: return Color(hex: "#336791")
        case .mysql: return Color(hex: "#00546B")
        case .mongodb: return Color(hex: "#00ED64")
        case .sqlite: return Color(hex: "#003B57")
        }
    }
    
    var backgroundColor: Color {
        switch self {
        case .convex: return Color(hex: "#1E1B1A")
        case .supabase: return Color(hex: "#3ECF8E")
        // case .neon: return Color(hex: "#00E599")
        case .postgres: return Color(hex: "#346791")
        case .mysql: return Color(hex: "#00546B")
        case .mongodb: return Color(hex: "#021E2C")
        case .sqlite: return Color(hex: "#E6F0FA")
        }
    }
    
    var icon: String {
        switch self {
        case .convex: return "convex"
        case .supabase: return "supabase"
        // case .neon: return "neon"
        case .postgres: return "postgres"
        case .mongodb: return "mongodb"
        case .mysql: return "mysql"
        case .sqlite: return "sqlite"
        }
    }
    
    var homeIcon: String {
        switch self {
        case .convex: return "convex"
        case .supabase: return "supabase"
        // case .neon: return "neon"
        case .postgres: return "postgres"
        case .mongodb: return "mongodb"
        case .mysql: return "mysql.white"
        case .sqlite: return "sqlite"
        }
    }
    
    
    var status: DatabaseStatus {
        switch self {
        case .supabase:
            return .comingSoon
        default:
            return .available
        }
    }
    
    var placeholderURI: String {
        switch self {
        case .convex:
            return "postgresql://username:password@host:5432/database"
        case .supabase:
            return "postgresql://username:password@host:5432/database"
        // case .neon:
        //     return "postgresql://username:password@host:5432/database"
        case .postgres:
            return "postgresql://username:password@localhost:5432/database"
        case .mysql:
            return "mysql://username:password@localhost:3306/database"
        case .mongodb:
            return "mongodb+srv://user:password@cluster.mongodb.net"
        case .sqlite:
            return "sqlite:///path/to/database.db"
        }
    }
    
    var category: DatabaseCategory {
        switch self {
        case .convex, .supabase:
            return .cloud
        case .postgres, .mysql, .mongodb, .sqlite:
            return .database
        }
    }
    
    var dataModelType: DataModelType {
            switch self {
            case .mongodb:
                return .noSQL
            case .convex, .supabase, .postgres, .mysql, .sqlite:
                return .sql
            }
        }
    
    var supportsRealTime: Bool {
        switch self {
        case .convex:
            return true
        case .supabase, .postgres, .mysql, .sqlite, .mongodb:
            return false
        }
    }
}

enum DatabaseCategory: String, CaseIterable, Sendable {
    case cloud = "Cloud Providers"
    case database = "Database"
}

enum DatabaseStatus: Sendable {
    case available
    case beta
    case comingSoon
    case notConnected
}

enum ConnectionEnvironment: String, CaseIterable, Codable, Sendable {
    case local = "Local"
    case testing = "Testing"
    case development = "Development"
    case staging = "Staging"
    case production = "Production"
}

enum DataModelType: String, CaseIterable, Sendable {
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
    var environment: ConnectionEnvironment?
    var url: String?
    var defaultDatabase: String?
    var createdAt: Date = Date()
    var lastOpenedAt: Date = Date()
    var updatedAt: Date = Date()
    
    // New individual connection fields (optional for backward compatibility)
    var hostname: String?
    var port: String?
    var username: String?
    var sslMode: String?
    
    // Stable identifier for keychain storage (persists across app restarts)
    var keychainId: String = UUID().uuidString

    var containerName: String?
    var containerId: String?
    
    // Password is stored in keychain, not in database
    var password: String? {
        get {
            return KeychainHelper.shared.retrieve(for: keychainId)
        }
        set {
            if let newPassword = newValue, !newPassword.isEmpty {
                KeychainHelper.shared.store(password: newPassword, for: keychainId)
            } else {
                KeychainHelper.shared.delete(for: keychainId)
            }
        }
    }
    
    init(databaseType: DatabaseType, url: String, name: String, color: ConnectionColor, environment: ConnectionEnvironment, defaultDatabase: String? = nil) {
        self.name = name
        self.databaseType = databaseType
        self.url = url
        self.color = color
        self.environment = environment
        self.defaultDatabase = defaultDatabase
    }
    
    init(databaseType: DatabaseType, name: String, color: ConnectionColor, environment: ConnectionEnvironment?, hostname: String, port: String, username: String, database: String? = nil, sslMode: String? = "prefer") {
        self.name = name
        self.databaseType = databaseType
        self.color = color
        self.environment = environment
        self.defaultDatabase = database
        self.hostname = hostname
        self.port = port
        self.username = username
        self.sslMode = sslMode
        self.url = nil
    }
    
    var connectionUri: String {
        if databaseType == .convex {
            return password ?? ""
        }
        // If we have individual fields, construct URI from them (new approach)
        if let hostname = hostname, !hostname.isEmpty,
           let port = port, !port.isEmpty,
           let username = username, !username.isEmpty {
            return constructURIFromFields()
        }
        
        // Fallback to legacy URI construction (backward compatibility)
        if let database = defaultDatabase, !database.isEmpty {
            return "\(url ?? "")/\(database)"
        } else {
            return url ?? ""
        }
    }
    
    private func constructURIFromFields(encodeCredentials: Bool = true) -> String {
        guard let hostname = hostname, let port = port, let username = username else {
            return url ?? ""
        }

        let scheme: String
        switch databaseType {
        case .postgres, .supabase, .convex, .sqlite:
            scheme = "postgresql"
        case .mysql:
            scheme = "mysql"
        case .mongodb:
            scheme = "mongodb"
        }

        let resolvedHost = hostname.isEmpty ? "localhost" : hostname
        let resolvedPort = Int(port) ?? (databaseType == .mysql ? 3306 : 5432)

        var uri = "\(scheme)://"
        if !username.isEmpty {
            if encodeCredentials {
                uri += username.addingPercentEncoding(withAllowedCharacters: .urlUserAllowed) ?? username
            } else {
                uri += username
            }
            if let pwd = password, !pwd.isEmpty {
                if encodeCredentials {
                    uri += ":\(pwd.addingPercentEncoding(withAllowedCharacters: .urlPasswordAllowed) ?? pwd)"
                } else {
                    uri += ":\(pwd)"
                }
            }
            uri += "@"
        }

        uri += "\(resolvedHost):\(resolvedPort)"

        if let database = defaultDatabase, !database.isEmpty {
            let encodedDatabase = database.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? database
            uri += "/\(encodeCredentials ? encodedDatabase : database)"
        }

        if (databaseType == .postgres || databaseType == .supabase || databaseType == .convex),
           let sslMode = sslMode {
            uri += "?sslmode=\(sslMode)"
        }

        return uri
    }

    /// Returns a readable connection URI for display/copy purposes (no percent-encoding)
    var copyableConnectionUri: String {
        if databaseType == .convex {
            return password ?? ""
        }
        if let hostname = hostname, !hostname.isEmpty,
           let port = port, !port.isEmpty,
           let username = username, !username.isEmpty {
            return constructURIFromFields(encodeCredentials: false)
        }
        return url ?? ""
    }
    
    // Helper method to check if connection uses new field-based approach
    var usesFieldBasedConnection: Bool {
        return hostname != nil && port != nil && username != nil
    }
    
    // Helper method to check if password exists in keychain
    var hasPassword: Bool {
        return KeychainHelper.shared.passwordExists(for: keychainId)
    }
    
    var displayUrl: String? {
        if databaseType == .convex {
            return nil
        }
        
        // If we have individual fields, construct display URL from them
        if let hostname = hostname, !hostname.isEmpty,
           let port = port, !port.isEmpty,
           let username = username, !username.isEmpty {
            return constructDisplayURLFromFields()
        }
        
        // Special handling for SQLite bookmark URLs
        if databaseType == .sqlite, let url = url, !url.isEmpty {
            return extractSQLiteFilePath(from: url)
        }
        
        // Fallback to sanitizing existing URL (backward compatibility)
        if let url = url, !url.isEmpty {
            return sanitizeURLForDisplay(url)
        }
        
        return nil
    }
    
    private func constructDisplayURLFromFields() -> String {
        guard let hostname = hostname, let port = port, let username = username else {
            return "Invalid connection"
        }
        
        var components = URLComponents()
        
        switch databaseType {
        case .postgres, .supabase, .convex:
            components.scheme = "postgresql"
        case .mysql:
            components.scheme = "mysql"
        case .sqlite:
            components.scheme = "sqlLite"
        case .mongodb:
            components.scheme = "mongodb"
        }
        
        components.host = hostname
        components.port = Int(port)
        components.user = username
        
        // Show asterisks if password exists in keychain
        if hasPassword {
            components.password = "****"
        }
        
        // Add database path
        if let database = defaultDatabase, !database.isEmpty {
            components.path = "/\(database)"
        }
        
        return components.url?.absoluteString ?? "\(hostname):\(port)"
    }
    
    private func extractSQLiteFilePath(from url: String) -> String {
        // Check if this is a security-scoped bookmark URL
        if url.hasPrefix("bookmark:") {
            // Try to decode the bookmark to get the original file path
            let bookmarkString = String(url.dropFirst(9)) // Remove "bookmark:"
            let components = bookmarkString.components(separatedBy: "|")
            
            if components.count >= 2 {
                let encryptedPath = components[1]
                // Decrypt the path (matching BookmarkManager logic)
                if let decryptedPath = decryptPath(encryptedPath) {
                    return decryptedPath
                }
            }
        }
        
        // Handle other SQLite URL formats
        if url.hasPrefix("sqlite://") {
            let path = String(url.dropFirst(9)) // Remove "sqlite://"
            return path.isEmpty ? ":memory:" : path
        } else if url.hasPrefix("file:") {
            return String(url.dropFirst(5)) // Remove "file:"
        }
        
        // Return the original URL if we can't parse it
        return url
    }
    
    private func decryptPath(_ encryptedPath: String) -> String? {
        guard let data = Data(base64Encoded: encryptedPath),
              let saltedPath = String(data: data, encoding: .utf8) else {
            return nil
        }
        
        let salt = "PlukSecureBookmark2025"
        if saltedPath.hasPrefix(salt) && saltedPath.hasSuffix(salt) {
            let startIndex = saltedPath.index(saltedPath.startIndex, offsetBy: salt.count)
            let endIndex = saltedPath.index(saltedPath.endIndex, offsetBy: -salt.count)
            return String(saltedPath[startIndex..<endIndex])
        }
        
        return nil
    }
    
    private func sanitizeURLForDisplay(_ url: String) -> String {
        guard let urlComponents = URLComponents(string: url) else {
            return url // Return original if parsing fails
        }
        
        var sanitizedComponents = urlComponents
        
        // Replace password with asterisks if it exists
        if urlComponents.password != nil {
            sanitizedComponents.password = "****"
        }
        
        return sanitizedComponents.url?.absoluteString ?? url
    }
    
    // Clean up keychain when connection is deleted
    func cleanupKeychain() {
        KeychainHelper.shared.delete(for: keychainId)
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
        if databaseType == .postgres || databaseType == .supabase || databaseType == .convex {
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
