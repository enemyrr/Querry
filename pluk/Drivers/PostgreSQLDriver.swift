import Foundation
import PostgresNIO

// MARK: - PostgreSQL Wrappers
struct PostgreSQLDatabaseWrapper: DatabaseWrapper {
    let name: String
}

struct PostgreSQLCollectionWrapper: CollectionWrapper {
    var id: ObjectIdentifier
    let name: String
}

// MARK: - PostgreSQL Driver
class PostgreSQLDriver: DatabaseDriver {
    typealias Database = PostgreSQLDatabaseWrapper
    typealias Collection = PostgreSQLCollectionWrapper
    typealias Document = [String: Any]
    typealias FormattedDocument = [String: Any]
    
    // Store connection and event loop group for proper cleanup
    private var connection: PostgresConnection?
    private var eventLoopGroup: MultiThreadedEventLoopGroup?
    private var isConnected = false
    
    // Connection configuration
    private var configuration: PostgresConnection.Configuration?
    
    deinit {
        // Ensure cleanup happens even if disconnect wasn't called explicitly
        // Capture the resources we need to clean up without capturing self
        let connection = self.connection
        let eventLoopGroup = self.eventLoopGroup
        
        Task { [connection, eventLoopGroup] in
            // Clean up the connection
            if let connection = connection {
                try? await connection.close()
            }
            
            // Clean up the event loop group
            if let eventLoopGroup = eventLoopGroup {
                try? await eventLoopGroup.shutdownGracefully()
            }
        }
    }
    
    func connect(to connectionUri: String) async throws -> PostgreSQLDatabaseWrapper {
        // Parse connection URI
        let config = try parseConnectionString(connectionUri)
        self.configuration = config
        
        // Create event loop group
        let eventLoopGroup = MultiThreadedEventLoopGroup(numberOfThreads: 1)
        self.eventLoopGroup = eventLoopGroup
        
        do {
            // Create and connect to PostgreSQL
            let connection = try await PostgresConnection.connect(
                on: eventLoopGroup.next(),
                configuration: config,
                id: 1,
                logger: Logger(label: "postgres")
            )
            
            self.connection = connection
            self.isConnected = true
            
            return PostgreSQLDatabaseWrapper(name: configuration?.database ?? "Default")
            
        } catch let error as PSQLError {
            await cleanup()
            throw mapPSQLError(error)
        } catch {
            await cleanup()
            throw DatabaseError.connectionFailed("Failed to establish PostgreSQL connection: \(error.localizedDescription)")
        }
    }
    
    func disconnect() async {
        await cleanup()
    }
    
    private func cleanup() async {
        if let connection = self.connection {
            try? await connection.close()
            self.connection = nil
        }
        
        if let eventLoopGroup = self.eventLoopGroup {
            try? await eventLoopGroup.shutdownGracefully()
            self.eventLoopGroup = nil
        }
        
        self.isConnected = false
    }
    
    private func ensureConnected() throws -> PostgresConnection {
            guard isConnected, let connection = self.connection else {
                throw DatabaseError.connectionFailed("Not connected to PostgreSQL database")
            }
            return connection
        }
    
    func getBuildInfo() async throws -> BuildInfo {
        let connection = try ensureConnected()
        do {
            let rows = try await connection.query("SELECT version()", logger: Logger(label: "postgres"))
            
            var fullVersionString = "Unknown"
            
            for try await (versionString) in rows.decode((String).self) {
                fullVersionString = versionString
            }
            
            guard let version = extractVersionNumber(from: fullVersionString) else {
                throw DatabaseError.operationFailed("Failed to extract build version")
            }
            
            return BuildInfo(
                version: version,
                databaseType: DatabaseType.postgres
            )
        } catch let error as PSQLError {
            throw mapPSQLError(error)
        } catch {
            throw DatabaseError.operationFailed("Failed to get build info: \(error.localizedDescription)")
        }
    }
    
