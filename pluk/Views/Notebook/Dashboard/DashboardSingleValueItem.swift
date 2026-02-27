import AppKit
import SwiftUI

final class DashboardSingleValueItem: DashboardBaseItem {

    static let identifier = NSUserInterfaceItemIdentifier("DashboardSingleValueItem")

    override var minimumContentHeight: CGFloat { 140 }

    private var hostingView: NSHostingView<AnyView>?

    func configure(block: NotebookBlock, viewModel: SingleValueBlockViewModel, isPublished: Bool = false) {
        configureBase(block: block, isPublished: isPublished)
        hostingView?.removeFromSuperview()

        let displayTitle = block.title.isEmpty ? "Untitled \(block.blockType.displayName)" : block.title
        let content = DashboardSingleValueContentView(viewModel: viewModel, title: displayTitle)
        let hosting = NSHostingView(rootView: AnyView(content))
        hosting.translatesAutoresizingMaskIntoConstraints = false
        blockContainer.addSubview(hosting)
        hostingView = hosting

        NSLayoutConstraint.activate([
            hosting.topAnchor.constraint(equalTo: blockContainer.topAnchor),
            hosting.leadingAnchor.constraint(equalTo: blockContainer.leadingAnchor),
            hosting.trailingAnchor.constraint(equalTo: blockContainer.trailingAnchor),
            hosting.bottomAnchor.constraint(equalTo: blockContainer.bottomAnchor),
        ])
    }
}

private struct DashboardSingleValueContentView: View {
    var viewModel: SingleValueBlockViewModel
    var title: String

    var body: some View {
        VStack(spacing: 4) {
            if viewModel.isLoadingSingleValue {
                ProgressView()
                    .controlSize(.small)
            } else if let error = viewModel.singleValueError {
                Text(error)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            } else if let value = viewModel.singleValueResult {
                Text(formattedValue(value))
                    .font(.system(size: 48, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)
                    .contentTransition(.numericText())

                let subtitle = viewModel.config?.label ?? title
                if !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func formattedValue(_ value: Double) -> String {
        if value >= 1_000_000 {
            return (value / 1_000_000).formatted(.number.precision(.fractionLength(1))) + "M"
        } else if value >= 10_000 {
            return (value / 1_000).formatted(.number.precision(.fractionLength(0))) + "K"
        } else if value >= 1_000 {
            return (value / 1_000).formatted(.number.precision(.fractionLength(1))) + "K"
        } else if value == value.rounded() {
            return Int(value).formatted(.number)
        } else {
            return value.formatted(.number.precision(.fractionLength(2)))
        }
    }
}
