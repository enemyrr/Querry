import SwiftUI
import Charts

struct BarChartView: View {
    let data: [ChartDataPoint]

    var body: some View {
        Chart(data) { point in
            BarMark(
                x: .value("X", point.x),
                y: .value("Y", point.y)
            )
            .foregroundStyle(Color.accentColor)
            .clipShape(.rect(cornerRadius: 3))
        }
        .chartXAxis {
            AxisMarks(values: .automatic) {
                AxisValueLabel()
                    .font(.caption)
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading) {
                AxisGridLine()
                AxisValueLabel()
                    .font(.caption)
            }
        }
    }
}
