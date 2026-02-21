# AGENTS.md

This file provides guidance to AI coding agents when working with code in this repository.

## Project Overview

**Pluk** is a multi-database GUI client application for macOS built with SwiftUI and AppKit. It supports PostgreSQL, MySQL, SQLite, and MongoDB with AI-powered query assistance.

## Environment

- Target macOS 15.0 or later
- Swift 6.2 or later, using modern Swift concurrency
- Use AppKit for high-performance logic and smaller components, complex table views, custom drawing, and window management
- Do not introduce third-party frameworks without asking first

## Important

- Always ask the user to test the product and see if its working fine instead of you trying to build
- Do not add comments unless its complex or info that's needed for user reference
- Always use github cli instead of API

## GitHub Workflow

- Create issues on the public repo: `pluk-inc/Pluk`
- Create PRs on the private repo: `pluk-inc/app-pluk`
- Link PRs to issues using `Fixes pluk-inc/Pluk#<issue-number>`

## GitHub GraphQL API

- Never use deprecated Projects (classic) fields: `projectCards`, `ProjectCard`, `ProjectColumn`
- Always use ProjectsV2 API: `projectItems`, `ProjectV2Item`, `ProjectV2ItemFieldValue`
- Reference: https://docs.github.com/en/graphql/reference/objects#projectv2

## AppKit Hover State Rules

- Always use `.inVisibleRect` in NSTrackingArea options — never use `rect: bounds` alone
- Pattern: `NSTrackingArea(rect: .zero, options: [.mouseEnteredAndExited, .activeInActiveApp, .inVisibleRect], owner: self)`
- For views inside scroll views or that can be clipped/hidden, also add a `refreshHoverState()` method that checks
  `window.mouseLocationOutsideOfEventStream` and call it from `updateTrackingAreas()`
- Reference implementations: `BlockHoverTrackingView` and `FieldRowCell` in `ChartConfigController.swift`

### Search Tools

**Use ast-grep for syntax-aware searches**: When searching for code patterns, function definitions, or structural elements, use `sg --lang swift -p'<pattern>'` instead of text-based search tools. Only fall back to grep/text search when explicitly requested or for non-code content.

### Key Components

**Database Layer**: Protocol-based driver system in `Drivers/` with unified interface for multiple database types.

**Service Layer**: Centralized business logic in `Services/`:

- `DatabaseService.swift` - Core database operations
- `AIService.swift` - AI query assistance
- `ConnectionService.swift` - Connection management
- `TabManager.swift` - Multi-tab interface

**View Layer**: SwiftUI views using @Observable pattern:

- `SQLEditorView/` - Query editor with syntax highlighting
- `MainWindow.swift` - Primary interface
- `CreateConnection/` - Database setup
- `Documents/` - Data tables and editing

### Data Management

- **SwiftData** for persistence (Connection model)
- **Keychain** for secure credential storage
- **Security-scoped bookmarks** for SQLite file access

### Dependencies

Key frameworks integrated via Xcode project:

- Database drivers: PostgresNIO, MySQLNIO, SQLiteNIO, MongoKitten
- UI: CodeEditorView (syntax highlighting)
- Services: AIProxy, Sparkle (updates), PostHog (analytics), Sentry (errors)

## Architecture: AppKit

- Appkit is the default
- Use NSHostingController to embed SwiftUI views in AppKit
- Use NSViewRepresentable / NSViewControllerRepresentable to embed AppKit views in SwiftUI
- Keep clear boundaries between SwiftUI and AppKit layers

## Concurrency & Actors

- Always mark @Observable classes with @MainActor
- Assume strict Swift concurrency rules are being applied
- Never use old-style Grand Central Dispatch concurrency such as `DispatchQueue.main.async()`. Always use modern Swift concurrency
- Never use `Task.sleep(nanoseconds:)`; always use `Task.sleep(for:)` instead
- For database operations, use actors to ensure thread safety
- Use async/await for all I/O operations (network, file, database)

## Swift Preferences

- Prefer Swift-native alternatives to Foundation methods where they exist, such as using `replacing("hello", with: "world")` rather than `replacingOccurrences(of: "hello", with: "world")`
- Never use C-style number formatting such as `String(format: "%.2f", value)`; always use `formatted(.number.precision(.fractionLength(2)))` instead
- Prefer static member lookup to struct instances where possible, such as `.circle` rather than `Circle()`
- Filtering text based on user input must be done using `localizedStandardContains()` as opposed to `contains()`
- Avoid force unwraps and force try unless it is unrecoverable
- Use guard statements for early returns
- Prefer value types (structs, enums) over reference types unless shared mutable state is required
- use Foundation.JSONDecoder() instead of JSONDecoder() because i have my custom function name as JSONDecoder()

## AppKit Rules

