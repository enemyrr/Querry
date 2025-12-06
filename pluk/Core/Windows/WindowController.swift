//
//  WindowController.swift
//  Pluk
//
//  Simple window controller for native tab creation
//

import AppKit
import SwiftUI
import SwiftData

// MARK: - Toolbar Identifiers

/// Simple window controller that creates native tabs for connections
class WindowController: NSWindowController, NSToolbarDelegate, NSToolbarItemValidation, NSUserInterfaceValidations {
    override var windowNibName: NSNib.Name? {
        return "TerminalTabsTitlebarVentura"
    }
    
    // MARK: - Static Registry
    
    private static var windowControllers: [NSWindow: WindowController] = [:]
    private static var windowTabManagers: [NSWindow: TabManager] = [:]
    
    private static func register(_ controller: WindowController, for window: NSWindow) {
        windowControllers[window] = controller
    }
    
    static func registerTabManager(_ tabManager: TabManager, for window: NSWindow) {
        // Only register if not already registered to prevent duplicates
        if windowTabManagers[window] == nil {
            windowTabManagers[window] = tabManager
        }
    }
    
    private static func unregister(_ window: NSWindow) {
        windowControllers.removeValue(forKey: window)
        windowTabManagers.removeValue(forKey: window)
    }
    
    static func getController(for window: NSWindow) -> WindowController? {
        return windowControllers[window]
    }
    
    private static func getTabManager(for window: NSWindow) -> TabManager? {
        return windowTabManagers[window]
    }
    
    /// Get the currently active tab type based on the key window
    static func getCurrentActiveTabType() -> TabType? {
        guard let keyWindow = NSApp.keyWindow else { return nil }
        return getController(for: keyWindow)?.tabType
    }
    
    // MARK: - Static Methods
    
    /// Create a new tab using Ghostty approach with manual tab management
    @discardableResult
    static func newTab(
        tabType: TabType,
        connectionInstance: ConnectionInstance? = nil
    ) -> WindowController {
        
        // Find the main window to add tab to
        let mainWindow = NSApp.windows.first { window in
            window.isVisible && window.isMainWindow
        } ?? NSApp.windows.first { window in
            window.isVisible
        }
        
        if let parentWindow = mainWindow {
            // Create new window that will become a tab
            let controller = WindowController(
                tabType: tabType,
                connectionInstance: connectionInstance
            )
            
            // Temporarily enable tabbing for this operation
            if let newWindow = controller.window {
                // Enable tabbing temporarily for tab creation
                newWindow.tabbingMode = .preferred
                
                // Add as a tab to existing window
                parentWindow.addTabbedWindow(newWindow, ordered: .above)

                // Make the new tab active
                newWindow.makeKeyAndOrderFront(nil)
                NSApp.activate(ignoringOtherApps: true)
            }
            
            return controller
        } else {
            // No existing window, create new one
            return newWindow(tabType: tabType, connectionInstance: connectionInstance)
        }
    }
    
    /// Create a new window (not tabbed)
    @discardableResult
    static func newWindow(
        tabType: TabType,
        connectionInstance: ConnectionInstance? = nil
    ) -> WindowController {
        let controller = WindowController(
            tabType: tabType,
            connectionInstance: connectionInstance
        )
        controller.showWindow(nil)
        return controller
    }
    
    /// Switch to existing tab or create new one
    static func switchToTab(_ tabType: TabType) {
        // Find existing tab window for this tab type
        let windows = NSApp.windows.filter { $0.isVisible }
        
        for window in windows {
            if let windowController = getController(for: window) {
                let matches = switch (windowController.tabType, tabType) {
                case (.home, .home):
                    true
                case (.connection(let existingId), .connection(let targetId)):
                    existingId == targetId
                default:
                    false
                }
                
                if matches {
                    window.makeKeyAndOrderFront(nil)
                    return
                }
            }
        }
        
        // If no existing tab found, handle appropriately
        switch tabType {
        case .home:
            // For home, switch to the main window instead of creating a new tab
            if let mainWindow = NSApp.windows.first(where: { $0.isVisible && !($0.windowController is WindowController) }) {
                mainWindow.makeKeyAndOrderFront(nil)
            }
        case .connection(let instanceId):
            // For connections, create a new tab
            if let connectionInstance = ConnectionService.shared.getInstance(instanceId) {
                newTab(
                    tabType: tabType,
                    connectionInstance: connectionInstance
                )
            }
        }
    }
    
