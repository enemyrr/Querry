import AppKit

// MARK: - Hover Divider Split View

final class HoverDividerSplitView: NSSplitView {
    private var isDividerVisible = false
    private var trackingArea: NSTrackingArea?
    private var showDividerTask: Task<Void, Never>?
    var isSidebarCollapsed = false

    override var dividerThickness: CGFloat { isSidebarCollapsed ? 0 : 2 }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if window != nil {
            setupDividerTracking()
        }
    }

    private func setupDividerTracking() {
        if let existingArea = trackingArea {
            removeTrackingArea(existingArea)
        }

        let newArea = NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .mouseMoved, .activeInKeyWindow, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(newArea)
        trackingArea = newArea
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        setupDividerTracking()
    }

    override func mouseMoved(with event: NSEvent) {
        super.mouseMoved(with: event)
        updateDividerVisibility(for: event)
    }

    override func mouseEntered(with event: NSEvent) {
        super.mouseEntered(with: event)
        updateDividerVisibility(for: event)
    }

    override func mouseExited(with event: NSEvent) {
        super.mouseExited(with: event)
        hideDivider()
    }

    private func updateDividerVisibility(for event: NSEvent) {
        let location = convert(event.locationInWindow, from: nil)
        let dividerRect = getDividerRect()
        let hoverZone = dividerRect.insetBy(dx: -10, dy: 0)
        let shouldShow = hoverZone.contains(location)

        if shouldShow == isDividerVisible && showDividerTask == nil { return }

        if shouldShow {
            guard showDividerTask == nil else { return }
            showDividerTask = Task { @MainActor [weak self] in
                try? await Task.sleep(for: .milliseconds(150))
                guard let self, !Task.isCancelled else { return }
                showDividerTask = nil
                isDividerVisible = true
                needsDisplay = true
            }
        } else {
            hideDivider()
        }
    }

    private func hideDivider() {
        showDividerTask?.cancel()
        showDividerTask = nil
        guard isDividerVisible else { return }
        isDividerVisible = false
        needsDisplay = true
    }

    private func getDividerRect() -> NSRect {
        guard arrangedSubviews.count >= 2 else { return .zero }

        let leftView = arrangedSubviews[0]
        return NSRect(
            x: leftView.frame.maxX,
            y: 0,
            width: dividerThickness,
            height: frame.height
        )
    }

    override func drawDivider(in rect: NSRect) {
        guard !isSidebarCollapsed, isDividerVisible else { return }
        NSColor.separatorColor.setFill()
        rect.fill()
    }
}

// MARK: - Sidebar Split View Controller

final class SidebarSplitViewController: NSSplitViewController {

    struct Configuration {
        var minWidth: CGFloat = 330
        var autosaveName: String? = "PlukSidebarSplitView"
        var startsCollapsed: Bool = false
    }

    private var sidebarItem: NSSplitViewItem!
    private var contentItem: NSSplitViewItem!
    private var isProgrammaticCollapse = false

    var isCollapsed: Bool { sidebarItem.isCollapsed }

    private let configuration: Configuration

    init(
        sidebarController: NSViewController,
        contentController: NSViewController,
        configuration: Configuration = Configuration()
    ) {
        self.configuration = configuration
        super.init(nibName: nil, bundle: nil)
        setupSplitViewItems(sidebarController: sidebarController, contentController: contentController)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    private func setupSplitViewItems(sidebarController: NSViewController, contentController: NSViewController) {
        sidebarItem = NSSplitViewItem(viewController: sidebarController)
        sidebarItem.canCollapse = true
        sidebarItem.minimumThickness = configuration.minWidth
        sidebarItem.maximumThickness = .greatestFiniteMagnitude
        sidebarItem.automaticMaximumThickness = .greatestFiniteMagnitude
        sidebarItem.holdingPriority = NSLayoutConstraint.Priority(260)

        contentItem = NSSplitViewItem(viewController: contentController)
        contentItem.minimumThickness = 400
        contentItem.holdingPriority = NSLayoutConstraint.Priority(250)

        splitViewItems = [sidebarItem, contentItem]
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

        if let autosaveName = configuration.autosaveName {
            splitView.autosaveName = autosaveName
        }

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleToggle(_:)),
            name: .toggleLeftSidebar,
            object: nil
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleSplitViewDidResize(_:)),
            name: NSSplitView.didResizeSubviewsNotification,
            object: splitView
        )

        if configuration.startsCollapsed {
            sidebarItem.isCollapsed = true
        } else if sidebarItem.isCollapsed {
            sidebarItem.isCollapsed = false
        }
    }

    override func viewDidAppear() {
        super.viewDidAppear()
        // Post initial visibility state so UI can sync
        let isVisible = !sidebarItem.isCollapsed
        postVisibilityChange(isVisible: isVisible)

        if let hoverSplitView = splitView as? HoverDividerSplitView {
            hoverSplitView.isSidebarCollapsed = !isVisible
        }
    }

    @objc private func handleToggle(_ notification: Notification) {
        guard let sourceWindow = notification.object as? NSWindow,
              sourceWindow == view.window else { return }
        toggle()
    }

    @objc private func handleSplitViewDidResize(_ notification: Notification) {
        let isVisible = !sidebarItem.isCollapsed
        postVisibilityChange(isVisible: isVisible)

        if let hoverSplitView = splitView as? HoverDividerSplitView {
            hoverSplitView.isSidebarCollapsed = !isVisible
        }
    }

    func toggle() {
        if isCollapsed {
            expand()
        } else {
            collapse()
        }
    }

    func collapse() {
        guard !sidebarItem.isCollapsed else { return }
        setSidebar(collapsed: true)
    }

    func expand() {
        guard sidebarItem.isCollapsed else { return }
        setSidebar(collapsed: false)
    }

    /// Collapses/expands the sidebar with **no animation** — `NSSplitViewItem`'s
    /// native instant collapse. Custom divider animation is intentionally
    /// omitted for now: animating the pane width (via `setPosition` or the
    /// native animator) corrupts the pane's Auto Layout subtree and clips the
    /// sidebar's trailing edge. We'll reintroduce a layout-safe animation
    /// separately.
    private func setSidebar(collapsed: Bool) {
        isProgrammaticCollapse = collapsed

        if let hoverSplitView = splitView as? HoverDividerSplitView {
            hoverSplitView.isSidebarCollapsed = collapsed
            hoverSplitView.needsDisplay = true
        }

        NotificationCenter.default.post(
            name: .sidebarAnimationWillStart,
            object: view.window,
            userInfo: ["isCollapsing": collapsed]
        )

        sidebarItem.isCollapsed = collapsed
        isProgrammaticCollapse = false

        postVisibilityChange(isVisible: !collapsed)
        NotificationCenter.default.post(name: .sidebarAnimationDidEnd, object: view.window)
    }

    private func postVisibilityChange(isVisible: Bool) {
        NotificationCenter.default.post(
            name: .sidebarVisibilityChanged,
            object: view.window,
            userInfo: ["isVisible": isVisible]
        )
    }

    // MARK: - NSSplitViewDelegate

    override func splitView(_ splitView: NSSplitView, canCollapseSubview subview: NSView) -> Bool {
        // Only allow collapse via programmatic toggle, not by dragging
        return isProgrammaticCollapse
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}
