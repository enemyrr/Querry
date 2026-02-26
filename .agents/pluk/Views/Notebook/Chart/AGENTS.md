# Views/Notebook/Chart/

## Purpose

Chart visualization system for notebook blocks. Handles chart configuration, data fetching, aggregation, and rendering across 7+ chart types.

## Key Files

| File | Purpose |
|------|---------|
| `ChartBlockViewModel.swift` | @Observable state: config, data fetching, axis mapping, aggregation |
| `ChartBlockController.swift` | AppKit NSViewController wrapping the chart + config UI |
| `ChartConfigController.swift` | 3-panel AppKit config UI (~2000 lines): source, fields, preview |
| `ChartDriverSession.swift` | Database session for chart queries (aggregated + raw) |
| `LineChartView.swift` | SwiftUI Charts: time series line + area fill |
| `BarChartView.swift` | SwiftUI Charts: vertical bars (grouped/stacked) |
| `AreaChartView.swift` | SwiftUI Charts: stacked area |
| `HorizontalBarChartView.swift` | SwiftUI Charts: horizontal bars |
| `ScatterChartView.swift` | SwiftUI Charts: XY scatter with optional trend line |
| `PieChartView.swift` | SwiftUI Charts: donut/pie |
| `HistogramChartView.swift` | SwiftUI Charts: binned distribution |
| `PivotTablePlaceholderView.swift` | Placeholder for future pivot table |

## Architecture

```
ChartBlockController (NSViewController)
├── ChartConfigController (3-panel NSViewController)
│   ├── Left Panel (250pt): Connection, schema, table selectors
│   ├── Middle Panel (250pt): Field config, aggregation pickers
│   └── Right Panel (flex): Chart preview
│       └── NSHostingView(ChartView) — SwiftUI chart embedded
└── ChartBlockViewModel (@Observable)
    ├── config: ChartBlockConfig (serialized to block.configJSON)
    ├── chartData: [ChartDataPoint]
    └── ChartDriverSession (DB queries)
```

## Data Flow

1. User selects connection → schema → table in left panel
2. `ChartBlockViewModel` fetches schema, classifies columns as measures (numeric) vs dimensions (non-numeric)
3. User drags/selects fields for X/Y axes and sets aggregation functions
4. `ChartBlockViewModel.fetchChartData()`:
   - If aggregation needed → `session.fetchAggregatedData()` (GROUP BY query)
   - If no aggregation → `session.fetchTableData()` (raw data)
5. Results transformed to `[ChartDataPoint]`
6. `reduceChartData()` caps at 160 points with smart downsampling
7. SwiftUI chart view renders from `chartData`

## ChartDataPoint

```swift
struct ChartDataPoint: Identifiable {
    let x: String       // X-axis label
    let y: Double       // Y value
    var series: String   // Multi-series identifier
}
```

Static helpers: `seriesPalette` (15 colors), `normalized()` (for pie/stacked), `fillMissingSeries()`, `xAxisStride()`

## Config Persistence

`ChartBlockConfig` (Codable struct) is serialized to `NotebookBlock.configJSON`:
- `connectionKeychainId`, `connectionName`, `databaseType`
- `databaseName`, `schemaName`, `tableName`
- `fields: [String: [String]]` — axis → column mappings
- `fieldAggregations: [String: [String: String]]` — per-column aggregation
- `chartType: ChartType`
- `rowLimit: Int`, `filters: [ChartFilterCondition]`

## Freeze/Snapshot Mechanism

During config changes, live chart updates are paused:
- `NotificationCenter.post(.notebookChartFreeze)` — freezes chart rendering
- Displays last-rendered image as snapshot
- Prevents visual jitter during rapid config changes
- Unfreezes when config settles

## Invariants

- Chart views use SwiftUI Charts framework — each type is a separate SwiftUI View
- Chart views are embedded in AppKit via `NSHostingView(rootView: AnyView(...))`
- `ChartBlockViewModel.persistConfig()` must be called to save changes to `block.configJSON`
- Column classification: numeric types → measures, everything else → dimensions
- Data capped at 160 points — `reduceChartData()` downsamples uniformly

## Anti-Patterns

- Do NOT render charts directly in AppKit — always use SwiftUI Charts via NSHostingView
- Do NOT modify `block.configJSON` directly — use `ChartBlockViewModel.persistConfig()`
- Do NOT skip the freeze mechanism during rapid config changes — causes UI jitter
- Do NOT assume all columns are available — chart types have specific field requirements defined in `ChartType`