    // MARK: - Instance Properties

    let tabType: TabType
    let connectionInstance: ConnectionInstance?

    // Cache toolbar items for updating
    private var environmentToolbarItem: NSToolbarItem?
    
    // MARK: - Initialization
    
    init(tabType: TabType, connectionInstance: ConnectionInstance? = nil) {
        self.tabType = tabType
        self.connectionInstance = connectionInstance
        
        super.init(window: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    override func windowDidLoad() {
        super.windowDidLoad()
        configureWindow()
    }

    /// Adopt an existing window (e.g., from MainMenu.xib) so all setup is centralized
    convenience init(adopting window: NSWindow, tabType: TabType = .home, connectionInstance: ConnectionInstance? = nil) {
        self.init(tabType: tabType, connectionInstance: connectionInstance)
        self.window = window
        configureWindow()
    }

    /// Shared window configuration for both new and adopted windows
    private func configureWindow() {
        guard let window = self.window else { return }

        window.tabbingIdentifier = "_PlukWindow"
        window.title = windowTitle
        window.styleMask.insert(.fullSizeContentView)
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.titlebarSeparatorStyle = .none
        
        // Disable the native "Show/Hide Tab Bar" menu item and button
        if let windowMenu = NSApp.windowsMenu {
            windowMenu.items.first(where: { $0.action == #selector(NSWindow.toggleTabBar(_:)) })?.isHidden = true
        }

        window.toolbarStyle = .unifiedCompact
        window.isMovableByWindowBackground = true

        // Set window size constraints to prevent unwanted expansion
        window.contentMinSize = NSSize(width: 800, height: 600)
        window.contentMaxSize = NSSize(width: 1400, height: 1000)

        // Manually restore window frame with constraints (avoid autosave which can bypass max size)
        if let savedFrameString = UserDefaults.standard.string(forKey: "PlukWindowFrame") {
            let frame = NSRectFromString(savedFrameString)
            // Clamp the saved frame to our constraints
            let clampedWidth = min(max(frame.width, 800), 1400)
            let clampedHeight = min(max(frame.height, 600), 1000)
            let clampedFrame = NSRect(
                x: frame.origin.x,
                y: frame.origin.y,
                width: clampedWidth,
                height: clampedHeight
            )
            window.setFrame(clampedFrame, display: true)
        } else {
            // If no saved frame, set default size and center
            window.setContentSize(NSSize(width: 1200, height: 800))
            window.center()
        }
        
        window.delegate = self

        let contentView = TabAwareMainWindow(
            tabType: tabType,
            connectionInstance: connectionInstance
        )
            .modelContainer((NSApp.delegate as! AppDelegate).sharedModelContainer)
        window.contentView = NSHostingView(rootView: contentView)

        // Toolbar
        let toolbar = NSToolbar(identifier: "_PlukToolbar")
        toolbar.allowsUserCustomization = false
        toolbar.displayMode = .iconOnly
        toolbar.delegate = self
        window.toolbar = toolbar
        window.toolbar?.validateVisibleItems()

        // Register this window controller
        WindowController.register(self, for: window)

        // Set up observation for connection data changes
        setupConnectionObservation()

        // Hide tab bar immediately on window creation
        hideTabBarViews(in: window)
        
        // Also hide tab bar after a short delay to catch any that are added later
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self, weak window] in
            guard let self = self, let window = window else { return }
            self.hideTabBarViews(in: window)
        }
    }


    // MARK: - Toolbar (collapse sidebar + custom tab bar)
    func toolbarAllowedItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        // Hide collapse button for HomeView (fixed sidebar)
        if case .home = tabType {
            return []
        }

        // Add environment menu for Convex connections
        if connectionInstance?.connection.databaseType == .convex {
            return [.collapseSidebarItem, .environmentMenuItem]
        }

        return [.collapseSidebarItem]
    }

    func toolbarDefaultItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        // Hide collapse button for HomeView (fixed sidebar)
        if case .home = tabType {
            return []
        }

        // Add environment menu for Convex connections
        if connectionInstance?.connection.databaseType == .convex {
            return [.collapseSidebarItem, .environmentMenuItem]
        }

        return [.collapseSidebarItem]
    }

