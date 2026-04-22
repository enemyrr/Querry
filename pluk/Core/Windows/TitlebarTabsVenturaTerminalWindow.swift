import AppKit

@MainActor
class TitlebarTabsVenturaTerminalWindow: NSWindow {
    private weak var tabBarMouseTarget: NSView?
    private weak var windowDragHandle: WindowDragHandleView?

    @MainActor
    override init(contentRect: NSRect, styleMask style: NSWindow.StyleMask, backing backingStoreType: NSWindow.BackingStoreType, defer flag: Bool) {
        super.init(contentRect: contentRect, styleMask: style, backing: backingStoreType, defer: flag)
        titlebarAppearsTransparent = true
        setupFullscreenNotifications()
    }
    var titlebarContainer: NSView? {
        if !styleMask.contains(.fullScreen) {
            return contentView?.firstViewFromRoot(withClassName: "NSTitlebarContainerView")
        }

        for window in NSApplication.shared.windows {
            guard window.className == "NSToolbarFullScreenWindow" else { continue }
            guard window.parent == self else { continue }

            return window.contentView?.firstViewFromRoot(withClassName: "NSTitlebarContainerView")
        }

        return nil
    }

    // MARK: NSWindow

    override func awakeFromNib() {
        super.awakeFromNib()
        MainActor.assumeIsolated {
            titlebarAppearsTransparent = true
            setupFullscreenNotifications()
            updateTitlebarVisibility()
        }
    }

    override func toggleTabBar(_ sender: Any?) {}

