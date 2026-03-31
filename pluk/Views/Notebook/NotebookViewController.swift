import AppKit
import SwiftData

final class NotebookViewController: NSViewController {

    private let dataController: NotebookDataController

    private var splitViewController: SidebarSplitViewController?
    private var keyMonitor: Any?
    private var windowActivationObserver: Any?

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
    }

    override func viewDidAppear() {
        super.viewDidAppear()
        dataController.refreshConnections()
        installWindowActivationObserver()
        showBetaNoticeIfNeeded()
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self,
                  self.view.window == event.window else { return event }
            let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            if flags == .command && event.charactersIgnoringModifiers == "e" {
                guard !self.dataController.isDashboardPublished, !self.dataController.isPublishPreviewing else { return event }
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
        removeWindowActivationObserver()
    }

    deinit {
        removeWindowActivationObserver()
    }

    private func showBetaNoticeIfNeeded() {
        let key = "hasAcknowledgedNotebookBeta"
        guard !UserDefaults.standard.bool(forKey: key),
              let window = view.window else { return }

        let alert = NSAlert()
        alert.messageText = "Notebooks is in Beta"
        alert.informativeText = "This feature is still under active development. Some things may not work as expected.\n\nHelp us improve by sharing your feedback!"
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Got it")
        alert.beginSheetModal(for: window) { _ in
            UserDefaults.standard.set(true, forKey: key)
        }
    }

    private func setupContent() {
        let sidebarVC = NotebookDataBrowserController()

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

    private func installWindowActivationObserver() {
        guard windowActivationObserver == nil,
              let window = view.window else { return }

        windowActivationObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.didBecomeMainNotification,
            object: window,
            queue: .main
        ) { [weak self] _ in
            self?.dataController.refreshConnections()
        }
    }

    private func removeWindowActivationObserver() {
        guard let windowActivationObserver else { return }
        NotificationCenter.default.removeObserver(windowActivationObserver)
        self.windowActivationObserver = nil
    }
}
