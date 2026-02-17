import AppKit
import SwiftData
import SwiftUI

final class NotebookViewController: NSViewController {

    private let notebookId: UUID
    private let modelContainer: ModelContainer
    private let dataController: NotebookDataController

    private var splitViewController: SidebarSplitViewController?
    private var keyMonitor: Any?

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
        setupContent()
    }

    override func viewDidAppear() {
        super.viewDidAppear()
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self,
                  self.view.window == event.window else { return event }
            let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            if flags == .command && event.charactersIgnoringModifiers == "e" {
                self.dataController.isRightSidebarVisible.toggle()
                return nil
            }
            return event
        }
    }

    override func viewDidDisappear() {
        super.viewDidDisappear()
        if let keyMonitor {
            NSEvent.removeMonitor(keyMonitor)
            self.keyMonitor = nil
        }
    }

    private func setupContent() {
        let sidebarVC = NotebookDataBrowserController(dataController: dataController)
        let contentVC = NotebookContentController(dataController: dataController)

        let splitVC = SidebarSplitViewController(
            sidebarController: sidebarVC,
            contentController: contentVC,
            configuration: .init(minWidth: 240, autosaveName: "NotebookSidebarSplit", startsCollapsed: true)
        )
        self.splitViewController = splitVC

        addChild(splitVC)
        let sv = splitVC.view
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
