import SwiftUI
import Charts

struct HorizontalBarChartView: View {
    let data: [ChartDataPoint]
    var chartType: ChartBlockConfig.ChartType = .groupedBar

    private var isMultiSeries: Bool {
        ChartDataPoint.hasMultipleSeries(data)
    }

    private var isHundredPercent: Bool {
        chartType == .hundredPercentStackedBar
    }

    private var displayData: [ChartDataPoint] {
        if isHundredPercent, isMultiSeries {
            return ChartDataPoint.normalized(data)
        }
        return data
    }

    private var categoryCount: Int {
        Set(data.map(\.x)).count
    }

    private var barThickness: CGFloat {
        let seriesCount = isMultiSeries && chartType == .groupedBar
            ? max(1, ChartDataPoint.seriesNames(data).count)
            : 1
        return seriesCount > 2 ? 8 : 20
    }

    var body: some View {
        GeometryReader { geo in
            let stride = ChartDataPoint.xAxisStride(for: data, availableWidth: geo.size.height)
            let series = ChartDataPoint.seriesNames(data)
            let colors = series.indices.map { ChartDataPoint.seriesPalette[$0 % ChartDataPoint.seriesPalette.count] }

            Chart(displayData) { point in
                if isMultiSeries {
                    if chartType == .groupedBar {
                        BarMark(
                            x: .value("Y", point.y),
                            y: .value("X", point.x),
                            height: .fixed(barThickness)
                        )
                        .foregroundStyle(by: .value("Series", point.series))
                        .position(by: .value("Series", point.series))
                        .clipShape(.rect(cornerRadius: 3))
                        .annotation(position: .trailing, spacing: 4) {
                            Text(point.y.formatted(.number.notation(.compactName)))
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    } else {
                        BarMark(
                            x: .value("Y", point.y),
                            y: .value("X", point.x),
                            height: .fixed(barThickness)
                        )
                        .foregroundStyle(by: .value("Series", point.series))
                    }
                } else {
                    BarMark(
                        x: .value("Y", point.y),
                        y: .value("X", point.x),
                        height: .fixed(barThickness)
                    )
                    .foregroundStyle(Color.accentColor)
                    .clipShape(.rect(cornerRadius: 3))
                    .annotation(position: .trailing, spacing: 4) {
                        Text(point.y.formatted(.number.notation(.compactName)))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .chartForegroundStyleScale(domain: series, range: colors)
            .hundredPercentXScale(isActive: isHundredPercent)
            .chartXAxis {
                AxisMarks(position: .bottom) { value in
                    AxisGridLine()
                    AxisValueLabel {
                        if let number = value.as(Double.self) {
                            if isHundredPercent {
                                Text(number.formatted(.percent))
                                    .font(.caption)
                            } else {
                                Text(number.formatted(.number.notation(.compactName)))
                                    .font(.caption)
                            }
                        }
                    }
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
            .chartLegend(isMultiSeries ? .visible : .hidden)
            .transaction { transaction in
                transaction.animation = nil
            }
        }
    }
}

private extension View {
    @ViewBuilder
    func hundredPercentXScale(isActive: Bool) -> some View {
        if isActive {
            chartXScale(domain: 0...1 as ClosedRange<Double>)
        } else {
            self
        }
    }
}
