import SwiftUI

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
}

struct CellTypeButton: View {
    let type: NotebookCellType
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: type.icon)
                    .font(.title3)
                Text(type.rawValue)
                    .font(.caption)
            }
            .frame(width: 72, height: 56)
            .background(.quinary)
            .clipShape(.rect(cornerRadius: 8))
        }
        .buttonStyle(.plain)
    }
}
