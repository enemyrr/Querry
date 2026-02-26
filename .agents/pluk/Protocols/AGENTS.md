# Protocols/

## Purpose

Defines `DatabaseDriver` — the single most important contract in the codebase. Every database (Postgres, MySQL, SQLite, MongoDB, Convex) implements this protocol. Also defines `DatabaseWrapper`, `CollectionWrapper`, and all shared DTOs.

## Entry Points

- `pluk/Protocols/DatabaseDriver.swift` — The only file. Contains the protocol, wrappers, DTOs, and factory.

## DatabaseDriver Protocol

Generic protocol with two associated types:
```
associatedtype Database: DatabaseWrapper
associatedtype Collection: CollectionWrapper
```

### Required Methods (All Drivers Must Implement)

| Category | Method | Notes |
|----------|--------|-------|
| **Connection** | `connect() async throws -> Database` | |
| | `disconnect() async` | |
| | `reconnect() async throws` | |
| | `ping() async throws` | Lightweight check, no state mutation |
| | `getBuildInfo() async throws -> BuildInfo` | Version + database type |
| | `switchDatabase(_:) async throws` | |
| **Listing** | `listDatabases() async throws -> [Database]` | |
| | `getDatabaseMetadata() async throws -> [Database]` | |
| | `listCollections(database:schema:) async throws -> [Collection]` | |
| **Documents** | `getDocumentCount(collection:filter:schema:) async throws -> Int` | |
| | `findDocuments(...)` | 3 overloads with different pagination params |
| | `createDocument(...)` | |
| | `updateDocument(...)` | |
| | `deleteDocument(...)` | |
| **Query** | `executeRawQuery(query:schema:) async throws -> [QueryResult]` | |
| **Schema** | `getSchema(collection:schema:) async throws -> DatabaseSchemaResult` | |
| | `getInformationSchema(database:) async throws -> [InformationSchema]` | |
| | `getIndexes(collection:schema:) async throws -> [DatabaseIndexInfo]` | |
| **Collections** | `createCollection(...)`, `renameCollection(...)`, `deleteCollection(...)` | |
| **AI** | `buildSystemPrompt(...)`, `buildAICommandPromptSystemPrompt(...)` | For CMD+K query assistance |

### Optional Methods (Default Throws NotImplemented)

| Method | Typical Usage |
|--------|---------------|
| `getCurrentDeploymentUrl()` | Convex environments only (returns nil by default) |
| `subscribeToCollectionChanges(...)` | Real-time subscriptions (Convex, partial MongoDB) |
| `clearSubscriptionCache()` | Clears subscription state |
| `createDatabase(...)` | SQL-only |
| `createSchema(...)` | SQL-only |
| `addColumn(...)` | SQL-only schema modification |
| `modifyColumn(...)` | SQL-only schema modification |
| `dropColumn(...)` | SQL-only schema modification |
| `createIndex(...)` | SQL-only index management |
| `dropIndex(...)` | SQL-only index management |

### Supporting Types (Same File)

- `DatabaseWrapper` — protocol: `name`, `size?`, `tableCount?`
- `CollectionWrapper` — protocol: `name`, `type`, `schema?` (Identifiable)
- `QueryResult` — columns (`[QueryColumnInfo]`), rows (`[[QueryRowInfo]]`), total count, raw rows
- `QueryColumnInfo` — name, type, format, index
- `QueryRowInfo` — value (`Any?`), dataType, format
- `DatabaseSchemaResult` — schema info array with convenience filters
- `DatabaseSchemaInfo` — ordinal, name, type, nullable, constraints, defaults, etc.
- `ConstraintInfo` — type (FK/PK/unique/check/exclusion/trigger), columns, foreign key refs
- `DatabaseIndexInfo` — name, type, columns, unique, partial, etc.
- `BuildInfo` — version string + DatabaseType
- `CreateDatabaseOptions` / `CreateSchemaOptions` — creation parameters

### DatabaseDriverFactory

```swift
class DatabaseDriverFactory {
    static func createDriver(for databaseType: DatabaseType) -> any DatabaseDriver
}
```
Maps: MongoDB, PostgreSQL, Supabase → PostgreSQLDriver, Convex, MySQL, SQLite

## Invariants

- All methods are `async throws` — use Swift concurrency exclusively
- The protocol itself has NO actor isolation — thread safety must be ensured at call sites
- `any DatabaseDriver` erases associated types — use when storing heterogeneous drivers
- Optional methods throw `DatabaseError.notImplemented` by default — never crash on unsupported operations
- Every driver must implement AI prompt methods for CMD+K feature

## Anti-Patterns

- Do NOT add `@MainActor` to the protocol — database operations run off main thread
- Do NOT force unwrap `QueryRowInfo.value` — values can be `nil` (SQL NULL)
- Do NOT assume all drivers support schema modification — check before calling optional methods
- Do NOT add new required methods without providing default implementations — breaks all existing drivers

## How to Add a New Driver

1. Create a new file/directory in `pluk/Drivers/`
2. Define `Database: DatabaseWrapper` and `Collection: CollectionWrapper` concrete types
3. Implement all required methods
4. Add case to `DatabaseDriverFactory.createDriver(for:)` in this file
5. Add `DatabaseType` case in `pluk/Models/Connection.swift`

## Downlinks

- [Drivers](../Drivers/AGENTS.md) — Where implementations live
- [Services](../Services/AGENTS.md) — `DatabaseService` consumes drivers