    func toolbar(_ toolbar: NSToolbar, itemForItemIdentifier itemIdentifier: NSToolbarItem.Identifier, willBeInsertedIntoToolbar flag: Bool) -> NSToolbarItem? {
        switch itemIdentifier {
        case .collapseSidebarItem:
            let item = NSToolbarItem(itemIdentifier: itemIdentifier)

            let buttonView = Button(action: {
                self.toggleSidebarNatively(nil)
            }) {
                Image(systemName: "sidebar.left")
                    .font(.system(size: 16))
            }
            .buttonStyle(.borderless)
            
            // Create SwiftUI button wrapped in hosting view to match environment menu approach
            let finalButtonView: AnyView
            if #available(macOS 26.0, *) {
                finalButtonView = AnyView(buttonView.padding(6).glassEffect().padding(.top, 9))
            } else {
                finalButtonView = AnyView(buttonView.padding(.top, 8))
            }
            
            let hostingView = NSHostingView(rootView: finalButtonView)
            hostingView.setContentHuggingPriority(.defaultHigh, for: .horizontal)
            hostingView.setContentCompressionResistancePriority(.defaultHigh, for: .horizontal)

            item.view = hostingView
            item.label = "Sidebar"
            item.paletteLabel = "Sidebar"
            item.toolTip = "Toggle Sidebar"

            return item

        case .environmentMenuItem:
            guard let instance = connectionInstance else { return nil }

            let item = NSToolbarItem(itemIdentifier: itemIdentifier)

            // Create a fresh SwiftUI view each time to pick up updated data
            let environmentMenu = createEnvironmentMenu(for: instance)
                .padding(.top, {
                    if #available(macOS 26, *) {
                        return 9
                    } else {
                        return 8
                    }
                }()) // Push down slightly
            let hostingView = NSHostingView(rootView: environmentMenu)

            // Set a reasonable size for the menu
            hostingView.setContentHuggingPriority(.defaultHigh, for: .horizontal)
            hostingView.setContentCompressionResistancePriority(.defaultHigh, for: .horizontal)
            
            item.view = hostingView
            item.label = "Environment"
            item.paletteLabel = "Environment"
            item.toolTip = "Switch Environment"
            
