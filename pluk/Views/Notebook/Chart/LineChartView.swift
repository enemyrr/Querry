import SwiftUI
import Charts

struct LineChartView: View {
    let data: [ChartDataPoint]

    var body: some View {
        let stride = ChartDataPoint.xAxisStride(for: data.count)
        Chart(data) { point in
            LineMark(
                x: .value("X", point.x),
                y: .value("Y", point.y)
            )
            .foregroundStyle(Color.accentColor)
            .interpolationMethod(.catmullRom)

            PointMark(
                x: .value("X", point.x),
                y: .value("Y", point.y)
            )
            .foregroundStyle(Color.accentColor)
            .symbolSize(20)
        }
        .chartXAxis {
            AxisMarks(values: .automatic) { value in
                if let label = value.as(String.self),
                   let index = data.firstIndex(where: { $0.x == label }),
                   index % stride == 0 {
                    AxisValueLabel {
                        Text(data[index].truncatedX)
                            .font(.caption)
                            .lineLimit(1)
                    }
                }
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