- Prefer NSViewController over bare NSView for complex view hierarchies
- Use NSTableView with NSDiffableDataSource for high-performance lists
- Use NSOutlineView for tree structures and hierarchical data
- Implement NSTableViewDelegate and NSTableViewDataSource protocols properly
- Use Auto Layout programmatically; avoid Interface Builder for complex layouts
- For custom drawing, override `draw(_:)` and use NSGraphicsContext or Core Graphics
- Use CALayer for animations and visual effects requiring GPU acceleration
- Handle NSWindow lifecycle properly (`windowWillClose`, `windowDidBecomeKey`)
- Use NSToolbar for window toolbars; configure items programmatically
- For titlebar customization, use `titlebarAppearsTransparent` and `titleVisibility`
- Use NSSplitViewController for resizable split views with persistence
- Implement proper responder chain for keyboard shortcuts and menu actions
- Use NSMenu and NSMenuItem for context menus; wire up actions and `validateMenuItem`

## SwiftData Rules

- Never use `@Attribute(.unique)`
- Model properties must always either have default values or be marked as optional
- All relationships must be marked optional

## Performance Guidelines

- Profile with Instruments before optimizing
- Use Time Profiler for CPU bottlenecks
- Use Allocations for memory issues
- Avoid blocking the main thread; offload work to background actors
- Use lazy initialization for expensive objects
- Reuse cells in NSTableView; implement `makeView(withIdentifier:owner:)`
- Batch database operations when possible

## Critical Architecture Patterns

### Database Driver System

**Unified Query Interface**: All database drivers (MongoDB, PostgreSQL, MySQL, SQLite) implement the `DatabaseDriver` protocol defined in `pluk/Protocols/DatabaseDriver.swift`. This provides a consistent interface for:

- Connection management (`connect`, `disconnect`, `reconnect`, `ping`)
- CRUD operations (`findDocuments`, `createDocument`, `updateDocument`, `deleteDocument`)
- Schema introspection (`getSchema`, `getIndexes`)
- Real-time subscriptions (optional, database-dependent)

**QueryResult Standardization**: Database-specific results are converted to a unified `QueryResult` type containing:

- `rows: [[String: QueryRowInfo]]` - Formatted data for UI display
- `rawRows: [[String: Any?]]` - Raw data for lazy decoding
- `columns: [QueryColumnInfo]` - Column metadata

**Driver-Specific Implementations**:

- Each driver in `Drivers/` converts native database types to the unified format
- MongoDB uses `FormattedDocument` → `[String: QueryRowInfo]` conversion
- SQL databases convert result sets to the same unified format

### MongoDB-Specific Data Flow

**Document Display Pipeline**:

```
MongoDB Document
  ↓
formatDocument() → Document.FormattedDocument (preserves rawDocument)
  ↓
convertFormattedDocumentToRow() → [String: QueryRowInfo]
  ↓
DocumentRowView displays formatted data
```

**Metadata Pattern**: MongoDB documents store `FormattedDocument` metadata using special key `__formattedDocument` in the row dictionary. This preserves access to the raw MongoDB Document for operations like JSON export while displaying formatted data in the UI.

**Type Conversion**: `Document+Formatting.swift` contains formatting logic that:

- Converts BSON types (ObjectId, Binary, Date, etc.) to display strings
- Handles nested documents and arrays recursively
- Preserves type information via `FormattedPrimitive`

### Environment Object Hierarchy

Views access services through SwiftUI environment:

```swift
@Environment(ConnectionInstance.self) private var instance
@Environment(AppViewModel.self) private var appViewModel
```

**ConnectionInstance** provides:

- `databaseService: DatabaseService` - Core database operations
- `selectedTab: DatabaseTab?` - Current active collection/table
- `connection: Connection` - Connection metadata
- `databaseDriver` - Direct access to driver (use sparingly)

**DatabaseService** centralizes all database operations and should be used instead of calling drivers directly.

### Document Editing Architecture

**Two-Way Binding Pattern**: `DocumentEditView` uses `@Binding` to share state with parent `DocumentRowView`:

- User edits JSON in CodeEditor (via binding)
- Changes sync to parent's `@State var editingJSON`
- Save button triggers update via `DatabaseService.updateDocument()`
- MongoDB driver converts edited JSON → MongoDB Document → database

**State Management**:

- `pendingAction: DocumentAction?` - Tracks edit/delete mode
- Local state in view (not centralized view model)
- Direct database updates without batching

### Real-Time Subscriptions

Some drivers support real-time updates (e.g., Convex):

- `subscribeToCollectionChanges()` provides live data streams
- Views check `databaseService.supportsRealTime` before subscribing
- Subscription lifecycle managed at view level
- Cache clearing via `clearSubscriptionCache()`

### AI Integration Points

AI features integrated at multiple levels:

- **Query Generation**: `buildSystemPrompt()` and `buildAICommandPromptSystemPrompt()` in each driver
- **Error Suggestions**: AI analyzes query errors and suggests fixes
- **Natural Language**: CMD+K actions convert text to database queries
- **AIProxy Service**: Centralized AI API access via AIProxy library

### Testing

- Always ask the user to test the product and see if its working fine instead of you trying to build<D-s>