            if #available(macOS 26.0, *) {
                item.isBordered = false
            }
            
            // Cache this item for updates
            environmentToolbarItem = item
            return item

        default:
            return nil
        }
    }

    // Ensure toolbar items are enabled
    func validateToolbarItem(_ item: NSToolbarItem) -> Bool {
        return true
    }

    // Also validate via NSUserInterfaceValidations to be safe
    func validateUserInterfaceItem(_ item: NSValidatedUserInterfaceItem) -> Bool {
        return true
    }

    // MARK: - Native Sidebar Toggle

    @objc func toggleSidebarNatively(_ sender: Any?) {
        // Find the NSSplitView in the window's view hierarchy and trigger native collapse
        if let window = self.window,
           let splitView = findNSSplitView(in: window.contentView) {

            // Use proper NSSplitView collapse/expand behavior
            if let leftSubview = splitView.arrangedSubviews.first {
                let isCurrentlyCollapsed = splitView.isSubviewCollapsed(leftSubview)

                if isCurrentlyCollapsed {
                    // Expand: Set to desired width (delegate will handle proper sizing)
                    splitView.setPosition(350, ofDividerAt: 0)
                    // Show environment selector
                    environmentToolbarItem?.view?.isHidden = false
                } else {
                    // Collapse: Set position to 0 to trigger native collapse
                    splitView.setPosition(0, ofDividerAt: 0)
                    // Hide environment selector
                    environmentToolbarItem?.view?.isHidden = true
                }
            }
        }
    }

    private func findNSSplitView(in view: NSView?) -> NSSplitView? {
        guard let view = view else { return nil }

        if let splitView = view as? NSSplitView {
            return splitView
        }

        for subview in view.subviews {
            if let found = findNSSplitView(in: subview) {
                return found
            }
        }

        return nil
    }
    
    private var windowTitle: String {
        switch tabType {
        case .home:
            return "Home"
        case .connection:
            return connectionInstance?.connection.name ?? "Connection"
        }
    }

    // MARK: - Connection Observation

    private func setupConnectionObservation() {
        guard let instance = connectionInstance else { return }

        // Listen for database updates
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleDatabasesUpdated(_:)),
            name: .databasesUpdated,
            object: instance
        )

        // Listen for connected database changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleConnectedDatabaseChanged(_:)),
            name: .connectedDatabaseChanged,
            object: instance
        )
    }

    @objc private func handleDatabasesUpdated(_ notification: Notification) {
        DispatchQueue.main.async { [weak self] in
            self?.refreshEnvironmentMenuItem()
        }
    }

    @objc private func handleConnectedDatabaseChanged(_ notification: Notification) {
        DispatchQueue.main.async { [weak self] in
            self?.refreshEnvironmentMenuItem()
        }
    }

    private func refreshEnvironmentMenuItem() {
        guard let instance = connectionInstance,
              let item = environmentToolbarItem else { return }

        // Create fresh SwiftUI view with updated data
        let updatedMenu = createEnvironmentMenu(for: instance)
            .padding(.top, {
                if #available(macOS 26, *) {
                    return 9
                } else {
                    return 8
                }
            }()) // Push down slightly
        let newHostingView = NSHostingView(rootView: updatedMenu)

        // Set sizing constraints
        newHostingView.setContentHuggingPriority(.defaultHigh, for: .horizontal)
        newHostingView.setContentCompressionResistancePriority(.defaultHigh, for: .horizontal)

        // Update the toolbar item's view
        item.view = newHostingView
    }

    /// Public method to trigger immediate refresh of environment menu
    /// Call this when you know the connection's databases have been updated
    func refreshEnvironmentMenu() {
        DispatchQueue.main.async { [weak self] in
            self?.refreshEnvironmentMenuItem()
        }
    }

    // MARK: - Environment Menu

    private func createEnvironmentMenu(for instance: ConnectionInstance) -> some View {
        let menuView = Menu {
            Section {
                if !instance.databases.isEmpty {
                    ForEach(instance.databases, id: \.name) { database in
                        Toggle(isOn: Binding<Bool>(
                            get: { instance.connectedDatabase?.name == database.name },
                            set: { isOn in
                                if isOn {
                                    self.openEnvironmentInNewTab(instance: instance, database: database)
                                }
                            }
                        )) {
                            Text(database.name)
                        }
                    }
                } else {
                    Text("No environments available")
                }
            } header: {
                Text("Switch Environment")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
            }
        } label: {
            EnvironmentMenuLabel(title: currentEnvironmentTitle(instance))
        }
        .menuStyle(.button)
        .buttonStyle(.plain)
        
        // Apply glass effect only if available
        if #available(macOS 26.0, *) {
            return AnyView(menuView.glassEffect())
        } else {
            return AnyView(menuView)
        }
    }

    private func currentEnvironmentTitle(_ instance: ConnectionInstance) -> String {
        instance.connectedDatabase?.name ?? "Select Environment"
    }

    private func openEnvironmentInNewTab(instance: ConnectionInstance, database: any DatabaseWrapper) {
        Task {
            if let instanceId = await ConnectionService.shared.openEnvironmentInNewTab(from: instance, databaseName: database.name) {
                // Switch to the new tab immediately - connection happens in background
                await MainActor.run {
                    WindowController.switchToTab(.connection(instanceId))
                }
            }
        }
    }

    // MARK: - Full Screen Notifications
    @objc internal func windowDidEnterFullScreen(_ notification: Notification) {
        guard let window = notification.object as? NSWindow else { return }
        // Re-hide tab bars when entering full screen
        self.hideTabBarViews(in: window)
    }

    @objc internal func windowDidExitFullScreen(_ notification: Notification) {
        guard let window = notification.object as? NSWindow else { return }
        // Re-hide tab bars when exiting full screen
        self.hideTabBarViews(in: window)
    }

    private func hideTabBarViews(in window: NSWindow) {
        // Method 1: Hide via window's titlebar area
        hideTitlebarTabs(in: window)
        
        // Method 2: Search content view hierarchy
        if let contentView = window.contentView {
            hideTabBarInView(contentView)
        }
        
        // Method 3: Search all window subviews
        searchWindowForTabViews(window)
    }
    
    private func hideTitlebarTabs(in window: NSWindow) {
        // Look for titlebar container views
        if let titlebarView = window.standardWindowButton(.closeButton)?.superview?.superview {
            hideTabBarInView(titlebarView)
        }
    }
    
    private func searchWindowForTabViews(_ window: NSWindow) {
        // Search all subviews of the window itself
        for view in window.contentView?.superview?.subviews ?? [] {
            let className = NSStringFromClass(type(of: view))
            if className.contains("Tab") {
                hideTabBarInView(view)
            }
        }
    }
    
    private func hideTabBarInView(_ view: NSView) {
        for subview in view.subviews {
            let className = NSStringFromClass(type(of: subview))
            
            if className.contains("TabBar") ||
                className.contains("NSTabViewController") ||
                className.contains("_NSTabBarView") ||
                className.contains("NSTitlebarTabView") ||
                className.contains("NSToolbarTabView") ||
                className.contains("NSTitlebarBackgroundView") ||
                className.contains("NSGlassContainerView") ||
                className.hasSuffix("TabBarView") {
                // Remove all constraints related to this view
                if let superview = subview.superview {
                    let constraintsToRemove = superview.constraints.filter { constraint in
                        (constraint.firstItem as? NSView) == subview ||
                        (constraint.secondItem as? NSView) == subview
                    }
                    superview.removeConstraints(constraintsToRemove)
                }
                
                // Remove the view's own constraints
                subview.removeConstraints(subview.constraints)
                
                // Now safely set frame to zero
                subview.frame = NSRect.zero
                subview.isHidden = true
            }
            
            // Continue searching in subviews
            hideTabBarInView(subview)
        }
    }
}


