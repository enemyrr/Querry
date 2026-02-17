import AppKit
import SwiftData
import SwiftUI

final class NotebookViewController: NSViewController {

    private let notebookId: UUID
    private let modelContainer: ModelContainer
    private let dataController: NotebookDataController

    private var splitViewController: NSSplitViewController!

    init(notebookId: UUID, modelContainer: ModelContainer) {
        self.notebookId = notebookId
        self.modelContainer = modelContainer
        self.dataController = NotebookDataController(
            notebookId: notebookId,
            modelContainer: modelContainer
        )
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    override func loadView() {
        let root = NSView()
        root.wantsLayer = true
        self.view = root

        dataController.load()
        setupSplitView()
    }

    private func setupSplitView() {
        let leftVC = NotebookDataBrowserController(dataController: dataController)
        let centerVC = NotebookContentController(dataController: dataController)
        let rightVC = NotebookAgentController()

        let leftItem = NSSplitViewItem(viewController: leftVC)
        leftItem.canCollapse = true
        leftItem.minimumThickness = 240
        leftItem.preferredThicknessFraction = 0.2

        let centerItem = NSSplitViewItem(viewController: centerVC)
        centerItem.minimumThickness = 400

        let rightItem = NSSplitViewItem(viewController: rightVC)
        rightItem.canCollapse = true
        rightItem.minimumThickness = 280
        rightItem.preferredThicknessFraction = 0.22

        splitViewController = NSSplitViewController()
        splitViewController.splitViewItems = [leftItem, centerItem, rightItem]

        let splitView = splitViewController.splitView
        splitView.isVertical = true
        splitView.dividerStyle = .thin
        splitView.autosaveName = "NotebookSplitView"

        addChild(splitViewController)
        let sv = splitViewController.view
        sv.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(sv)

        NSLayoutConstraint.activate([
            sv.topAnchor.constraint(equalTo: view.topAnchor),
            sv.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            sv.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            sv.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
    }
}
