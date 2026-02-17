import AppKit
import SwiftUI

final class NotebookContentController: NSViewController {

    private let dataController: NotebookDataController

    private var headerHostingView: NSHostingView<AnyView>?
    private var toolbarHostingView: NSHostingView<AnyView>?
    private var emptyStateHostingView: NSHostingView<AnyView>?

    init(dataController: NotebookDataController) {
        self.dataController = dataController
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    override func loadView() {
        let root = NSView()
        root.wantsLayer = true
        self.view = root

        setupHeader()
        setupToolbar()
        setupEmptyState()
        setupConstraints()
    }

    private func setupHeader() {
        let headerView = NotebookHeaderView(dataController: dataController)
        let hosting = NSHostingView(rootView: AnyView(headerView))
        hosting.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(hosting)
        headerHostingView = hosting
    }

    private func setupToolbar() {
        let toolbarView = NotebookToolbar()
        let hosting = NSHostingView(rootView: AnyView(toolbarView))
        hosting.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(hosting)
        toolbarHostingView = hosting
    }

    private func setupEmptyState() {
        let emptyView = NotebookEmptyStateView(dataController: dataController)
        let hosting = NSHostingView(rootView: AnyView(emptyView))
        hosting.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(hosting)
        emptyStateHostingView = hosting
    }

    private func setupConstraints() {
        guard let header = headerHostingView,
              let toolbar = toolbarHostingView,
              let emptyState = emptyStateHostingView else { return }

        NSLayoutConstraint.activate([
            header.topAnchor.constraint(equalTo: view.topAnchor, constant: 50),
            header.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            header.trailingAnchor.constraint(equalTo: toolbar.leadingAnchor),

            toolbar.topAnchor.constraint(equalTo: view.topAnchor, constant: 50),
            toolbar.trailingAnchor.constraint(equalTo: view.trailingAnchor),

            emptyState.topAnchor.constraint(equalTo: header.bottomAnchor),
            emptyState.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            emptyState.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            emptyState.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
    }
}
