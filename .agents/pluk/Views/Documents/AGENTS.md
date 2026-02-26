# Views/Documents/

## Purpose

Document/table viewer area — manages the tab bar, routes tab content to the appropriate view, and handles the floating action bar and right sidebar.

## Directory Structure

```
pluk/Views/Documents/
├── DocumentView.swift              ⚠️ MISNAMED — contains class TabContentView (NSView router)
├── TabBar.swift                    Tab icon mapping + legacy tab implementation
├── TabBarView.swift                AppKit tab bar with drag-and-drop (1114 lines)
├── DatabaseSelectorModal.swift     Database/schema picker modal
├── FloatingActionBar/              14 files — filtering, pagination, query, schema ops
├── RightSidebar/                   Row detail panels
└── TabContent/
    ├── DocumentView/               MongoDB document viewer
    │   ├── DocumentList.swift      SwiftUI view for MongoDB documents
    │   └── DocumentRow/            5 files — row rendering variants
    └── TableListView/              SQL table viewer (see dedicated AGENTS.md)
```

## Tab Routing

`DocumentViewController` (in `pluk/Core/ViewControllers/`) routes each tab:

```
DocumentViewController.makeTabContentView(tab)
  ↓
  IF table-type tab (browse/aggregate/schema/indexes)
     AND database IN (postgres, sqlite, mysql, convex):
    → TableContentViewController (AppKit-native path)
  ↓
  ELSE:
    → TabContentView (SwiftUI fallback path)
      ├── SQL editor → NSHostingView(SQLEditorView)
      ├── Function editor → NSHostingView(FunctionEditorView)
      ├── MongoDB → NSHostingView(DocumentList)
      └── Canvas/ERD → CanvasViewController
```

## Naming Collision Warning

**`DocumentView.swift`** does NOT contain a view called DocumentView:
- **File**: `DocumentView.swift` — Contains class `TabContentView` (an NSView that routes tab content)
- **Directory**: `TabContent/DocumentView/` — Contains `DocumentList` (SwiftUI MongoDB document viewer)

These are completely unrelated despite sharing the name.

## TabBarView (AppKit)

High-performance AppKit tab bar (`TabBarView.swift`, 1114 lines):
- Drag-to-reorder with smooth animations and auto-scroll
- Custom `DraggableTabNSView` with snapshot during drag
- Keyboard shortcuts: Cmd+W close, Cmd+T new tab, Shift+Cmd+[/] navigate
- Sidebar collapse animation tracking via `isSidebarAnimating` flag

## FloatingActionBar

Mega-component (14 files) that provides contextual controls below the table:
- `FloatingActionBar.swift` — Main coordinator
- `ContentModeActionBar.swift` — For table data mode (pagination, add row, save/discard)
- `SchemaModeActionBar.swift` — For schema editing mode
- `QueryEditor.swift` — Inline SQL query editor
- `CommandPalette.swift` — Cmd+K AI command palette
- `AISearchView.swift` — AI-powered search

## Invariants

- `TabBarView` is pure AppKit — no SwiftUI
- `FloatingActionBar` communicates with `TableDataController` for mutations
- MongoDB uses SwiftUI `DocumentList` path — NOT the AppKit `TableContentViewController`
- Right sidebar shows row details when `appViewModel.isRightSidebarVisible` is true

## Anti-Patterns

- Do NOT search for "DocumentView" expecting a single class — there's a file and a directory with the same name
- Do NOT add MongoDB to the `TableContentViewController` routing — it has a different data model
- Do NOT modify `TabBarView` without testing drag-and-drop — it has complex animation state

## Downlinks

- [TabContent/TableListView](TabContent/TableListView/AGENTS.md) — Core table viewer
- [Core/ViewControllers](../../Core/ViewControllers/AGENTS.md) — `DocumentViewController` that owns this
