import Foundation

enum NotebookCellType: String, CaseIterable {
    case query = "Query"
    case python = "Python"
    case text = "Text"
    case chart = "Chart"
    case metric = "Metric"
    case parameter = "Parameter"

    var icon: String {
        switch self {
        case .query: "terminal"
        case .python: "chevron.left.forwardslash.chevron.right"
        case .text: "doc.text"
        case .chart: "chart.bar"
        case .metric: "number"
        case .parameter: "slider.horizontal.3"
        }
    }

    var blockKind: NotebookBlockKind? {
        switch self {
        case .chart: .chart
        case .text: .text
        default: nil
        }
    }

    var isEnabled: Bool {
        blockKind != nil
    }
}
