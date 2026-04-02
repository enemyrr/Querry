# Models/

## Purpose

Data models organized into three categories: SwiftData persistent entities, @Observable runtime state, and plain value types (structs/enums).

## SwiftData Models (@Model)

Persisted via SwiftData. All registered in `AppDelegate`'s model container.

| Model | Key Properties | Notes |
|-------|---------------|-------|
| `Connection` | url, databaseType, keychainId, hostname, port | Password stored in Keychain (computed property), not SwiftData |
| `Notebook` | title, description, status (exploratory → production) | Container for blocks |
| `NotebookBlock` | blockType (.chart/.text), sortOrder, configJSON, blockHeight | Config stored as JSON string |
| `AgentChat` | title, createdAt | Groups agent messages |
| `AgentMessage` | role (.user/.assistant), content, feedback | feedback is computed (raw string ↔ enum) |
| `QueryHistoryEntry` | encryptedQuery, queryType, source, databaseType | Encrypted with AES-GCM |

### SwiftData Rules (CRITICAL)

- **Never** use `@Attribute(.unique)` — causes SwiftData crashes
- All properties must have default values OR be optional
- All relationships must be optional
- Use `Foundation.JSONDecoder()` not `JSONDecoder()` (name collision with custom function)

## @Observable Classes (Runtime State)

Not persisted. Track live application state.

| Class | Isolation | Purpose |
|-------|-----------|---------|
| `ConnectionInstance` | `@Observable` | Active connection: holds `DatabaseService`, tabs, collections, status |
| `DatabaseTab` | `@Observable` + Codable | Open tab state: name, viewMode, queryState. Custom Codable excludes transient fields |
| `AppViewModel` | `@MainActor @Observable final` | Global UI state: right sidebar visibility/width |
| `TableModificationTracker` | `@Observable` | Tracks cell/row edits for undo and batch commit |
| `SchemaModificationTracker` | `@Observable` | Tracks column/index changes for schema editor |

## Value Types (Structs/Enums)

### In Connection.swift
- `DatabaseType` — enum: postgres, mysql, sqlite, mongodb, convex, supabase, mariadb. Extensive computed properties: `displayName`, `accentColor`, `icon`, `dataModelType`, `supportsRealTime`
- `DatabaseCategory`, `DatabaseStatus`, `ConnectionEnvironment`, `DataModelType`

### In AppSettings.swift
- `AutoCompleteKey`, `IndentStyle`, `CSVDelimiter`, `CSVQuoteStyle`, `SyntaxTheme`, `AIProvider`, `AIModel`, `KeymapPreset`, etc.

### In ChartBlockConfig.swift
- `ChartBlockConfig` (Codable) — Full chart config: connection, table, fields, aggregations, filters, chartType
- `ChartType` — line, bar, area, horizontalBar, scatter, pie, histogram, pivotTable
- `AggregationFunction` — sum, avg, count, countDistinct, min, max, none. Has `sqlExpression` and `sqlAliasSuffix`
- `ChartFilterCondition` — field, operator, value with `sqlFragment` generation

### In ModificationTracker.swift
- `CellModification`, `RowModification`, `ModificationHistoryEntry`, `RowHistoryEntry`

### In StreamingPart.swift
- `StreamingPart` — enum: `.text(String)`, `.thinking(String)`, `.toolCall(id, name, displayText, iconName, isComplete, round)`

### Canvas/ subdirectory
- `CanvasDocument`, `CanvasNode`, `CanvasEdge`, `CanvasViewport` — all Codable structs for ERD visualization

## Invariants

- SwiftData models are `@Model final class` — always final
- `@Observable` classes must be `@MainActor` (Swift 6 strict concurrency)
- `Connection.password` is a computed property backed by Keychain — never persisted in SwiftData
- `DatabaseTab` custom Codable excludes transient properties (`selectedRowData`, `selectedRawRowData`, `selectedRowIndex`, `initialQuery`, etc.)
- `NotebookBlock.configJSON` stores serialized config — use `textContent` computed property for text blocks

## Anti-Patterns

- Do NOT add `@Attribute(.unique)` to any SwiftData model
- Do NOT store secrets in SwiftData properties — use Keychain
- Do NOT create SwiftData model properties without defaults — will crash on migration
- Do NOT make SwiftData relationships non-optional — will crash
- Do NOT access `DatabaseTab` transient properties after deserialization — they'll be nil/default
- When using `NotificationCenter.addObserver(forName:object:queue:using:)` inside runtime-state models like `ConnectionInstance`, store the returned token and remove that token in `deinit`; `removeObserver(self)` does not unregister block-based observers

## Downlinks

- [Services](../Services/AGENTS.md) — Services that own and mutate these models
- [Protocols](../Protocols/AGENTS.md) — DTOs like `QueryResult`, `DatabaseSchemaInfo` defined there
