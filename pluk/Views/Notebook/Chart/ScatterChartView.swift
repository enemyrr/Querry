import SwiftUI
import Charts

struct ScatterChartView: View {
    let data: [ChartDataPoint]

    var body: some View {
        Chart(data) { point in
            PointMark(
                x: .value("X", point.x),
                y: .value("Y", point.y)
            )
            .foregroundStyle(Color.accentColor)
            .symbolSize(30)
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
        .transaction { transaction in
            transaction.animation = nil
        }
    }
}
