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
    private var lastExpandedWidth: CGFloat = 330
    private var isAnimating = false
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

        contentItem = NSSplitViewItem(viewController: contentController)
        contentItem.minimumThickness = 400

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
        guard !isAnimating else { return }

        let isVisible = !sidebarItem.isCollapsed
        postVisibilityChange(isVisible: isVisible)

        if let hoverSplitView = splitView as? HoverDividerSplitView {
            hoverSplitView.isSidebarCollapsed = !isVisible
        }

        if isVisible {
            lastExpandedWidth = sidebarItem.viewController.view.frame.width
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
        guard !isAnimating, !sidebarItem.isCollapsed else { return }
        lastExpandedWidth = sidebarItem.viewController.view.frame.width
        animateSidebar(collapsed: true)
    }

    func expand() {
        guard !isAnimating, sidebarItem.isCollapsed else { return }
        animateSidebar(collapsed: false)
    }

    private func animateSidebar(collapsed: Bool) {
        isAnimating = true
        isProgrammaticCollapse = collapsed

        let sidebarView = sidebarItem.viewController.view

        if let hoverSplitView = splitView as? HoverDividerSplitView {
            hoverSplitView.isSidebarCollapsed = collapsed
            hoverSplitView.needsDisplay = true
        }

        if !collapsed {
            sidebarView.alphaValue = 0
        }

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.1
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            context.allowsImplicitAnimation = true

            NotificationCenter.default.post(
                name: .sidebarAnimationWillStart,
                object: self.view.window,
                userInfo: ["isCollapsing": collapsed]
            )

            sidebarView.animator().alphaValue = collapsed ? 0 : 1
            sidebarItem.animator().isCollapsed = collapsed
        } completionHandler: { [weak self] in
            MainActor.assumeIsolated {
                guard let self else { return }
                self.isAnimating = false
                self.isProgrammaticCollapse = false

                if !collapsed {
                    sidebarView.alphaValue = 1
                }

                self.postVisibilityChange(isVisible: !collapsed)
                NotificationCenter.default.post(name: .sidebarAnimationDidEnd, object: self.view.window)

                if !collapsed {
                    let targetWidth = max(self.lastExpandedWidth, self.configuration.minWidth)
                    self.splitView.setPosition(targetWidth, ofDividerAt: 0)
                }
            }
        }
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
