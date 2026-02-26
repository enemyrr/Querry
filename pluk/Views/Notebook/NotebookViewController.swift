import AppKit
import SwiftData

final class NotebookViewController: NSViewController {

    private let dataController: NotebookDataController

    private var splitViewController: SidebarSplitViewController?
    private var keyMonitor: Any?

    init(notebookId: UUID, modelContainer: ModelContainer) {
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
        observePublishedState()
    }

    override func viewDidAppear() {
        super.viewDidAppear()
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self,
                  self.view.window == event.window else { return event }
            let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            if flags == .command && event.charactersIgnoringModifiers == "e" {
                guard !self.dataController.isDashboardPublished else { return event }
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

    private func observePublishedState() {
        withObservationTracking {
            _ = self.dataController.isDashboardPublished
        } onChange: { [weak self] in
            Task { @MainActor [weak self] in
                guard let self else { return }
                if self.dataController.isDashboardPublished {
                    self.splitViewController?.collapse()
                }
                self.observePublishedState()
            }
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
        let splitView = splitVC.view
        splitView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(splitView)

        NSLayoutConstraint.activate([
            splitView.topAnchor.constraint(equalTo: view.topAnchor),
            splitView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            splitView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            splitView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
    }
}
