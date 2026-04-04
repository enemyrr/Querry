# Views/Notebook/Shared/

## Purpose

Shared utilities and content views used by both the Notebook (NSStackView-based) and Dashboard (NSCollectionView-based) views.

## Files

- **`BlockDragController.swift`** — Manages drag-and-drop visual state: snapshot layer, dim overlay, auto-scroll timer, and dashed indicator shape helpers. Both `NotebookBlocksController` and `DashboardGridController` use this.
- **`SingleValueContentView.swift`** — SwiftUI single-value renderer kept for hosted SwiftUI surfaces; dashboard single-value now uses the AppKit `SingleValueDisplayView`.
- **`NonRecyclingCollectionView.swift`** — NSCollectionView subclass that reports `visibleRect == bounds` so complex hosted block views are not recycled while scrolling.

## Invariants

- `BlockDragController` is a utility object, not a view controller — it does not own the drop logic, which differs between Notebook (vertical stack) and Dashboard (2D grid)
- `cleanup()` must be called at the end of every drag to release layers and reset state
- `DashboardDragHandle` must cancel drags on scroll-wheel / interrupted mouse sequences; relying on `mouseUp` alone inside notebook scroll views can leave the drag snapshot and cursor stuck
- The dashed indicator style (1.5 line width, [4, 3] dash pattern, 10pt corner radius) is the canonical visual for drop zones across both views
- Use `NonRecyclingCollectionView` for block surfaces that host SwiftUI/AppKit-heavy content (currently dashboard charts); default recycling can cause hosted content to disappear during scroll/reuse

## Anti-Patterns

- Do NOT put layout-specific drop logic in `BlockDragController` — keep it in the respective controllers
- Do NOT duplicate the dashed shape styling — always use `BlockDragController.applyDashedStyle()` or `makeDashedShape()`
