import SwiftUI
import Charts

struct HorizontalBarChartView: View {
    let data: [ChartDataPoint]

    var body: some View {
        Chart(data) { point in
            BarMark(
                x: .value("Y", point.y),
                y: .value("X", point.x)
            )
            .foregroundStyle(Color.accentColor)
            .clipShape(.rect(cornerRadius: 3))
        }
        .chartXAxis {
            AxisMarks(position: .bottom) {
                AxisGridLine()
                AxisValueLabel()
                    .font(.caption)
            }
        }
        .chartYAxis {
            AxisMarks(values: .automatic) {
                AxisValueLabel()
                    .font(.caption)
            }
        }
        .transaction { transaction in
            transaction.animation = nil
        }
    }
}
