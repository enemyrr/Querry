# Services/

## Purpose

Business logic layer. Services coordinate between the UI (Views/ViewControllers) and the data layer (Drivers/Models). They manage state, enforce rules, and handle cross-cutting concerns.

## Service Inventory

### Singletons (`.shared`)

| Service | Isolation | Purpose |
|---------|-----------|---------|
| `ConnectionService` | `@Observable` | Multi-connection instance lifecycle, active tab tracking |
| `TabManager` | `@Observable` | Tab creation/switching/closing, `PlukTab` array |
| `AnalyticsService` | `@MainActor final` | PostHog event tracking, first-event deduplication |
| `BookmarkManager` | None | macOS security-scoped bookmark management |
| `SidebarItemRegistry` | `@unchecked Sendable` | Sidebar item tracking, posts `.sidebarItemsDidChange` |
| `SparkleUpdaterManager` | `@MainActor NSObject` | App updates via Sparkle framework |

### Instance-Based (One Per Connection/Tab)

| Service | Isolation | Purpose |
|---------|-----------|---------|
| `DatabaseService` | `@Observable` | Per-connection DB operations, query execution, schema, caching |
| `TableDataController` | `@Observable @MainActor` | Per-tab table display logic, real-time subscriptions, CRUD |
| `QueryHistoryService` | `@MainActor @Observable` | Per-connection query recording with AES-GCM encryption |
| `SchemaModificationService` | `actor` | Transactional schema mutations (columns, indexes) |

### Stateless (Static Methods)

| Service | Purpose |
|---------|---------|
| `AIService` | OpenAI integration via AIProxy for SQL generation (gpt-4.1-mini) |
| `ERDSchemaReader` | Generates `CanvasDocument` from schema using Kahn's algorithm |
| `QueryHistoryEncryptionService` | AES-GCM encrypt/decrypt with per-connection keys |

## Key Dependency Graph

```
TableDataController
  ├─ ConnectionInstance (owns reference)
  ├─ DatabaseService (via instance)
  ├─ SchemaModificationService (created per-use)
  ├─ AnalyticsService.shared
  ├─ TableModificationTracker (row edits)
  └─ TableChangeDetector (real-time diffs)

ConnectionService.shared
  ├─ ConnectionInstance[] (owns all)
  ├─ SidebarItemRegistry.shared
  └─ WindowController

DatabaseService (per ConnectionInstance)
  ├─ QueryHistoryService? (weak ref)
  ├─ AnalyticsService.shared
  └─ any DatabaseDriver (active driver)
```

## TableDataController — Key Service

The most complex service. Manages everything for a single table tab:

- **Data loading**: `loadDocumentsIfNeeded()`, `loadOrSubscribe()`, `refreshData()`
- **CRUD**: `commitModifications()` — batch INSERT/UPDATE/DELETE
- **Schema CRUD**: `commitSchemaModifications()` — add/modify/drop columns
- **Filtering**: `updateFilterConditions()`, `generateInitialFilter()`
- **Real-time**: `subscribeToRealTimeUpdatesIfSupported()`, `handleRealTimeUpdate()`
- **Clipboard**: `parseClipboardContent()` (JSON or TSV)

Posts `.tableReloadData` notification (with tableName in userInfo).

## Invariants

- Singletons use `static let shared` with private `init()`
- `@Observable` classes require `@MainActor` in Swift 6
- `SchemaModificationService` is the only custom `actor` — enforces sequential schema changes
- `DatabaseService` is NOT annotated `@MainActor` but is `@Observable` — access it on main thread
- `QueryHistoryService` encrypts all stored queries with per-connection AES-GCM keys
- Never access `BookmarkManager` from a non-main context without `withSecurityScopedAccess()`
- `BedrockService.shared.warmUpCredentials()` warms the shared `CognitoCredentialManager` cache used by both `BedrockService` and `BedrockGLMService`; UI entry points that hit the GLM path can still call this helper before first request

## Anti-Patterns

- Do NOT create a second `ConnectionService` — always use `.shared`
- Do NOT call `DatabaseService` methods from background threads without proper isolation
- Do NOT bypass `SchemaModificationService` for schema changes — it handles transactions (BEGIN/COMMIT/ROLLBACK)
- Do NOT store passwords in `DatabaseService` — they live in Keychain via `Connection`
- Do NOT call `TableDataController.commitModifications()` without checking `modificationTracker` has changes

## Downlinks

- [Models](../Models/AGENTS.md) — SwiftData entities and @Observable state consumed by services
- [Protocols](../Protocols/AGENTS.md) — `DatabaseDriver` protocol used by `DatabaseService`
- [Core/ViewControllers](../Core/ViewControllers/AGENTS.md) — VCs that own and observe services
