import Cocoa

/// Titlebar tabs for macOS 13 to 15.
class TitlebarTabsVenturaTerminalWindow: NSWindow {

    override init(contentRect: NSRect, styleMask style: NSWindow.StyleMask, backing backingStoreType: NSWindow.BackingStoreType, defer flag: Bool) {
        super.init(contentRect: contentRect, styleMask: style, backing: backingStoreType, defer: flag)

        // Apply transparency immediately for programmatically created windows
        titlebarAppearsTransparent = true

        // Set up fullscreen notifications
        setupFullscreenNotifications()
    }
    // NSWindow functions:
    var titlebarContainer: NSView? {
        // If we aren't fullscreen then the titlebar container is part of our window.
        if !styleMask.contains(.fullScreen) {
            return contentView?.firstViewFromRoot(withClassName: "NSTitlebarContainerView")
        }

        // If we are fullscreen, the titlebar container view is part of a separate
        // "fullscreen window", we need to find the window and then get the view.
        for window in NSApplication.shared.windows {
            // This is the private window class that contains the toolbar
            guard window.className == "NSToolbarFullScreenWindow" else { continue }

            // The parent will match our window. This is used to filter the correct
            // fullscreen window if we have multiple.
            guard window.parent == self else { continue }

            return window.contentView?.firstViewFromRoot(withClassName: "NSTitlebarContainerView")
        }

        return nil
    }
    
    // MARK: NSWindow
    override func awakeFromNib() {
        super.awakeFromNib()

        // Apply transparency immediately
        titlebarAppearsTransparent = true
        // Set up fullscreen notifications
        setupFullscreenNotifications()

        // Ensure titlebar visibility is applied on mount
        updateTitlebarVisibility()
    }
    
    // Override to prevent tab bar from ever being shown
    override func toggleTabBar(_ sender: Any?) {
        // Do nothing - we never want to show the native tab bar
    }
    
    // Override to validate the tab bar menu item (always disabled)
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
        // Hide titlebar in non-fullscreen mode
        titleVisibility = .hidden
        titlebarAppearsTransparent = true
        titlebarSeparatorStyle = .none
        // Extend content view to cover titlebar area
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
    }

    override func toggleFullScreen(_ sender: Any?) {
        super.toggleFullScreen(sender)
    }

    @objc func windowWillEnterFullScreen(_ notification: Notification) {
        // Prepare titlebar transparency for fullscreen
        updateFullscreenTitlebarTransparency()
    }

    @objc func windowDidEnterFullScreen(_ notification: Notification) {
        // Apply fullscreen titlebar transparency
        updateFullscreenTitlebarTransparency()
    }

    @objc func windowWillExitFullScreen(_ notification: Notification) {
        // Reset titlebar transparency for windowed mode
        updateTitlebarVisibility()
    }

    @objc func windowDidExitFullScreen(_ notification: Notification) {
        // Ensure titlebar transparency is reset
        updateTitlebarVisibility()
    }

    private func updateFullscreenTitlebarTransparency() {
        // Make titlebar transparent in fullscreen
        if styleMask.contains(.fullScreen) {
            titlebarAppearsTransparent = true
            backgroundColor = NSColor.clear
            isOpaque = false

            // Also set the fullscreen window's titlebar to be transparent
            self.setFullscreenTitlebarTransparent()
        }
    }

    private func setFullscreenTitlebarTransparent() {
        // Find the fullscreen toolbar window and make its titlebar transparent
        for window in NSApplication.shared.windows {
            guard window.className == "NSToolbarFullScreenWindow" else { continue }
            guard window.parent == self else { continue }

            window.titlebarAppearsTransparent = true
            window.backgroundColor = NSColor.clear
            window.isOpaque = false

            // Hide any visual effect views in the fullscreen titlebar
            if let titlebarContainer = window.contentView?.firstViewFromRoot(withClassName: "NSTitlebarContainerView") {
                for effectView in titlebarContainer.descendants(withClassName: "NSVisualEffectView") {
                    effectView.isHidden = true
                }
            }
            break
        }
    }

    // This is called by macOS for native tabbing in order to add the tab bar. We hook into
    // this, detect the tab bar being added, and override its behavior.
    override func addTitlebarAccessoryViewController(_ childViewController: NSTitlebarAccessoryViewController) {
        let isTabBar = isTabBar(childViewController)

        if (isTabBar) {
            // Ensure it has the right layoutAttribute to force it next to our titlebar
            childViewController.layoutAttribute = .right

            // Update titlebar visibility based on fullscreen state
            updateTitlebarVisibility()

            // Mark the controller for future reference so we can easily find it. Otherwise
            // the tab bar has no ID by default.
            childViewController.identifier = Self.tabBarIdentifier
        }

        super.addTitlebarAccessoryViewController(childViewController)
    }
    
    // MARK: Tab Bar

    /// This identifier is attached to the tab bar view controller when we detect it being
    /// added.
    static let tabBarIdentifier: NSUserInterfaceItemIdentifier = .init("_plukTabBar")
    
    
    /// Returns true if there is a tab bar visible on this window.
    var hasTabBar: Bool {
        contentView?.firstViewFromRoot(withClassName: "NSTabBar") != nil
    }

    func isTabBar(_ childViewController: NSTitlebarAccessoryViewController) -> Bool {
        if childViewController.identifier == nil {
            // The good case
            if childViewController.view.contains(className: "NSTabBar") {
                return true
            }

            // When a new window is attached to an existing tab group, AppKit adds
            // an empty NSView as an accessory view and adds the tab bar later. If
            // we're at the bottom and are a single NSView we assume its a tab bar.
            if childViewController.layoutAttribute == .bottom &&
                childViewController.view.className == "NSView" &&
                childViewController.view.subviews.isEmpty {
                return true
            }

            return false
        }

        // View controllers should be tagged with this as soon as possible to
        // increase our accuracy. We do this manually.
        return childViewController.identifier == Self.tabBarIdentifier
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}
