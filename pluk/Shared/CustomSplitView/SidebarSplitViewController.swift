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

        // Both the connection-details column AND the nav rail (home + "O" +
        // feedback icons) live as direct subviews of `sidebarView`. Animate
        // each explicitly so we don't rely on layer-backed alpha/transform
        // cascading from the parent.
        let animatedViews: [NSView] = sidebarView.subviews.isEmpty
            ? [sidebarView]
            : sidebarView.subviews
        for view in animatedViews { view.wantsLayer = true }

        if let hoverSplitView = splitView as? HoverDividerSplitView {
            hoverSplitView.isSidebarCollapsed = collapsed
            hoverSplitView.needsDisplay = true
        }

        let targetWidth: CGFloat = collapsed
            ? 0
            : max(lastExpandedWidth, configuration.minWidth)
        let translationDistance: CGFloat = 12
        let duration: CFTimeInterval = 0.1

        // Drive the divider ourselves so inner SwiftUI hosting views never
        // lay out against the transient `automaticMaximumThickness`-driven
        // width NSSplitView would pick on `isCollapsed = false`.
        sidebarItem.minimumThickness = 0
        if !collapsed {
            sidebarItem.isCollapsed = false
            splitView.setPosition(0, ofDividerAt: 0)
            for view in animatedViews {
                view.alphaValue = 0
                view.layer?.transform = CATransform3DMakeTranslation(translationDistance, 0, 0)
            }
        } else {
            for view in animatedViews {
                view.alphaValue = 1
                view.layer?.transform = CATransform3DIdentity
            }
        }

        // `transform.translation.x` isn't an NSView animator key, so animate it
        // explicitly while keeping the model value in sync inside the same
        // animation group.
        let translateAnim = CABasicAnimation(keyPath: "transform.translation.x")
        translateAnim.fromValue = collapsed ? 0 : translationDistance
        translateAnim.toValue = collapsed ? translationDistance : 0
        translateAnim.duration = duration
        translateAnim.timingFunction = CAMediaTimingFunction(name: .easeOut)

        NSAnimationContext.runAnimationGroup { context in
            context.duration = duration
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            context.allowsImplicitAnimation = true

            NotificationCenter.default.post(
                name: .sidebarAnimationWillStart,
                object: self.view.window,
                userInfo: ["isCollapsing": collapsed]
            )

            splitView.animator().setPosition(targetWidth, ofDividerAt: 0)
            for view in animatedViews {
                view.animator().alphaValue = collapsed ? 0 : 1
                view.layer?.transform = collapsed
                    ? CATransform3DMakeTranslation(translationDistance, 0, 0)
                    : CATransform3DIdentity
                view.layer?.add(translateAnim, forKey: "sidebarTranslateX")
            }
        } completionHandler: { [weak self] in
            MainActor.assumeIsolated {
                guard let self else { return }
                self.isAnimating = false
                self.isProgrammaticCollapse = false

                if collapsed {
                    self.sidebarItem.isCollapsed = true
                }
                self.sidebarItem.minimumThickness = self.configuration.minWidth

                // Reset to a clean baseline so the next animation starts fresh.
                for view in animatedViews {
                    view.layer?.removeAnimation(forKey: "sidebarTranslateX")
                    view.layer?.transform = CATransform3DIdentity
                    view.alphaValue = 1
                }

                self.postVisibilityChange(isVisible: !collapsed)
                NotificationCenter.default.post(name: .sidebarAnimationDidEnd, object: self.view.window)
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