// MARK: - NSWindowDelegate

extension WindowController: NSWindowDelegate {
    func windowDidResize(_ notification: Notification) {
        // Save window frame manually (only if within constraints)
        guard let window = notification.object as? NSWindow else { return }
        let frame = window.frame

        UserDefaults.standard.set(NSStringFromRect(frame), forKey: "PlukWindowFrame")
    }

    func windowDidBecomeMain(_ notification: Notification) {
        // Ensure tab bar stays hidden when window becomes main
        if let window = window {
            hideTabBarViews(in: window)
        }

        // Notify that the active tab has changed
        NotificationCenter.default.post(name: .tabDidChange, object: nil)
    }

    func windowWillClose(_ notification: Notification) {
        // Handle any cleanup when window closes
        if let window = window {
            // Notify TabManager to clean up document tabs for this connection
            if case .connection(_) = tabType {
                // Find the TabManager for this window and clean up
                if let tabManager = WindowController.getTabManager(for: window) {
                    // Close all non-home tabs when the native tab closes
                    let tabsToClose = tabManager.tabs.filter { $0.type != .home }
                    for tab in tabsToClose {
                        tabManager.closeTab(tab.id)
                    }
                }
            }

            WindowController.unregister(window)

            // Remove custom TabBar from content view
            if let contentView = window.contentView {
                for subview in contentView.subviews {
                    if subview is NSHostingView<TabBar> {
                        subview.removeFromSuperview()
                        print("TabBar removed from content view")
                        break
                    }
                }
            }

            // Clean up notification observers
            NotificationCenter.default.removeObserver(self, name: NSWindow.didEnterFullScreenNotification, object: window)
            NotificationCenter.default.removeObserver(self, name: NSWindow.didExitFullScreenNotification, object: window)

            // Clean up connection observation notifications
            if let instance = connectionInstance {
                NotificationCenter.default.removeObserver(self, name: .databasesUpdated, object: instance)
                NotificationCenter.default.removeObserver(self, name: .connectedDatabaseChanged, object: instance)
            }

            // Handle native tab closure
            handleNativeTabClosure(window)
        }
    }

