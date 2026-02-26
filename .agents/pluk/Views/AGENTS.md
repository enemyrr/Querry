# Views/

## Purpose

Feature-level UI screens organized by domain. Mix of pure SwiftUI views and AppKit view controllers. Directory structure follows features, not framework boundaries.

## Directory Map

| Directory | Type | Purpose |
|-----------|------|---------|
| `Documents/` | Hybrid | Tab bar, tab content routing, table viewer, MongoDB documents |
| `Notebook/` | AppKit + SwiftUI cells | Block-based notebook editor, AI agent, charts |
| `Home/` | SwiftUI | App home screen, workspace list, recents |
| `Settings/` | AppKit window + SwiftUI panes | Singleton settings window, preference panes |
| `Sidebar/` | SwiftUI | Connection details sidebar, schema selector, feedback form |
| `SQLEditorView/` | SwiftUI | SQL query editor, AI command prompt |
| `Canvas/` | AppKit | ERD viewer with custom NSView drawing |
| `CreateConnection/` | SwiftUI | Connection wizard with per-driver forms |
| `CreateDatabase/` | SwiftUI | Database creation dialog |
| `FunctionEditorView/` | SwiftUI | Stored procedure editor |
| `QueryHistory/` | SwiftUI | Query history panel |
| `CheckForUpdates/` | SwiftUI | App update modal |
| `Splits/` | AppKit | Custom split view divider |
| `Windows/` | SwiftUI | About window |

## AppKit vs SwiftUI Boundaries

**Rule**: AppKit owns windows, navigation, and high-performance table rendering. SwiftUI is used for forms, modals, and leaf components.

### AppKit Controllers in Views/

- `Canvas/CanvasViewController.swift` — Custom NSView drawing for ERD
- `Notebook/NotebookViewController.swift` — Notebook root VC
- `Notebook/Content/NotebookContentController.swift` — Notebook layout
- `Settings/SettingsWindowController.swift` — Singleton NSWindowController

### Pure SwiftUI

- `Home/HomeView.swift` — Entry via `NSHostingController` from `MainContentViewController`
- `CreateConnection/`, `CreateDatabase/`, `QueryHistory/`, `CheckForUpdates/`
- Most Settings panes (GeneralSettingsView, KeymapSettingsView, etc.)
- `FloatingActionBar/` components (16 files)

## Navigation Flow

```
MainContentViewController
├── .home → NSHostingController(HomeView)
├── .notebook → NotebookViewController
└── .connection → DocumentViewController
    ├── TabBarView (AppKit, draggable)
    └── Per-tab content:
        ├── SQL DB table → TableContentViewController (AppKit)
        ├── SQL editor → TabContentView → NSHostingView(SQLEditorView)
        ├── Function editor → TabContentView → NSHostingView(FunctionEditorView)
        ├── MongoDB → TabContentView → NSHostingView(DocumentList)
        └── Canvas/ERD → TabContentView → CanvasViewController
```

## Naming Collisions

1. **`Documents/DocumentView.swift`** — Contains class `TabContentView` (an NSView router). NOT a SwiftUI View despite the filename.
2. **`Documents/TabContent/DocumentView/`** — Directory containing `DocumentList.swift` for MongoDB. Unrelated to the file above.
3. **Settings is a singleton** — `SettingsWindowController.shared` persists across app lifecycle; don't create new instances.

## Invariants

- AppKit VCs in `Views/` follow same patterns as `Core/ViewControllers/` (observation, environment injection)
- All SwiftUI views embedded in AppKit must receive environment injection
- Settings window is a singleton NSWindowController — use `SettingsWindowController.shared`
- `FloatingActionBar` is a mega-component (14 files) — it manages filtering, pagination, query execution, and schema modifications

## Downlinks

- [Documents](Documents/AGENTS.md) — Tab management, table viewer
- [Notebook](Notebook/AGENTS.md) — Notebook system
- [Notebook/Agent](Notebook/Agent/AGENTS.md) — AI agent subsystem
- [Notebook/Chart](Notebook/Chart/AGENTS.md) — Chart visualization
- [Documents/TabContent/TableListView](Documents/TabContent/TableListView/AGENTS.md) — Core table viewer
- [Shared](../Shared/AGENTS.md) — Design system components used by views
- [Core/ViewControllers](../Core/ViewControllers/AGENTS.md) — AppKit VCs that host these views