    func listDatabases() async throws -> [PostgreSQLDatabaseWrapper] {
        let connection = try ensureConnected()
        
        do {
            let rows = try await connection.query(
                "SELECT datname FROM pg_database WHERE datistemplate = false",
                logger: Logger(label: "postgres")
            )
            
            var databases: [PostgreSQLDatabaseWrapper] = []
            
            for try await (name) in rows.decode((String).self) {
                databases.append(PostgreSQLDatabaseWrapper(name: name))
            }
            
            return databases
        } catch let error as PSQLError {
            throw mapPSQLError(error)
        } catch {
            throw DatabaseError.operationFailed("Failed to list databases: \(error.localizedDescription)")
        }
    }
    
    func listCollections() async throws -> [PostgreSQLCollectionWrapper] {
        let connection = try ensureConnected()
        
        do {
            let rows = try await connection.query(
                "SELECT tablename FROM pg_tables WHERE schemaname = 'public'",
                logger: Logger(label: "postgres")
            )
            
            var collections: [PostgreSQLCollectionWrapper] = []
            
            for try await (name) in rows.decode((String).self) {
                collections.append(PostgreSQLCollectionWrapper(
                    id: ObjectIdentifier(NSString(string: name)),
                    name: name
                ))
            }
            
            return collections
        } catch let error as PSQLError {
            throw mapPSQLError(error)
        } catch {
            throw DatabaseError.operationFailed("Failed to list tables: \(error.localizedDescription)")
        }
    }
    
    func getDocumentCount(for collectionName: String, filter: [String: Any]) async throws -> Int {
        throw DatabaseError.notImplemented("MySQL driver not yet implemented")
    }
    
    func findDocuments(in collectionName: String, filter: [String: Any]) async throws -> [[String: Any]] {
        throw DatabaseError.notImplemented("MySQL driver not yet implemented")
    }
    
    func createDocument(in collectionName: String, database: PostgreSQLDatabaseWrapper, document: [String: Any]) async throws {
        throw DatabaseError.notImplemented("MySQL driver not yet implemented")
    }
    
    func updateDocument(in collectionName: String, database: PostgreSQLDatabaseWrapper, id: Any, data: [String: Any]) async throws {
        throw DatabaseError.notImplemented("MySQL driver not yet implemented")
    }
    
    func deleteDocument(in collectionName: String, database: PostgreSQLDatabaseWrapper, id: Any) async throws {
        throw DatabaseError.notImplemented("MySQL driver not yet implemented")
    }
    
    func createCollection(named collectionName: String) async throws {
        throw DatabaseError.notImplemented("MySQL driver not yet implemented")
    }
    
    func renameCollection(from oldName: String, to newName: String) async throws {
        throw DatabaseError.notImplemented("MySQL driver not yet implemented")
    }
    
    // MARK: - Helper Methods
    private func parseConnectionString(_ urlString: String) throws -> PostgresConnection.Configuration {
        guard let url = URL(string: urlString),
              let host = url.host else {
            throw DatabaseError.configurationError("Invalid PostgreSQL URL format")
        }
        
        let port = url.port ?? 5432
        let username = url.user ?? "postgres"
        let password = url.password ?? ""
        let database = String(url.path.dropFirst()) // Remove leading "/"
        
        // Validate required fields
        if username.isEmpty {
            throw DatabaseError.configurationError("Username is required")
        }
        
        if database.isEmpty {
            throw DatabaseError.configurationError("Database name is required")
        }
        
        return PostgresConnection.Configuration(
            host: host,
            port: port,
            username: username,
            password: password.isEmpty ? nil : password,
            database: database,
            tls: .disable // You might want to make this configurable
        )
    }
    
    private func buildWhereClause(from filter: [String: Any]) -> String {
        guard !filter.isEmpty else { return "" }
        
        let conditions = filter.map { key, value in
            if let stringValue = value as? String {
                return "\(key) = '\(stringValue)'"
            } else if let numberValue = value as? NSNumber {
                return "\(key) = \(numberValue)"
            } else {
                return "\(key) = '\(value)'"
            }
        }
        
        return conditions.joined(separator: " AND ")
    }
    