    override func validateUserInterfaceItem(_ item: NSValidatedUserInterfaceItem) -> Bool {
        if item.action == #selector(toggleTabBar(_:)) {
            return false
        }
        return super.validateUserInterfaceItem(item)
    }

    private func setupFullscreenNotifications() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(windowWillEnterFullScreen(_:)),
            name: NSWindow.willEnterFullScreenNotification,
            object: self
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(windowDidEnterFullScreen(_:)),
            name: NSWindow.didEnterFullScreenNotification,
            object: self
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(windowWillExitFullScreen(_:)),
            name: NSWindow.willExitFullScreenNotification,
            object: self
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(windowDidExitFullScreen(_:)),
            name: NSWindow.didExitFullScreenNotification,
            object: self
        )
    }

    // MARK: - Titlebar Tabs

    private func updateTitlebarVisibility() {
        titleVisibility = .hidden
        titlebarAppearsTransparent = true
        titlebarSeparatorStyle = .none
        if let contentView = contentView {
            let windowFrame = frame
            let newContentFrame = NSRect(
                x: 0,
                y: 0,
                width: windowFrame.width,
                height: windowFrame.height
            )
            contentView.frame = newContentFrame
        }
        refreshWindowDragHandle()
    }

    @objc func windowWillEnterFullScreen(_ notification: Notification) {
        updateFullscreenTitlebarTransparency()
    }

    @objc func windowDidEnterFullScreen(_ notification: Notification) {
        updateFullscreenTitlebarTransparency()
    }

    @objc func windowWillExitFullScreen(_ notification: Notification) {
        updateTitlebarVisibility()
    }

    @objc func windowDidExitFullScreen(_ notification: Notification) {
        updateTitlebarVisibility()
    }

    private func updateFullscreenTitlebarTransparency() {
        if styleMask.contains(.fullScreen) {
            titlebarAppearsTransparent = true
            backgroundColor = NSColor.clear
            isOpaque = false

            self.setFullscreenTitlebarTransparent()
        }
    }

    private func setFullscreenTitlebarTransparent() {
        for window in NSApplication.shared.windows {
            guard window.className == "NSToolbarFullScreenWindow" else { continue }
            guard window.parent == self else { continue }

            window.titlebarAppearsTransparent = true
            window.backgroundColor = NSColor.clear
            window.isOpaque = false

            if let titlebarContainer = window.contentView?.firstViewFromRoot(withClassName: "NSTitlebarContainerView") {
                for effectView in titlebarContainer.descendants(withClassName: "NSVisualEffectView") {
                    effectView.isHidden = true
                }
            }
            break
        }
    }

    override func addTitlebarAccessoryViewController(_ childViewController: NSTitlebarAccessoryViewController) {
        let isTabBar = isTabBar(childViewController)

        if isTabBar {
            childViewController.layoutAttribute = .right
            updateTitlebarVisibility()
            childViewController.identifier = Self.tabBarIdentifier
        }

        super.addTitlebarAccessoryViewController(childViewController)
        scheduleWindowDragHandleRefresh()

        if #available(macOS 26, *), isTabBar {
            hideTabBarAccessoryClipViews()

            Task { @MainActor [weak self] in
                self?.hideTabBarAccessoryClipViews()
            }

            Task { @MainActor [weak self] in
                try? await Task.sleep(for: .milliseconds(100))
                self?.hideTabBarAccessoryClipViews()
            }

            Task { @MainActor [weak self] in
                try? await Task.sleep(for: .milliseconds(300))
                self?.hideTabBarAccessoryClipViews()
            }
        }
    }

    @available(macOS 26, *)
    private func hideTabBarAccessoryClipViews() {
        guard let titlebarContainer = titlebarContainer else { return }

        for clipView in titlebarContainer.descendants(withClassName: "NSTitlebarAccessoryClipView") {
            if clipView.firstDescendant(withClassName: "NSTabBar") != nil {
                clipView.isHidden = true
                clipView.frame = .zero
                clipView.alphaValue = 0
            }
        }

        for tabBar in titlebarContainer.descendants(withClassName: "NSTabBar") {
            tabBar.isHidden = true
            tabBar.frame = .zero
            tabBar.alphaValue = 0
        }

        for accessoryView in titlebarAccessoryViewControllers {
            if accessoryView.identifier == Self.tabBarIdentifier {
                accessoryView.view.isHidden = true
                accessoryView.view.frame = .zero
                accessoryView.view.alphaValue = 0
            }
        }
    }

    // MARK: Tab Bar

    static let tabBarIdentifier: NSUserInterfaceItemIdentifier = .init("_plukTabBar")

    var hasTabBar: Bool {
        contentView?.firstViewFromRoot(withClassName: "NSTabBar") != nil
    }

    func isTabBar(_ childViewController: NSTitlebarAccessoryViewController) -> Bool {
        if childViewController.identifier == nil {
            if childViewController.view.contains(className: "NSTabBar") {
                return true
            }

            if childViewController.layoutAttribute == .bottom,
               childViewController.view.className == "NSView",
               childViewController.view.subviews.isEmpty {
                return true
            }

            return false
        }

        return childViewController.identifier == Self.tabBarIdentifier
    }

    override func sendEvent(_ event: NSEvent) {
        switch event.type {
        case .keyDown:
            if shouldCloseConnectionForCommandW(event) {
                return
            }
        case .leftMouseDown:
            tabBarMouseTarget = nil
            if let target = tabBarHitTarget(for: event) {
                tabBarMouseTarget = target
                target.mouseDown(with: event)
                return
            }
        case .leftMouseDragged:
            if let target = tabBarMouseTarget {
                target.mouseDragged(with: event)
                return
            }
        case .leftMouseUp:
            if let target = tabBarMouseTarget {
                tabBarMouseTarget = nil
                target.mouseUp(with: event)
                return
            }
        default:
            break
        }
        super.sendEvent(event)
    }

    func scheduleWindowDragHandleRefresh() {
        refreshWindowDragHandle()

        Task { @MainActor [weak self] in
            self?.refreshWindowDragHandle()
        }

        Task { @MainActor [weak self] in
            try? await Task.sleep(for: .milliseconds(100))
            self?.refreshWindowDragHandle()
        }

        Task { @MainActor [weak self] in
            try? await Task.sleep(for: .milliseconds(300))
            self?.refreshWindowDragHandle()
        }
    }

    private func refreshWindowDragHandle() {
        guard !styleMask.contains(.fullScreen) else {
            windowDragHandle?.isHidden = true
            return
        }

        guard let titlebarView = standardWindowButton(.closeButton)?.superview?.superview,
              let toolbarView = titlebarView.subviews.first(where: {
                  String(describing: type(of: $0)).contains("ToolbarView")
              }),
              let hostView = titlebarView.superview
        else {
            return
        }

        let dragHandle: WindowDragHandleView
        if let windowDragHandle {
            windowDragHandle.removeFromSuperview()
            windowDragHandle.isHidden = false
            dragHandle = windowDragHandle
        } else {
            let view = WindowDragHandleView()
            view.identifier = .init("_plukWindowDragHandle")
            view.translatesAutoresizingMaskIntoConstraints = false
            windowDragHandle = view
            dragHandle = view
        }

        hostView.addSubview(dragHandle)
        NSLayoutConstraint.activate([
            dragHandle.leadingAnchor.constraint(equalTo: toolbarView.leadingAnchor),
            dragHandle.trailingAnchor.constraint(equalTo: toolbarView.trailingAnchor),
            dragHandle.topAnchor.constraint(equalTo: toolbarView.topAnchor),
            dragHandle.bottomAnchor.constraint(equalTo: toolbarView.topAnchor, constant: 12),
        ])
    }

    private func shouldCloseConnectionForCommandW(_ event: NSEvent) -> Bool {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        guard flags == .command,
              event.charactersIgnoringModifiers == "w",
              let controller = WindowController.getController(for: self) else {
            return false
        }

        return controller.closeConnectionIfDocumentTabsEmpty()
    }

    private func tabBarHitTarget(for event: NSEvent) -> NSView? {
        guard let contentView = contentView else { return nil }

        let locationInWindow = event.locationInWindow

        let point: NSPoint
        if let themeFrame = contentView.superview {
            point = themeFrame.convert(locationInWindow, from: nil)
        } else {
            point = locationInWindow
        }

        let hitView = contentView.hitTest(point)

        if hitView == nil {
            return findTabBarTarget(at: locationInWindow, in: contentView)
        }

        guard let hitView else { return nil }

        if hitView is NSControl {
            var isInsideTabBarScrollView = false
            var c: NSView? = hitView
            while let v = c {
                if v is DraggableTabNSView { isInsideTabBarScrollView = true; break }
                if v is TabBarView { break }
                c = v.superview
            }
            if !isInsideTabBarScrollView {
                return nil
            }
            return hitView
        }

        var current: NSView? = hitView
        var foundTabBar = false
        while let view = current {
            if view is DraggableTabNSView {
                return view
            }
            if view is TabBarView { foundTabBar = true }
            current = view.superview
        }

        if foundTabBar {
            return findTabBarTarget(at: locationInWindow, in: contentView)
        }
        return nil
    }

    private func findTabBarTarget(at locationInWindow: NSPoint, in view: NSView) -> NSView? {
        // Walk the view hierarchy to find DraggableTabNSViews and check close buttons
        func walk(_ v: NSView) -> NSView? {
            if let draggable = v as? DraggableTabNSView {
                let localPoint = draggable.convert(locationInWindow, from: nil)
                if draggable.bounds.contains(localPoint) {
                    // Check if the close button is at this point
                    for sub in draggable.subviews {
                        for child in sub.subviews {
                            if let btn = child as? NSButton, !btn.isHidden {
                                let btnLocal = btn.convert(locationInWindow, from: nil)
                                if btn.bounds.contains(btnLocal) {
                                    return btn
                                }
                            }
                        }
                    }
                    return draggable
                }
                return nil
            }
            for sub in v.subviews {
                if let result = walk(sub) { return result }
            }
            return nil
        }

        return walk(view)
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}

private final class WindowDragHandleView: NSView {
    override func mouseDown(with event: NSEvent) {
        if event.type == .leftMouseDown, event.clickCount == 1 {
            window?.performDrag(with: event)
            return
        }

        super.mouseDown(with: event)
    }
}
