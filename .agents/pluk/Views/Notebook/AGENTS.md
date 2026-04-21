# Views/Notebook/

## Purpose

Block-based notebook system for data exploration. Users create notebooks containing text blocks and chart blocks, with an AI agent that can query databases and generate visualizations.

## Directory Structure

```
pluk/Views/Notebook/
├── NotebookViewController.swift        Root AppKit VC (uses SidebarSplitViewController)
├── NotebookDataController.swift        @Observable state for notebook
├── Agent/                              AI agent system (tool loop, streaming, markdown)
├── Chart/                              Chart visualization (config, views, data fetching)
├── Text/                               Text block editing (MarkdownTextView, parser)
├── Blocks/                             Block management (controller, insertion, action bar)
├── Content/                            Layout VCs (content, main pane, inner split)
├── Sidebar/                            Data browser (table/schema explorer)
├── Header/                             Notebook header and toolbar
└── EmptyState/                         Initial state UI with cell type buttons
```

## Architecture

```
NotebookViewController (root)
└── SidebarSplitViewController
    ├── Left: NotebookDataBrowserController (table explorer)
    └── Right: NotebookContentController
        └── NotebookMainPaneController
            └── NotebookInnerSplitController
                ├── Top: NotebookBlocksController (block list)
                │   ├── ChartBlockController × n
                │   └── TextBlockController × n
                └── Bottom: AgentChatController (AI conversation)
```

## Data Model

- **Notebook** (@Model) — Container with title, description, status
- **NotebookBlock** (@Model) — Individual blocks: `blockType` (.chart/.text), `sortOrder`, `configJSON`, `blockHeight`
- **AgentChat** (@Model) — Conversation sessions
- **AgentMessage** (@Model) — Messages with `role` (.user/.assistant), `content` with XML-serialized metadata

## Block Lifecycle

1. **Creation**: User clicks "Add Block" or AI agent creates via tool call
2. **Persistence**: `modelContainer.mainContext.insert(block)`
3. **Rendering**: `NotebookBlocksController` creates `ChartBlockController` or `TextBlockController`
4. **Configuration**: Chart config saved to `block.configJSON`; text content via `block.textContent` computed property
5. **Deletion**: `NotebookDataController.deleteBlock()` → cleanup → remove from `blocks` array

## Invariants

- `NotebookBlocksController` maintains a `blockControllers: [UUID: NSViewController]` dictionary
- Block order is determined by `sortOrder` property
- `ChartBlockController.cleanupSession()` must be called before removing a chart block
- The agent can only execute **read-only SELECT queries** — write operations are blocked
- Agent messages embed `<thinking>` and `<tool_call>` XML tags for display — these are stripped before feeding back to the LLM

## Debugging Surprises

- `cmd+w` for notebook windows is not provided by the app's main menu. `MainMenu.xib` omits the standard Window → Close item, so notebook-specific controllers must handle the shortcut explicitly or the window will ignore it while document tabs still respond via their own local monitor.

## Anti-Patterns

- Do NOT create NotebookBlock without setting `sortOrder` — blocks will overlap
- Do NOT directly mutate `configJSON` — use the view model's `persistConfig()` method
- Do NOT forget to call `cleanupSession()` on chart removal — leaks database connections
- Do NOT infer the head of an inline single-value row after a cross-row move. When inserting at the start of an existing row, explicitly make the dragged block the row head and flip the old head to inline, or drag/drop will appear to snap into the wrong row.
- Do NOT align block insertion UI against raw collection row frames. Notebook rows include non-content chrome (title area and, for most block types, resize-handle space), so `Add new` indicators and inline insertion bars must be centered against the visible block surfaces/gaps or they will look vertically off.
- Do NOT size notebook same-row drag outlines or row division previews from raw `NotebookGridLayout` frames when the item is live. Use `NotebookBaseItem.blockContainer` for the visible card surface; the layout frame still includes notebook chrome and makes the dashed target read slightly short.
- Do NOT size dashboard drag previews or same-row drop outlines from raw `NSCollectionViewLayoutAttributes.frame` when the item is live. Use `DashboardBaseItem.blockContainer` for the visible card frame; the collection item frame includes title/handle chrome and makes the dashed target look shorter than the card.
- Do NOT capture `indexPath.item` into collection-item drag callbacks and assume it stays correct after `moveItem`. Resolve the source block/index from the item's current block ID at drag start, or reordered drags can move the wrong block.
- Do NOT leave notebook drag cleanup with `insertRowGapBeforeIndex` or `insertBarBeforeRowIndex` still set. Those transient layout flags can shift the first row down and leave a fake blank gap with an `Add new` indicator after the drop. Clear the flags, invalidate layout, and only fall back to a full reload if the hosting path is already known-safe.

## Downlinks

- [Agent](Agent/AGENTS.md) — AI agent loop, tool system, streaming
- [Chart](Chart/AGENTS.md) — Chart config, view models, per-type views