    private func mapPSQLError(_ error: PSQLError) -> DatabaseError {
        // Check the specific error code first
        switch error.code {
        case .authMechanismRequiresPassword:
            return DatabaseError.authenticationFailed("Password required for authentication")
        case .unsupportedAuthMechanism:
            return DatabaseError.authenticationFailed("Unsupported authentication mechanism")
        case .saslError:
            return DatabaseError.authenticationFailed("SASL authentication failed")
        case .connectionError:
            return DatabaseError.connectionFailed("Cannot connect to PostgreSQL server")
        case .serverClosedConnection:
            return DatabaseError.connectionFailed("Server closed the connection")
        case .clientClosedConnection:
            return DatabaseError.connectionFailed("Client connection was closed")
        case .server:
            // For server errors, check the server info for more specific error details
            if let serverInfo = error.serverInfo {
                // Check SQL state for authentication errors
                if let sqlState = serverInfo[.sqlState] {
                    switch sqlState {
                    case "28000", "28P01": // Invalid authorization specification / Invalid password
                        return DatabaseError.authenticationFailed("Invalid username or password")
                    case "3D000": // Invalid catalog name (database does not exist)
                        return DatabaseError.connectionFailed("Database does not exist")
                    case "42501": // Insufficient privilege
                        return DatabaseError.authenticationFailed("Insufficient database privileges")
                    default:
                        break
                    }
                }
                
                // Use the error message from the server
                if let message = serverInfo[.message] {
                    return DatabaseError.operationFailed("PostgreSQL server error: \(message)")
                }
            }
            return DatabaseError.operationFailed("PostgreSQL server error")
        default:
            // For debugging, you can use: String(reflecting: error) to see full error details
            return DatabaseError.operationFailed("PostgreSQL error: \(error.code)")
        }
    }
    
    private func extractVersionNumber(from fullVersion: String) -> String? {
           let pattern = #"PostgreSQL\s+(\d+(?:\.\d+)*)"#
           
           do {
               let regex = try NSRegularExpression(pattern: pattern, options: [])
               let nsString = fullVersion as NSString
               let results = regex.matches(in: fullVersion, options: [], range: NSRange(location: 0, length: nsString.length))
               
               if let match = results.first,
                  match.numberOfRanges > 1 {
                   let versionRange = match.range(at: 1)
                   return nsString.substring(with: versionRange)
               }
           } catch {
               print("Regex failed for version extraction: \(error)")
           }
           
        return nil
    }
}

// MARK: - Utility Extensions

extension PostgreSQLDriver {
    /// Helper function to add timeout to async operations
    private func withTimeout<T>(seconds: TimeInterval, operation: @escaping () async throws -> T) async throws -> T? {
        try await withThrowingTaskGroup(of: T?.self) { group in
            group.addTask {
                try await operation()
            }
            
            group.addTask {
                try await Task.sleep(for: .seconds(seconds))
                return nil
            }
            
            if let result = try await group.next() {
                group.cancelAll()
                return result
            } else {
                group.cancelAll()
                return nil
            }
        }
    }
}

// MARK: - Database Error
enum DatabaseError: Error, LocalizedError {
    case notImplemented(String)
    case connectionFailed(String)
    case operationFailed(String)
    case authenticationFailed(String)
    case configurationError(String)
    
    var errorDescription: String? {
        switch self {
        case .notImplemented(let message):
            return "Not implemented: \(message)"
        case .connectionFailed(let message):
            return "Connection failed: \(message)"
        case .operationFailed(let message):
            return "Operation failed: \(message)"
        case .authenticationFailed(let message):
            return "Authentication failed: \(message)"
        case .configurationError(let message):
            return "Configuration error: \(message)"
        }
    }
}
