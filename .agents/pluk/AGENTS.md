# pluk/

## Purpose

Root source directory for Pluk — a multi-database GUI client for macOS supporting PostgreSQL, MySQL, SQLite, MongoDB, and Convex with AI-powered query assistance.

## Architecture Layers (Top → Bottom)

```
AppKit Layer        Core/Windows/, Core/ViewControllers/    Window management, tab routing, table display
SwiftUI Overlay     Views/                                  Feature screens, modals, leaf components
Service Layer       Services/                               Business logic, coordination, state
Model Layer         Models/                                 SwiftData entities, @Observable state, value types
Driver Layer        Drivers/                                Database-specific protocol implementations
Protocol Layer      Protocols/                              DatabaseDriver contract + shared DTOs
Shared/Utilities    Shared/, Utilities/                     Design system, code editor, helpers
Core/Database       Core/Database/                          BSON/JSON conversion, SQL formatting
```

## Entry Points

- `pluk/AppDelegate.swift` — @main entry, initializes SwiftData container (6 entities), PostHog, Sentry, Sparkle
- `pluk/Core/Windows/WindowController.swift` — NSWindowController for main window
- `pluk/Core/Windows/MainContentViewController.swift` — Root VC, routes home/connection/notebook

## Module Map

| Directory | What Lives Here |
|-----------|----------------|
| `Protocols/` | `DatabaseDriver` protocol — the central contract |
| `Drivers/` | Per-database implementations (Postgres, MySQL, SQLite, MongoDB, Convex, MariaDB) |
| `Services/` | Business logic: `DatabaseService`, `ConnectionService`, `TableDataController`, `AIService` |
| `Models/` | SwiftData entities + @Observable classes + value types |
| `Core/ViewControllers/` | AppKit view controllers (Document, Table, Sidebar, Notebook) |
| `Core/Windows/` | Window management (WindowController, MainContentVC) |
| `Core/Database/` | Cross-cutting DB utilities (BSON, JSON, SQL formatting) |
| `Views/` | Feature screens organized by domain (Documents, Notebook, Home, Settings, etc.) |
| `Shared/` | Design system components (buttons, dropdowns, tooltips, split views) |
| `Utilities/` | Code editor, keychain, pagination, string/date/color extensions |
| `Helpers/` | `AnyCodable` wrapper |
| `Extensions/` | NSView hover background, notification names |

## Invariants

- AppKit is the primary UI framework; SwiftUI is used for leaf views embedded via `NSHostingView`/`NSHostingController`
- All `@Observable` classes must be `@MainActor`
- Never use `DispatchQueue`; always use Swift concurrency (`async`/`await`, `Task`, actors)
- Never use `Task.sleep(nanoseconds:)`; use `Task.sleep(for:)` instead
- Never use `@Attribute(.unique)` in SwiftData models
- Use `Foundation.JSONDecoder()` instead of `JSONDecoder()` (custom function name collision)
- Use `localizedStandardContains()` for user-facing text filtering
- Prefer Swift-native string methods (`replacing()` not `replacingOccurrences(of:)`)
- Never use C-style formatting (`String(format:)`); use `.formatted()` instead

## Naming Collisions to Watch

1. **DocumentView.swift** — Contains class `TabContentView` (NSView router), NOT a SwiftUI view
2. **TabContent/DocumentView/** — Directory for MongoDB `DocumentList` (SwiftUI), unrelated to above
3. **Two Markdown parsers**: `Text/MarkdownParser.swift` (notebook text blocks) vs `Agent/Markdown/MarkdownBlockParser.swift` (agent output)
4. **TableListView** (SwiftUI orchestrator) vs **TableCoordinator** (AppKit NSTableView) — both in `TableListView/`
5. **Core/Database/** (utilities: BSON, JSON, formatting) vs **Drivers/** (protocol implementations)
6. **JSONDecoder()** — Custom function in project; always qualify with `Foundation.JSONDecoder()`

## Debugging Surprises

- The top-level workspace instructions reference `.agents/pluk/Core/Windows/AGENTS.md`, but that file is not currently present. Use this root architecture overview and `.agents/pluk/Core/ViewControllers/AGENTS.md` for nearby window/view-controller context until the Windows-specific file exists.
- `WindowController` windows render custom top chrome inside `.fullSizeContentView`, so custom bars such as `TabBarView` and notebook toolbar/header must explicitly preserve window drag and double-click zoom/minimize behavior if they should feel native.

## Downlinks

- [Protocols](Protocols/AGENTS.md) — DatabaseDriver contract
- [Drivers](Drivers/AGENTS.md) — Per-database implementations
- [Services](Services/AGENTS.md) — Business logic layer
- [Models](Models/AGENTS.md) — Data models
- [Core/ViewControllers](Core/ViewControllers/AGENTS.md) — AppKit VC hierarchy
- [Views](Views/AGENTS.md) — View layer overview
- [Shared](Shared/AGENTS.md) — Design system
- [Core/Database](Core/Database/AGENTS.md) — Database utilities
