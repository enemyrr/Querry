import SwiftUI
import Charts

struct AreaChartView: View {
    let data: [ChartDataPoint]

    var body: some View {
        Chart(data) { point in
            AreaMark(
                x: .value("X", point.x),
                y: .value("Y", point.y)
            )
            .foregroundStyle(Color.accentColor.opacity(0.3))
            .interpolationMethod(.catmullRom)

            LineMark(
                x: .value("X", point.x),
                y: .value("Y", point.y)
            )
            .foregroundStyle(Color.accentColor)
            .interpolationMethod(.catmullRom)
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
