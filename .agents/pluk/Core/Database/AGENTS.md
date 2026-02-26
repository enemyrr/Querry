# Core/Database/

## Purpose

Cross-cutting database utilities for type conversion, formatting, and introspection. These are **NOT driver implementations** — they're shared helpers used across multiple drivers and services.

## Distinction from Drivers/

| This directory (`Core/Database/`) | `Drivers/` directory |
|-----------------------------------|---------------------|
| BSON ↔ JSON conversion | PostgreSQL driver |
| SQL formatting | MySQL driver |
| SQLite file introspection | SQLite driver |
| MongoDB query helpers | MongoDB driver |
| Error types | Convex driver |

Think of `Core/Database/` as the **utility belt** and `Drivers/` as the **implementations**.

## File Inventory

| File | Purpose | Key API |
|------|---------|---------|
| `SQLFormatter.swift` | SQL formatting via JavaScriptCore | `SQLFormatter.format(sql, dialect:)` |
| `BSON2JSON.swift` | BSON → JSON serialization | `BSON2JSONSerializer().serialize(document:)` |
| `ExtendedJSONDecoder.swift` | Extended JSON → BSON conversion | `ExtendedJSONDecoder().decodeDocument(from:)` |
| `JSON+Decoder.swift` | Fast JSON parsing via yyjson C library | `JSONDecoder(data:).jsonKeyValuePairs()` |
| `BSON+Decimal128.swift` | Decimal128 type handling | Binary.SubType extensions |
| `SQLiteWALDetector.swift` | SQLite WAL mode detection | `SQLiteWALDetector.isInWALMode(at:)` |
| `MongoDBQueryHandler.swift` | MongoDB/BSON special types | `MongoKittenQueryHandler.parseDate()` |
| `BSONError.swift` | BSON error types | `BSONError.InvalidArgumentError` |
| `MongoError.swift` | MongoDB-specific errors | `MongoError.collectionNotFound` |

## SQLFormatter

Uses JavaScriptCore to run `sql-formatter.min.js`:
- Dialects: sqlite, postgresql, mysql, mariadb, bigquery, redshift, spark, snowflake, tsql, plsql
- Options: `tabWidth`, `useTabs`, `keywordCase`, `dataTypeCase`, `functionCase`, `linesBetweenQueries`
- Enums: `SQLDialect`, `TextCase` (preserve/upper/lower), `SQLFormatOptions`

## JSON Parsing

**Important**: `JSON+Decoder.swift` defines a custom `JSONDecoder` struct using yyjson C library for fast, order-preserving JSON parsing. This is why the project requires `Foundation.JSONDecoder()` for standard JSON decoding — the name collides.

Key methods:
- `json() throws -> Any` — Raw parsed result
- `jsonKeyValuePairs() throws -> [(key: String, value: Any)]` — Preserves key order (important for Extended JSON)

## SQLiteWALDetector

Reads SQLite file headers directly (no database connection needed):
- `isInWALMode(at: URL) -> Bool` — Checks writer version byte == 2
- `getSQLiteFileInfo(at: URL) -> SQLiteFileInfo?` — Full header info (page size, versions, counters)

## Invariants

- `SQLFormatter` loads JS once and reuses the context
- `JSONDecoder` here is NOT `Foundation.JSONDecoder` — always qualify Foundation usage
- BSON conversion preserves Extended JSON types ($oid, $date, $binary, $timestamp)
- `SQLiteWALDetector` reads raw bytes — no SQLite library dependency

## Anti-Patterns

- Do NOT use `JSONDecoder()` unqualified — it resolves to the custom yyjson wrapper, not Foundation
- Do NOT modify BSON conversion without understanding Extended JSON spec
- Do NOT assume `SQLFormatter` is synchronous everywhere — JavaScriptCore evaluation can be slow for large queries
- Do NOT put driver-specific logic here — driver code belongs in `Drivers/`

## Downlinks

- [Drivers](../../Drivers/AGENTS.md) — Driver implementations that consume these utilities
- [Protocols](../../Protocols/AGENTS.md) — DTO types that these utilities produce/consume
