# Views/Notebook/Shared/

## Purpose

Shared utilities and content views used by both the Notebook (NSStackView-based) and Dashboard (NSCollectionView-based) views.

## Files

- **`BlockDragController.swift`** — Manages drag-and-drop visual state: snapshot layer, dim overlay, auto-scroll timer, and dashed indicator shape helpers. Both `NotebookBlocksController` and `DashboardGridController` use this.
- **`SingleValueContentView.swift`** — SwiftUI view for rendering a single numeric value with formatted display (M/K suffixes), loading state, and error state. Used by `DashboardSingleValueItem`.

## Invariants

- `BlockDragController` is a utility object, not a view controller — it does not own the drop logic, which differs between Notebook (vertical stack) and Dashboard (2D grid)
- `cleanup()` must be called at the end of every drag to release layers and reset state
- The dashed indicator style (1.5 line width, [4, 3] dash pattern, 10pt corner radius) is the canonical visual for drop zones across both views

## Anti-Patterns

- Do NOT put layout-specific drop logic in `BlockDragController` — keep it in the respective controllers
- Do NOT duplicate the dashed shape styling — always use `BlockDragController.applyDashedStyle()` or `makeDashedShape()`
