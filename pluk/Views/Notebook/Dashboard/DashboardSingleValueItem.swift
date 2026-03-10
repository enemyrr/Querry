import AppKit
import SwiftUI

final class DashboardSingleValueItem: DashboardBaseItem {

    static let identifier = NSUserInterfaceItemIdentifier("DashboardSingleValueItem")

    override var minimumContentHeight: CGFloat { 120 }

    private var hostingView: NSHostingView<AnyView>?

    func configure(block: NotebookBlock, viewModel: SingleValueBlockViewModel, isPublished: Bool = false) {
        configureBase(block: block, isPublished: isPublished)

        let content = SingleValueContentView(viewModel: viewModel, title: titleLabel.stringValue)
        if let existing = hostingView {
            existing.rootView = AnyView(content)
        } else {
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
}
