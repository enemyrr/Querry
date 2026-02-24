import SwiftUI
import Charts

struct HorizontalBarChartView: View {
    let data: [ChartDataPoint]

    var body: some View {
        let stride = ChartDataPoint.xAxisStride(for: data.count)
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
        .transaction { transaction in
            transaction.animation = nil
        }
    }
}
