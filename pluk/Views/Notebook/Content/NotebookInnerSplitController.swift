import AppKit

final class NotebookInnerSplitController: NSSplitViewController {

    private var contentItem: NSSplitViewItem!
    private var inspectorItem: NSSplitViewItem!
    private var isProgrammaticCollapse = false
    private var isAnimating = false

    var onCollapseStateChanged: ((Bool) -> Void)?

    var isInspectorCollapsed: Bool { inspectorItem.isCollapsed }

    private let dataController: NotebookDataController

    init(contentController: NSViewController, inspectorController: NSViewController, dataController: NotebookDataController) {
        self.dataController = dataController
        super.init(nibName: nil, bundle: nil)

        contentItem = NSSplitViewItem(viewController: contentController)
        contentItem.holdingPriority = .defaultLow
        contentItem.minimumThickness = 300

        inspectorItem = NSSplitViewItem(viewController: inspectorController)
        inspectorItem.canCollapse = true
        inspectorItem.isCollapsed = true
        inspectorItem.minimumThickness = 350
        inspectorItem.maximumThickness = 450
        inspectorItem.holdingPriority = .defaultLow + 1

        splitViewItems = [contentItem, inspectorItem]
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    override func loadView() {
        let customSplitView = HoverDividerSplitView()
        customSplitView.isVertical = true
        customSplitView.dividerStyle = .thin
        self.splitView = customSplitView
        super.loadView()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleSplitViewDidResize),
            name: NSSplitView.didResizeSubviewsNotification,
            object: splitView
        )

        observeRightSidebar()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: - Toggle

    func toggle() {
        if inspectorItem.isCollapsed {
            expand()
        } else {
            collapse()
        }
    }

    private func collapse() {
        guard !isAnimating, !inspectorItem.isCollapsed else { return }
        animateInspector(collapsed: true)
    }

    private func expand() {
        guard !isAnimating, inspectorItem.isCollapsed else { return }
        animateInspector(collapsed: false)
    }

    private func animateInspector(collapsed: Bool) {
        isAnimating = true
        isProgrammaticCollapse = collapsed

        let inspectorView = inspectorItem.viewController.view

        if let hoverSplitView = splitView as? HoverDividerSplitView {
            hoverSplitView.isSidebarCollapsed = collapsed
            hoverSplitView.needsDisplay = true
        }

        if !collapsed {
            inspectorView.alphaValue = 0
        }

        onCollapseStateChanged?(collapsed)

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.2
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            context.allowsImplicitAnimation = true
            inspectorView.animator().alphaValue = collapsed ? 0 : 1
            inspectorItem.animator().isCollapsed = collapsed
        } completionHandler: { [weak self] in
            guard let self else { return }
            isAnimating = false
            isProgrammaticCollapse = false

            if !collapsed {
                inspectorView.alphaValue = 1
            }

            if let hoverSplitView = splitView as? HoverDividerSplitView {
                hoverSplitView.isSidebarCollapsed = collapsed
            }
        }
    }

    // MARK: - Observation

    private func observeRightSidebar() {
        withObservationTracking {
            _ = self.dataController.isRightSidebarVisible
        } onChange: {
            Task { @MainActor in
                self.syncCollapseState()
                self.observeRightSidebar()
            }
        }
    }

    private func syncCollapseState() {
        if dataController.isRightSidebarVisible {
            expand()
        } else {
            collapse()
        }
    }

    // MARK: - NSSplitViewDelegate

    @objc private func handleSplitViewDidResize(_ notification: Notification) {
        guard !isAnimating else { return }

        if let hoverSplitView = splitView as? HoverDividerSplitView {
            hoverSplitView.isSidebarCollapsed = inspectorItem.isCollapsed
        }
    }

    override func splitView(_ splitView: NSSplitView, canCollapseSubview subview: NSView) -> Bool {
        return isProgrammaticCollapse
    }
}
