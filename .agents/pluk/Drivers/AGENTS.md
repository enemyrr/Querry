# Drivers/

## Purpose

Database-specific implementations of the `DatabaseDriver` protocol. Each driver translates the generic protocol into native database operations.

## Directory Structure

```
pluk/Drivers/
├── PostgreSQL/
│   ├── PostgreSQLDriver.swift          Main driver (89KB, largest)
│   ├── PostgreSQLDriver+Decode.swift   PostgresCell → QueryRowInfo
│   ├── PostgreSQLDriver+Encode.swift   Swift types → PostgresEncodable
│   ├── PostgreSQLFilterBuilder.swift   WHERE clause generation
│   ├── PostgreSQLConnectionStringParser.swift  URI parsing (17KB)
│   └── PostgresTimeOfDayValue.swift
├── MySQL/
│   ├── MySQLDriver.swift               Main driver (62KB)
│   ├── MySQLDriver+Decode.swift        MySQLData → QueryRowInfo
│   ├── MySQLDriver+Encode.swift        Swift types → MySQLData
│   └── MySQLFilterBuilder.swift
├── SQLite/
│   ├── SQLiteDriver.swift              Main driver (59KB)
│   └── SQLiteFilterBuilder.swift
├── Convex/
│   ├── ConvexDriver.swift              REST-based driver (67KB)
│   ├── ConvexFilterBuilder.swift       JSON FilterExpression (not SQL)
│   ├── Client/                         REST client (5 files)
│   └── ConvexMobile/                   FFI wrapper + xcframework
├── MongoDBDriver.swift                 Single file (24KB, mostly AI prompt)
├── MariaDBDriver.swift                 Stub — all methods throw notImplemented
└── Helpers/
    ├── Date+Timestamp.swift            Timestamp parsing (no timezone)
    └── Date+Timestampz.swift           Timezone-aware timestamp parsing
```

## File Naming Pattern

For each SQL database, the convention is:

| File | Purpose |
|------|---------|
| `{DB}Driver.swift` | Class definition, connection management, CRUD, schema, AI prompts |
| `{DB}Driver+Decode.swift` | Native DB type → `QueryRowInfo` conversion |
| `{DB}Driver+Encode.swift` | Swift type → native DB bindable type |
| `{DB}FilterBuilder.swift` | `FilterOperator` → database-specific WHERE clause |

## Per-Driver Wrapper Types

Each driver defines its own concrete wrappers:

| Driver | Database Wrapper | Collection Wrapper |
|--------|-----------------|-------------------|
| PostgreSQL | `PostgreSQLDatabaseWrapper` | `PostgreSQLCollectionWrapper` |
| MySQL | `MySQLDatabaseWrapper` | `MySQLCollectionWrapper` |
| SQLite | `SQLiteDatabaseWrapper` | `SQLiteCollectionWrapper` |
| MongoDB | `MongoDBWrapper` | `MongoCollectionWrapper` |
| Convex | `ConvexDatabaseWrapper` | `ConvexCollectionWrapper` |
| MariaDB | `MariaDBDatabaseWrapper` | `MariaDBCollectionWrapper` |

## Filter Builder Quirks

| Database | Identifier Quoting | ILIKE Support | Escape Character | Placeholders |
|----------|--------------------|---------------|-----------------|--------------|
| PostgreSQL | `"column"` (double quotes) | Native ILIKE | `''` (doubled) | `$1, $2...` |
| MySQL | `` `column` `` (backticks) | LIKE is case-insensitive | `\'` (backslash) | `?` |
| SQLite | `"column"` (double quotes) | `LOWER()` wrapper | `''` (doubled) | N/A |
| Convex | N/A (JSON) | N/A | N/A | N/A |

## Invariants

- Drivers maintain private connection objects and event loop groups
- Proper cleanup in `deinit` with graceful shutdown
- `Supabase` maps to `PostgreSQLDriver` in the factory
- All drivers return standardized `QueryRowInfo` regardless of native types
- AI prompt methods (`buildSystemPrompt`, `buildAICommandPromptSystemPrompt`) must return database-appropriate prompts

## Anti-Patterns

- Do NOT access driver connection objects from outside the driver — they are private
- Do NOT assume MariaDB works — it's a stub, all methods throw `notImplemented`
- Do NOT copy-paste filter builder logic between drivers — each handles escaping differently
- Do NOT add Convex-specific SQL — Convex uses JSON filter expressions, not SQL

## How to Add a New Database

1. Create a new directory: `pluk/Drivers/NewDB/`
2. Create `NewDBDriver.swift` conforming to `DatabaseDriver`
3. Define `NewDBDatabaseWrapper` and `NewDBCollectionWrapper`
4. Add `NewDBFilterBuilder.swift` for WHERE clause generation
5. Add Decode/Encode extensions if needed
6. Register in `DatabaseDriverFactory.createDriver(for:)` in `pluk/Protocols/DatabaseDriver.swift`
7. Add `DatabaseType` case in `pluk/Models/Connection.swift`

## Downlinks

- [Protocols](../Protocols/AGENTS.md) — The `DatabaseDriver` contract these implement
- [Core/Database](../Core/Database/AGENTS.md) — Cross-cutting utilities (BSON, JSON, SQL formatting)
