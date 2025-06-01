# Database Driver Architecture

This document describes the new scalable database driver architecture implemented in Pluk, which allows for easy addition of new database types without changing the core business logic.

## Architecture Overview

The database driver architecture uses a protocol-based approach with the following key components:

### 1. Core Protocol (`DatabaseDriver`)
Located in `pluk/Protocols/DatabaseDriver.swift`, this protocol defines the interface that all database drivers must implement:

```swift
protocol DatabaseDriver {
    associatedtype Database
    associatedtype Collection  
    associatedtype Document
    
    // Connection management
    func connect(to connectionUri: String) async throws -> Database
    func disconnect() async
    func getBuildInfo() async throws -> BuildInfo
    
    // Database operations
    func listDatabases() async throws -> [Database]
    func listCollections() async throws -> [Collection]
    
    // Collection operations
    func getDocumentCount(for collectionName: String, in database: Database) async throws -> Int
    func findDocuments(in collectionName: String, database: Database, filter: [String: Any]) async throws -> [Document]
    func createDocument(in collectionName: String, database: Database, document: [String: Any]) async throws
    func updateDocument(in collectionName: String, database: Database, id: Any, data: [String: Any]) async throws
    func deleteDocument(in collectionName: String, database: Database, id: Any) async throws
    
    // Collection management
    func createCollection(named collectionName: String, in database: Database) async throws
    func renameCollection(from oldName: String, to newName: String, in database: Database) async throws
}
```

### 2. Driver Factory (`DatabaseDriverFactory`)
The factory pattern creates the appropriate driver based on the database type:

```swift
class DatabaseDriverFactory {
    static func createDriver(for databaseType: DatabaseType) -> any DatabaseDriver {
        switch databaseType {
        case .mongodb:
            return MongoDBDriver()
        case .postgres, .supabase, .neon:
            return PostgreSQLDriver()
        case .mysql:
            return MySQLDriver()
        case .mariadb:
            return MariaDBDriver()
        }
    }
}
```

### 3. Wrapper Protocols
Generic wrapper protocols abstract database-specific types:

- `DatabaseWrapper`: Wraps database objects with a common `name` property
- `CollectionWrapper`: Wraps collection objects with a common `name` property

## Current Implementation Status

### ✅ MongoDB Driver (`pluk/Drivers/MongoDBDriver.swift`)
- **Status**: Fully implemented and functional
- **Dependencies**: MongoKitten, MongoCore
- **Features**: Complete CRUD operations, collection management, build info

### 🚧 PostgreSQL Driver (`pluk/Drivers/PostgreSQLDriver.swift`)
- **Status**: Placeholder implementation
- **Next Steps**: Implement using a PostgreSQL Swift client like PostgresKit or PostgresNIO

### 🚧 MySQL Driver (`pluk/Drivers/MySQLDriver.swift`)
- **Status**: Placeholder implementation  
- **Next Steps**: Implement using MySQLKit or similar Swift MySQL client

### 🚧 MariaDB Driver (`pluk/Drivers/MariaDBDriver.swift`)
- **Status**: Placeholder implementation
- **Next Steps**: Implement using MySQL-compatible client

## Adding a New Database Driver

### Step 1: Create Driver Implementation
Create a new file `pluk/Drivers/YourDatabaseDriver.swift`:

```swift
import Foundation
import YourDatabaseSDK

// MARK: - Database Wrappers
struct YourDatabaseWrapper: DatabaseWrapper {
    let database: YourDatabaseType
    var name: String { database.name }
}

struct YourCollectionWrapper: CollectionWrapper {
    let collection: YourCollectionType
    var name: String { collection.name }
}

// MARK: - Your Database Driver
class YourDatabaseDriver: DatabaseDriver {
    typealias Database = YourDatabaseWrapper
    typealias Collection = YourCollectionWrapper
    typealias Document = YourDocumentType
    
    private var connectedDatabase: YourDatabaseType?
    
    func connect(to connectionUri: String) async throws -> YourDatabaseWrapper {
        // Implement connection logic
        let database = try await YourDatabaseType.connect(connectionUri)
        self.connectedDatabase = database
        return YourDatabaseWrapper(database: database)
    }
    
    func disconnect() async {
        // Implement disconnection logic
        await connectedDatabase?.disconnect()
        connectedDatabase = nil
    }
    
    // Implement other required methods...
}
```

### Step 2: Add to Factory
Update `DatabaseDriverFactory` in `pluk/Protocols/DatabaseDriver.swift`:

```swift
static func createDriver(for databaseType: DatabaseType) -> any DatabaseDriver {
    switch databaseType {
    case .mongodb:
        return MongoDBDriver()
    case .yourNewDatabase:
        return YourDatabaseDriver()
    // ... other cases
    }
}
```

### Step 3: Update DatabaseType Enum
Add your database type to the `DatabaseType` enum in `pluk/Models/Connection.swift`.

## Migration Strategy

The current implementation maintains backward compatibility with existing MongoDB code while introducing the new driver architecture:

### Phase 1: ✅ Core Architecture (Current)
- Implement driver protocol and factory
- Create MongoDB driver implementation
- Update ConnectionInstance to use drivers
- Maintain MongoDB backward compatibility

### Phase 2: 🚧 Additional Drivers
- Implement PostgreSQL driver
- Implement MySQL driver  
- Implement MariaDB driver
- Test multi-database functionality

### Phase 3: 🔮 Legacy Code Migration
- Gradually migrate MongoDB-specific code to use generic driver interface
- Remove direct MongoKitten dependencies from business logic
- Standardize document/data representations

## Error Handling

The architecture uses a common `DatabaseError` enum for driver-specific errors:

```swift
enum DatabaseError: Error, LocalizedError {
    case notImplemented(String)
    case connectionFailed(String)
    case operationFailed(String)
}
```

## Testing Strategy

Each driver should include:
- Unit tests for all protocol methods
- Integration tests with real database instances
- Mock implementations for UI testing

## Benefits of This Architecture

1. **Scalability**: Easy to add new database types
2. **Maintainability**: Common interface reduces code duplication
3. **Testability**: Protocol-based design enables easy mocking
4. **Flexibility**: Database-specific optimizations within common interface
5. **Backward Compatibility**: Existing MongoDB code continues to work

## Future Considerations

- **Connection Pooling**: Driver-level connection management
- **Schema Discovery**: Auto-detect table/collection structures
- **Query Builder**: Generic query building interface
- **Migration Tools**: Data migration between database types
- **Performance Monitoring**: Driver-specific metrics and monitoring 