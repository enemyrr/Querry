import SwiftUI
import Charts

struct PieChartView: View {
    let data: [ChartDataPoint]

    var body: some View {
        Chart(data) { point in
            SectorMark(
                angle: .value("Value", point.y),
                innerRadius: .ratio(0.4),
                angularInset: 1.5
            )
            .foregroundStyle(by: .value("Category", point.x))
            .clipShape(.rect(cornerRadius: 3))
        }
        .chartLegend(position: .bottom, spacing: 8)
        .transaction { transaction in
            transaction.animation = nil
        }
    }
}