    private func handleNativeTabClosure(_ window: NSWindow) {
        // Get all tabbed windows in this group
        let tabbedWindows = window.tabbedWindows ?? [window]

        // If this is the last tab in the group, let it close normally
        if tabbedWindows.count <= 1 {
            return
        }

        // Find another tab to make active
        for tabbedWindow in tabbedWindows {
            if tabbedWindow != window {
                // Switch to another tab before this one closes
                DispatchQueue.main.async {
                    tabbedWindow.makeKeyAndOrderFront(nil)
                }
                break
            }
        }
    }
}

// MARK: - Tab-Aware Main Window

struct TabAwareMainWindow: View {
    let tabType: TabType
    let connectionInstance: ConnectionInstance?

    @State private var appViewModel = AppViewModel()
    @State private var sidebarViewModel: SidebarViewModel
    @State private var tabManager: TabManager
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) var colorScheme

    init(tabType: TabType, connectionInstance: ConnectionInstance?) {
        self.tabType = tabType
        self.connectionInstance = connectionInstance

        // Initialize SidebarViewModel with window-specific connection instance
        self._sidebarViewModel = State(initialValue: SidebarViewModel(windowConnectionInstance: connectionInstance))

        // Initialize TabManager with native tab context
        self._tabManager = State(initialValue: TabManager(nativeTabType: tabType, connectionInstance: connectionInstance))
    }

    private var isHomeTab: Bool {
        if case .home = tabType {
            return true
        }
        return false
    }

    var body: some View {
        ZStack {
            VibrantBackgroundView()
                .edgesIgnoringSafeArea(.all)

            if colorScheme == .dark {
                Color(.windowBackgroundColor)
                    .opacity(0.80)
                    .edgesIgnoringSafeArea(.all)
            } else {
                Color(hex: 0xFFFFFF)
                    .opacity(0.10)
                    .blendMode(.multiply)
                    .edgesIgnoringSafeArea(.all)
            }

            // Show connection color for this tab's connection
            if let connectionInstance = connectionInstance {
                connectionInstance.connection.color.color
                    .opacity(0.08)
                    .blendMode(.multiply)
                    .edgesIgnoringSafeArea(.all)
            }
            
            CustomSplitView(
                sidebar: {
                    // Sidebar stays the same across all tabs
                    Sidebar()
                        .environment(connectionInstance)
                        .padding(.top, 50)
                },
                detail: {
                    // Only the detail area changes per tab
                    TabSpecificContent(tabType: tabType, connectionInstance: connectionInstance)
                },
                isFullScreenView: isHomeTab,
                isSidebarVisible: $appViewModel.isSidebarVisible,
                connectionInstance: connectionInstance
            )
            .environment(\.currentDatabaseType, connectionInstance?.connection.databaseType)
        }
        .environment(appViewModel)
        .environment(sidebarViewModel)
        .environment(tabManager)
        .onAppear {
            // Register this tab's TabManager with the window (with duplicate prevention)
            if let window = NSApp.keyWindow {
                WindowController.registerTabManager(tabManager, for: window)
            }
        }
    }
}

// MARK: - Tab Specific Content

struct TabSpecificContent: View {
    let tabType: TabType
    let connectionInstance: ConnectionInstance?

    var body: some View {
        switch tabType {
        case .home:
            HomeView()
                .padding(.top, 50)

        case .connection:
            if let connectionInstance = connectionInstance {
                DocumentView()
                    .environment(connectionInstance)
                    .padding(.top, 10)
            } else {
                // Connection not found, show error
                ConnectionNotFoundView()
            }
        }
    }
}

struct ConnectionNotFoundView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.largeTitle)
                .foregroundStyle(.orange)

            Text("Connection Not Found")
                .font(.title2)
                .fontWeight(.semibold)

            Text("This connection tab could not be loaded.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}


// MARK: - Environment Values

extension EnvironmentValues {
    @Entry var tabType: TabType = .home
    @Entry var connectionInstance: ConnectionInstance? = nil
}

struct VibrantBackgroundView: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = .sidebar
        view.blendingMode = .behindWindow
        return view
    }
    
    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {}
}

