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

### Current Work Context
Branch `8-feature-sql-editor-view-with-new-tab-integration` suggests active SQL editor improvements with AI integration and multi-tab functionality.