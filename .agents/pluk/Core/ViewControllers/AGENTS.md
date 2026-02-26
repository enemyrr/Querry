# Core/ViewControllers/

## Purpose

AppKit-first view controller hierarchy that owns the main application UI. These VCs replaced earlier pure-SwiftUI navigation during the AppKit migration. SwiftUI views are embedded as leaves via `NSHostingView`/`NSHostingController`.

## Hierarchy

```
WindowController (pluk/Core/Windows/)
└── MainContentViewController (pluk/Core/Windows/)
    ├── NavigationSidebarViewController     Left sidebar (connections, notebooks)
    └── Content area (switches by tab type):
        ├── NSHostingController(HomeView)   For .home tabs
        ├── NotebookViewController          For .notebook tabs (in Views/Notebook/)
        └── DocumentViewController          For .connection tabs
            ├── TabBarView (AppKit)         Draggable tab bar
            ├── NSTabView                   Invisible tab switcher
            │   ├── TableContentViewController   For SQL table tabs (Postgres/MySQL/SQLite/Convex)
            │   │   ├── NSHostingView(FilterBarContainer)
            │   │   ├── TableCoordinator.tableView (pure AppKit)
            │   │   └── NSHostingView(FloatingBarContainer)
            │   └── TabContentView (NSView)      For SQL editor, MongoDB, function editor, canvas
            └── NSHostingView(RowDetailSidebar)  Right sidebar
```

## Key Files

| File | Class | Purpose |
|------|-------|---------|
| `pluk/Core/ViewControllers/DocumentViewController.swift` | `DocumentViewController` | Tab management, right sidebar, tab sync with `ConnectionInstance` |
| `pluk/Core/ViewControllers/TableContentViewController.swift` | `TableContentViewController` | Table display: owns `TableDataController` + `TableCoordinator` |
| `pluk/Core/ViewControllers/NavigationSidebarViewController.swift` | `NavigationSidebarViewController` | Sidebar buttons, context menus, selection state |

Also relevant (in other directories):
- `pluk/Core/Windows/MainContentViewController.swift` — Root VC, background styling, routes by tab type
- `pluk/Core/Windows/WindowController.swift` — NSWindowController lifecycle
- `pluk/Views/Notebook/NotebookViewController.swift` — Notebook VC (separate hierarchy)

## Migration Status

| Component | Status | Framework |
|-----------|--------|-----------|
| MainContentViewController | Complete | AppKit |
| DocumentViewController | Complete | AppKit |
| TableContentViewController | Complete | AppKit + SwiftUI leaves |
| NavigationSidebarViewController | Complete | AppKit |
| TableCoordinator | Complete | Pure AppKit |
| SQL Editor tabs | SwiftUI fallback | SwiftUI via TabContentView |
| MongoDB tabs | SwiftUI fallback | SwiftUI via DocumentList |
| Home screen | SwiftUI | NSHostingController |

## Patterns

### Observation (withObservationTracking)

All VCs observe `@Observable` objects using re-registration pattern:

```swift
private func observeTabs() {
    withObservationTracking {
        _ = self.instance.tabs
        _ = self.instance.selectedTab
    } onChange: {
        Task { @MainActor in
            self.handleTabsChanged()
            self.observeTabs()  // Re-register — CRITICAL
        }
    }
}
```

DocumentViewController observes: `instance.tabs`, `instance.selectedTab`, `appViewModel.isRightSidebarVisible`
TableContentViewController observes: `dataController.viewState`, `dataController.updatedFields`, `dataController.filterConditions`, `tab.viewMode`, error states

### Environment Injection (AppKit → SwiftUI)

Before wrapping any SwiftUI view in `NSHostingView`, inject all environments:

```swift
private func injectEnvironments<V: View>(_ view: V) -> some View {
    view
        .environment(instance)
        .environment(appViewModel)
        .environment(sidebarViewModel)
        .environment(tabManager)
        .environment(\.currentDatabaseType, instance.connection.databaseType)
        .modelContainer(modelContainer)
}
```

### @Bindable Bridge

SwiftUI wrapper structs convert `@Observable` to `@Bindable` for two-way binding:

```swift
private struct FilterBarContainer: View {
    @Bindable var dataController: TableDataController
    var body: some View { FilterBuilderView(...) }
}
```

### TableCoordinator Direct Instantiation

In the AppKit path, `TableCoordinator` is created directly (no `NSViewRepresentable`):

```swift
let coordinator = TableCoordinator(schema: ..., queryResult: ..., callbacks: ...)
let scrollView = coordinator.setupTableView()
contentArea.addSubview(scrollView)
```

## Invariants

- Tab routing in `DocumentViewController.makeTabContentView()` checks database type — SQL databases get `TableContentViewController`, others get `TabContentView` (SwiftUI fallback)
- Every `withObservationTracking` callback must re-register itself
- All SwiftUI views embedded in AppKit must receive full environment injection
- `TableContentViewController` creates `TableDataController` — they have 1:1 lifetime
- Error alerts use `NSAlert.beginSheetModal`, not SwiftUI `.alert()`

## Anti-Patterns

- Do NOT forget to re-register observation in `onChange` — observation is one-shot
- Do NOT embed SwiftUI without `injectEnvironments()` — will crash on missing `@Environment` values
- Do NOT use `NSViewRepresentable` for `TableCoordinator` in the AppKit path — create directly
- Do NOT add MongoDB to the `TableContentViewController` path — it uses a different data model

## Downlinks

- [Views](../../Views/AGENTS.md) — SwiftUI views embedded in these VCs
- [Services](../../Services/AGENTS.md) — `TableDataController`, `ConnectionService` owned by VCs
- [Views/Documents](../../Views/Documents/AGENTS.md) — Tab content views and table components
