# Views/Documents/TabContent/TableListView/

## Purpose

Core table viewer for browsing database tables. Contains BOTH the SwiftUI fallback path AND the AppKit primary path components. This is the most performance-critical UI in the app.

## Naming Collision Warning

Two parallel paths exist for table viewing:

| Component | Framework | Used When |
|-----------|-----------|-----------|
| **TableCoordinator** | Pure AppKit | Primary path — SQL databases via `TableContentViewController` |
| **TableListView** | SwiftUI | Fallback path — MongoDB, or when accessed via `TabContentView` |

Both live in this directory but serve different entry points.

## Directory Structure

```
pluk/Views/Documents/TabContent/TableListView/
├── TableListView.swift                 SwiftUI orchestrator (state, loading, filtering)
├── TableListViewController.swift       NSViewRepresentable bridge (SwiftUI → AppKit)
├── TableCoordinator.swift              NSTableView delegate/datasource (pure AppKit)
├── TableCoordinator+Menu.swift         Context menu implementation
├── ViewModes/
│   ├── TableViewModeContainer.swift    Routes between content/schema/definition modes
│   ├── ContentModeView.swift           Data viewing mode → calls TableListViewController
│   ├── DefinitionModeView.swift        Table definition (read-only)
│   └── SchemaModeView/                 Schema editor (6 files, add/modify/drop columns)
├── Components/                         11 files — cell renderers, popovers, badges
└── FilterBuilderView/                  4 files — query filter UI
```

## Two Entry Paths

### Path 1: AppKit (Primary) — via TableContentViewController

```
DocumentViewController
  → TableContentViewController (creates TableDataController)
    → TableCoordinator (created directly, no NSViewRepresentable)
      → setupTableView() returns NSScrollView
    → NSHostingView(FilterBarContainer) — SwiftUI filter bar
    → NSHostingView(FloatingBarContainer) — SwiftUI floating action bar
```

`TableDataController` (in `pluk/Services/`) holds all business logic.

### Path 2: SwiftUI (Fallback) — via TabContentView

```
TabContentView (NSView)
  → NSHostingView(TableListView)
    → TableListView (SwiftUI, holds @State business logic)
      → TableViewModeContainer
        → ContentModeView
          → TableListViewController (NSViewRepresentable)
            → TableCoordinator (via makeCoordinator())
```

`TableListView` itself holds the business logic as @State properties.

## TableCoordinator

The core AppKit table renderer (`NSTableViewDelegate` + `NSTableViewDataSource`):
- Manages `CustomTableView` (NSTableView subclass)
- Cell types: checkbox, text, enum, foreign key, null indicator
- Column width caching per table
- Sorting state management
- Row selection and quick-look popover
- Context menu (copy, paste, delete, export)
- Modification tracking integration (undo/redo)
- `isSidebarAnimating` flag — guards against redraws during sidebar collapse

Key methods:
- `setupTableView() -> NSView` — Creates and returns the scroll view
- `updateRows(_:newSchema:)` — Refreshes table data
- `updateHighlighting(fields:rows:)` — Real-time change highlighting

## View Modes

`DatabaseTab.ViewMode` enum controls what's displayed:

| Mode | View | Purpose |
|------|------|---------|
| `.content` | ContentModeView → TableCoordinator | Table data with filtering |
| `.schema` | SchemaModeView + SchemaTableCoordinator | Editable columns/indexes |
| `.definition` | DefinitionModeView | Read-only table definition |

## TableListViewState

Enum defined in `TableListView.swift`, also used by `TableDataController`:
```swift
enum TableListViewState {
    case loading
    case error(String)
    case loaded(QueryResult, DatabaseSchemaResult)
}
```

## Invariants

- `TableCoordinator` is used by BOTH paths — it's the shared AppKit renderer
- In the AppKit path, `TableCoordinator` is created directly (not via NSViewRepresentable)
- In the SwiftUI path, `TableCoordinator` is created via `makeCoordinator()`
- Column widths are cached and restored per table
- Real-time highlighting uses `updatedFields` and `updatedRows` sets

## Anti-Patterns

- Do NOT confuse `TableListView` (SwiftUI state holder) with `TableCoordinator` (AppKit renderer)
- Do NOT use the SwiftUI path for new SQL database features — use the AppKit `TableContentViewController` path
- Do NOT modify `TableCoordinator` during sidebar animation — check `isSidebarAnimating`
- Do NOT bypass `TableDataController` for data operations in the AppKit path
- Quick Look JSON formatting is display-only; when saving from the popover, preserve the tracker’s true original/current cell values and never treat the prettified string as the canonical value

## Downlinks

- [Services](../../../../Services/AGENTS.md) — `TableDataController` business logic
- [Documents](../../AGENTS.md) — Parent context (tab routing, floating action bar)
