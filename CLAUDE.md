# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**Pluk** is a multi-database GUI client application for macOS built with SwiftUI. It supports PostgreSQL, MySQL, SQLite, and MongoDB with AI-powered query assistance.

## Development Commands

### Building
```bash
# Standard release build (ARM64 only)
./scripts/build.sh

# Debug build
./scripts/build.sh --configuration Debug

# Build with code signing
./scripts/build.sh --sign

# Beta/pre-release build
IS_PRERELEASE_BUILD=YES ./scripts/build.sh
```

### Testing
- Unit tests: `PlukTests` target
- UI tests: `PlukUITests` target 
- **Note**: Do not attempt to run the Xcode project for testing - manual testing only

### Version Management
- Version configuration: `pluk/version.xcconfig`
- Current version: 0.0.1-beta.20 (build 271)
- Bundle ID: doc.pluk

## Architecture

### Core Structure
```
pluk/
├── Core/           # Database core, models, extensions
├── Drivers/        # Database-specific drivers (PostgreSQL, MySQL, SQLite, MongoDB)
├── Services/       # Business logic (DatabaseService, AIService, ConnectionService, TabManager)
├── Views/          # SwiftUI views organized by feature
├── Models/         # SwiftData models (Connection.swift is primary)
├── Shared/         # Reusable UI components
└── Utilities/      # Helper functions
```

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

### AI Integration
Active development area with components in `Views/SQLEditorView/`:
- `AICommandPrompt.swift` - Natural language query input
- `AIErrorSuggestionPopup.swift` - Error correction suggestions
- `AIService.swift` - AI service coordination

### Build System
- **Primary scheme**: "Collection" (builds Pluk.app)
- **Output**: `build/Build/Products/<Configuration>/Pluk.app`
- **Architecture**: ARM64 only (Apple Silicon)
- **Signing**: Automated via `scripts/codesign-app.sh`

### Development Patterns
- **MVVM**: SwiftUI + @Observable view models
- **Protocol-oriented**: Database drivers implement common protocols
- **Environment injection**: Services provided via SwiftUI environment
- **Security-first**: Keychain integration, SSL/TLS support

### Search Tools
**Use ast-grep for syntax-aware searches**: When searching for code patterns, function definitions, or structural elements, use `sg --lang swift -p'<pattern>'` instead of text-based search tools. Only fall back to grep/text search when explicitly requested or for non-code content.

## Swift/SwiftUI Best Practices for AI-Generated Code

When writing or reviewing code, watch for these common issues in AI-generated Swift/SwiftUI code and apply modern best practices:

### SwiftUI Modifiers & APIs
- ❌ `foregroundColor()` → ✅ `foregroundStyle()` (supports gradients, not deprecated)
- ❌ `cornerRadius()` → ✅ `clipShape(.rect(cornerRadius:))` (more features, not deprecated)
- ❌ `onChange()` with 1 parameter → ✅ Accept two parameters or none (old variant is unsafe)
- ❌ `tabItem()` → ✅ Use new `Tab` API (type-safe selection, better features)
- ❌ `onTapGesture()` → ✅ Use `Button` instead (better VoiceOver/accessibility support)
- ❌ `NavigationView` → ✅ `NavigationStack` (unless supporting iOS 15)
- ❌ Inline destination `NavigationLink` in lists → ✅ `navigationDestination(for:)`

### State Management
- ❌ `ObservableObject` → ✅ `@Observable` macro (simpler, faster, unless you need Combine)
- ❌ Computed properties for view breakdown → ✅ Separate SwiftUI views (better performance with @Observable)
- ❌ `DispatchQueue.main.async` overuse → ✅ Use Swift concurrency properly
- ❌ Unnecessary `@MainActor` in new projects → ✅ Main actor isolation is on by default

### SwiftData
- ⚠️ `@Attribute(.unique)` does not work with CloudKit - avoid if using CloudKit sync

### Typography & Layout
- ❌ `.font(.system(size:))` with fixed sizes → ✅ Use Dynamic Type fonts (`.body`, `.title`, etc.)
- ❌ For iOS 26+: Use `.font(.body.scaled(by: 1.5))` for relative sizing
- ❌ Over-using `fontWeight()` → ✅ Remember `fontWeight(.bold)` ≠ `bold()`
- ❌ `GeometryReader` overuse → ✅ Consider `visualEffect()` or `containerRelativeFrame()`
- ❌ Fixed frame sizes everywhere → ✅ Use flexible layouts

### Buttons & Labels
- ❌ `Label` for button labels → ✅ Inline API: `Button("Tap me", systemImage: "plus", action: ...)`
- ❌ Image-only buttons → ✅ Include text labels for VoiceOver

### Data & Collections
- ❌ `ForEach(Array(x.enumerated()), id: \.element.id)` → ✅ `ForEach(x.enumerated(), id: \.element.id)`
- ❌ Long code to find documents directory → ✅ `URL.documentsDirectory`

### Concurrency & Async
- ❌ `Task.sleep(nanoseconds:)` → ✅ `Task.sleep(for: .seconds(1))`

### Formatting & Rendering
- ❌ C-style formatting: `String(format: "%.2f", value)` → ✅ `Text(value, format: .number.precision(.fractionLength(2)))`
- ❌ `UIGraphicsImageRenderer` for SwiftUI → ✅ `ImageRenderer`

### Code Organization
- ⚠️ Avoid placing many types in a single file - guarantees longer build times
- ⚠️ Watch for hallucinated APIs that look good but don't exist

**Target Platform**: This project targets modern iOS (iOS 18+), so use the latest APIs without backwards compatibility workarounds.

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