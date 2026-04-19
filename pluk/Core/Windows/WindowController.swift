import AppKit
import SwiftData
import SwiftUI

class WindowController: NSWindowController, NSToolbarDelegate, NSToolbarItemValidation, NSUserInterfaceValidations {
    private static let windowFrameAutosaveName: NSWindow.FrameAutosaveName = "PlukMainWindow"
    private static let legacyWindowFrameDefaultsKey = "PlukWindowFrame"
    private static let minimumWindowSize = NSSize(width: 800, height: 600)
    private static let defaultWindowSize = NSSize(width: 1200, height: 800)

    override var windowNibName: NSNib.Name? {
        "TerminalTabsTitlebarVentura"
    }
    
    // MARK: - Static Registry
    
    private static var windowControllers: [NSWindow: WindowController] = [:]
    private static var windowTabManagers: [NSWindow: TabManager] = [:]
    
    private static func register(_ controller: WindowController, for window: NSWindow) {
        windowControllers[window] = controller
    }
    
    static func registerTabManager(_ tabManager: TabManager, for window: NSWindow) {
        guard windowTabManagers[window] == nil else { return }
        windowTabManagers[window] = tabManager
    }
    
    private static func unregister(_ window: NSWindow) {
        windowControllers.removeValue(forKey: window)
        windowTabManagers.removeValue(forKey: window)
    }
    
    static func getController(for window: NSWindow) -> WindowController? {
        windowControllers[window]
    }

    private static func getTabManager(for window: NSWindow) -> TabManager? {
        windowTabManagers[window]
    }
    
    static func getCurrentActiveTabType() -> TabType? {
        guard let keyWindow = NSApp.keyWindow else { return nil }
        return getController(for: keyWindow)?.tabType
    }
    
    // MARK: - Static Methods

    @discardableResult
    static func newTab(
        tabType: TabType,
        connectionInstance: ConnectionInstance? = nil
    ) -> WindowController {
        let parentWindow = NSApp.windows.first(where: { $0.isVisible && $0.isMainWindow })
            ?? NSApp.windows.first(where: { $0.isVisible })

        guard let parentWindow else {
            return newWindow(tabType: tabType, connectionInstance: connectionInstance)
        }

        let controller = WindowController(tabType: tabType, connectionInstance: connectionInstance)

        if let newWindow = controller.window {
            newWindow.setFrame(parentWindow.frame, display: false)
            newWindow.tabbingMode = .preferred
            parentWindow.addTabbedWindow(newWindow, ordered: .above)
            newWindow.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
        }

        return controller
    }

    @discardableResult
    static func newWindow(
        tabType: TabType,
        connectionInstance: ConnectionInstance? = nil
    ) -> WindowController {
        let controller = WindowController(tabType: tabType, connectionInstance: connectionInstance)
        controller.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
        return controller
    }

    @discardableResult
    static func showHome() -> WindowController {
        for window in NSApp.windows {
            guard let windowController = getController(for: window),
                  case .home = windowController.tabType else { continue }
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return windowController
        }

        return newWindow(tabType: .home)
    }

    static func switchToTab(_ tabType: TabType) {
        for window in NSApp.windows {
            guard let windowController = getController(for: window) else { continue }

            let matches = switch (windowController.tabType, tabType) {
            case (.home, .home):
                true
            case (.connection(let existingId), .connection(let targetId)):
                existingId == targetId
            case (.notebook(let existingId), .notebook(let targetId)):
                existingId == targetId
            default:
                false
            }

            if matches {
                window.makeKeyAndOrderFront(nil)
                NSApp.activate(ignoringOtherApps: true)
                return
            }
        }

        switch tabType {
        case .home:
            _ = showHome()
        case .connection(let instanceId):
            if let connectionInstance = ConnectionService.shared.getInstance(instanceId) {
                newTab(tabType: tabType, connectionInstance: connectionInstance)
            }
        case .notebook:
            newTab(tabType: tabType)
        }
    }
    
    @MainActor
    static func closeNotebookWindow(id: UUID) {
        for window in NSApp.windows {
            guard let controller = getController(for: window),
                  case .notebook(let windowNotebookId) = controller.tabType,
                  windowNotebookId == id else { continue }
            window.close()
            return
        }
    }

    // MARK: - Instance Properties

    let tabType: TabType
    private weak var connectionInstance: ConnectionInstance?
    var shouldTeardownConnectionOnClose = true
    private var environmentToolbarItem: NSToolbarItem?
    private var isRefreshingDeployments = false

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

    convenience init(adopting window: NSWindow, tabType: TabType = .home, connectionInstance: ConnectionInstance? = nil) {
        self.init(tabType: tabType, connectionInstance: connectionInstance)
        self.window = window
        configureWindow()
    }

    private func configureWindow() {
        guard let window = self.window else { return }

        window.tabbingIdentifier = "_PlukWindow"
        window.title = windowTitle
        window.styleMask.insert(.fullSizeContentView)
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.titlebarSeparatorStyle = .none

        if let windowMenu = NSApp.windowsMenu {
            windowMenu.items.first(where: { $0.action == #selector(NSWindow.toggleTabBar(_:)) })?.isHidden = true
        }

        window.toolbarStyle = .unifiedCompact
        window.isMovableByWindowBackground = true
        restoreWindowFrame(window)

        window.delegate = self

        let mainVC = MainContentViewController(
            tabType: tabType,
            connectionInstance: connectionInstance,
            modelContainer: (NSApp.delegate as! AppDelegate).sharedModelContainer
        )
        window.contentViewController = mainVC

        let toolbar = NSToolbar(identifier: "_PlukToolbar")
        toolbar.allowsUserCustomization = false
        toolbar.displayMode = .iconOnly
        toolbar.delegate = self
        window.toolbar = toolbar
        toolbar.validateVisibleItems()

        WindowController.register(self, for: window)
        setupConnectionObservation()

        hideTabBarViews(in: window)
        Task { [weak self, weak window] in
            try? await Task.sleep(for: .milliseconds(100))
            guard let self, let window else { return }
            self.hideTabBarViews(in: window)
        }
    }

    private func restoreWindowFrame(_ window: NSWindow) {
        let restoredFrame = window.setFrameUsingName(Self.windowFrameAutosaveName)
        window.setFrameAutosaveName(Self.windowFrameAutosaveName)

        if restoredFrame {
            let clampedFrame = clampedWindowFrame(window.frame)
            if clampedFrame != window.frame {
                window.setFrame(clampedFrame, display: true)
            }
            persistWindowFrame(window)
            return
        }

        if let legacyFrame = legacyWindowFrame() {
            window.setFrame(clampedWindowFrame(legacyFrame), display: true)
            UserDefaults.standard.removeObject(forKey: Self.legacyWindowFrameDefaultsKey)
            persistWindowFrame(window)
            return
        }

        window.setContentSize(Self.defaultWindowSize)
        window.center()
        persistWindowFrame(window)
    }

    private func legacyWindowFrame() -> NSRect? {
        guard let savedFrameString = UserDefaults.standard.string(forKey: Self.legacyWindowFrameDefaultsKey) else {
            return nil
        }

        let frame = NSRectFromString(savedFrameString)
        guard frame.width > 0, frame.height > 0 else { return nil }
        return frame
    }

    private func clampedWindowFrame(_ frame: NSRect) -> NSRect {
        NSRect(
            x: frame.origin.x,
            y: frame.origin.y,
            width: max(frame.width, Self.minimumWindowSize.width),
            height: max(frame.height, Self.minimumWindowSize.height)
        )
    }

    private func persistWindowFrame(_ window: NSWindow) {
        window.saveFrame(usingName: Self.windowFrameAutosaveName)
    }

    // MARK: - Toolbar

    private var toolbarIdentifiers: [NSToolbarItem.Identifier] {
        switch tabType {
        case .connection:
            if connectionInstance?.connection.databaseType == .convex {
                return [.collapseSidebarItem, .environmentMenuItem]
            }
            return [.collapseSidebarItem]
        case .notebook:
            return []
        case .home:
            return []
        }
    }

    func toolbarAllowedItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        toolbarIdentifiers
    }

    func toolbarDefaultItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        toolbarIdentifiers
    }

    private var toolbarItemTopPadding: CGFloat {
        if #available(macOS 26, *) { 9 } else { 8 }
    }

    func toolbar(_ toolbar: NSToolbar, itemForItemIdentifier itemIdentifier: NSToolbarItem.Identifier, willBeInsertedIntoToolbar flag: Bool) -> NSToolbarItem? {
        switch itemIdentifier {
        case .collapseSidebarItem:
            return makeSidebarToggleItem(identifier: itemIdentifier)
        case .environmentMenuItem:
            return makeEnvironmentItem(identifier: itemIdentifier)
        default:
            return nil
        }
    }

    private func makeSidebarToggleItem(identifier: NSToolbarItem.Identifier) -> NSToolbarItem {
        let item = NSToolbarItem(itemIdentifier: identifier)

        let buttonView = SidebarToggleButtonView {
            self.toggleSidebarNatively(nil)
        }

        let hostingView = NSHostingView(rootView: sidebarToggleContent(buttonView))
        hostingView.setContentHuggingPriority(.defaultHigh, for: .horizontal)
        hostingView.setContentCompressionResistancePriority(.defaultHigh, for: .horizontal)

        item.view = hostingView
        item.label = "Sidebar"
        item.paletteLabel = "Sidebar"
        item.toolTip = nil

        return item
    }

    private func sidebarToggleContent(_ buttonView: SidebarToggleButtonView) -> some View {
        buttonView.padding(.top, toolbarItemTopPadding)
    }

    private func makeEnvironmentItem(identifier: NSToolbarItem.Identifier) -> NSToolbarItem? {
        guard let instance = connectionInstance else { return nil }

        let item = NSToolbarItem(itemIdentifier: identifier)

        let environmentMenu = createEnvironmentMenu(for: instance)
            .padding(.top, toolbarItemTopPadding)
        let hostingView = NSHostingView(rootView: environmentMenu)
        hostingView.setContentHuggingPriority(.defaultHigh, for: .horizontal)
        hostingView.setContentCompressionResistancePriority(.defaultHigh, for: .horizontal)

        item.view = hostingView
        item.label = "Environment"
        item.paletteLabel = "Environment"
        item.toolTip = "Switch Environment"

        if #available(macOS 26.0, *) {
            item.isBordered = false
        }

        environmentToolbarItem = item
        return item
    }

    func validateToolbarItem(_ item: NSToolbarItem) -> Bool {
        true
    }

    func validateUserInterfaceItem(_ item: NSValidatedUserInterfaceItem) -> Bool {
        true
    }

    // MARK: - Native Sidebar Toggle

    @objc func toggleSidebarNatively(_ sender: Any?) {
        guard let window = self.window else { return }
        if case .notebook = tabType { return }

        NotificationCenter.default.post(name: .toggleLeftSidebar, object: window)

        Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(50))
            if let controller = self?.findSidebarController(in: window.contentView) {
                self?.environmentToolbarItem?.view?.isHidden = controller.isCollapsed
            }
        }
    }

    private func findSidebarController(in view: NSView?) -> SidebarSplitViewController? {
        guard let view else { return nil }

        if let controller = view.nextResponder as? SidebarSplitViewController {
            return controller
        }

        for subview in view.subviews {
            if let found = findSidebarController(in: subview) {
                return found
            }
        }

        return nil
    }
    
    private var windowTitle: String {
        switch tabType {
        case .home:
            "Home"
        case .connection:
            connectionInstance?.connection.name ?? "Connection"
        case .notebook(let notebookId):
            notebookTitle(for: notebookId)
        }
    }

    private func notebookTitle(for notebookId: UUID) -> String {
        let container = (NSApp.delegate as? AppDelegate)?.sharedModelContainer
        if let context = container?.mainContext,
           let notebook = try? context.fetch(
               FetchDescriptor<Notebook>(predicate: #Predicate { $0.id == notebookId })
           ).first {
            return notebook.title
        }
        return "Notebook"
    }

    // MARK: - Connection Observation

    private func setupConnectionObservation() {
        guard let instance = connectionInstance else { return }

        for name in [Notification.Name.databasesUpdated, .connectedDatabaseChanged] {
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(handleEnvironmentChange(_:)),
                name: name,
                object: instance
            )
        }
    }

    @objc private func handleEnvironmentChange(_ notification: Notification) {
        Task { @MainActor [weak self] in
            self?.refreshEnvironmentMenu()
        }
    }

    func refreshEnvironmentMenu() {
        guard let instance = connectionInstance,
              let item = environmentToolbarItem else { return }

        let updatedMenu = createEnvironmentMenu(for: instance)
            .padding(.top, toolbarItemTopPadding)
        let newHostingView = NSHostingView(rootView: updatedMenu)
        newHostingView.setContentHuggingPriority(.defaultHigh, for: .horizontal)
        newHostingView.setContentCompressionResistancePriority(.defaultHigh, for: .horizontal)

        item.view = newHostingView
    }

    // MARK: - Environment Menu

    private func createEnvironmentMenu(for instance: ConnectionInstance) -> some View {
        let menuView = Menu {
            Section {
                if !instance.databases.isEmpty {
                    ForEach(instance.databases.sorted(by: { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }), id: \.name) { database in
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

            Section {
                Button {
                    Task {
                        await self.refreshDeployments(for: instance)
                    }
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
            }
        } label: {
            EnvironmentMenuLabel(title: currentEnvironmentTitle(instance), isLoading: isRefreshingDeployments)
        }
        .menuStyle(.button)
        .buttonStyle(.plain)

        if #available(macOS 26.0, *) {
            return AnyView(menuView.glassEffect())
        } else {
            return AnyView(menuView)
        }
    }

    private func refreshDeployments(for instance: ConnectionInstance) async {
        await MainActor.run {
            isRefreshingDeployments = true
            refreshEnvironmentMenu()
        }

        do {
            let fresh = try await instance.databaseService.refreshConvexDeployments()
            await MainActor.run {
                instance.databases = fresh
                isRefreshingDeployments = false
                refreshEnvironmentMenu()

                Task { @MainActor in
                    if let updatedToken = await instance.databaseService.buildUpdatedConvexEmbeddedToken() {
                        instance.connection.password = updatedToken
                    }
                }
            }
        } catch {
            debugLog("Failed to refresh deployments: \(error)")
            await MainActor.run {
                isRefreshingDeployments = false
                refreshEnvironmentMenu()
            }
        }
    }

    private func currentEnvironmentTitle(_ instance: ConnectionInstance) -> String {
        instance.connectedDatabase?.name ?? "Select Environment"
    }

    private func openEnvironmentInNewTab(instance: ConnectionInstance, database: any DatabaseWrapper) {
        Task {
            guard let instanceId = await ConnectionService.shared.openEnvironmentInNewTab(from: instance, databaseName: database.name) else { return }

            let tabTitle = "\(instance.connection.name) – \(database.name)"
            let appliedImmediately = await MainActor.run {
                WindowController.switchToTab(.connection(instanceId))
                return ConnectionService.shared.updateTabTitle(for: instanceId, title: tabTitle)
            }

            guard !appliedImmediately else { return }

            try? await Task.sleep(for: .milliseconds(100))
            await MainActor.run {
                _ = ConnectionService.shared.updateTabTitle(for: instanceId, title: tabTitle)
            }
        }
    }

    // MARK: - Full Screen

    @objc internal func windowDidEnterFullScreen(_ notification: Notification) {
        guard let window = notification.object as? NSWindow else { return }
        hideTabBarViews(in: window)
    }

    @objc internal func windowDidExitFullScreen(_ notification: Notification) {
        guard let window = notification.object as? NSWindow else { return }
        hideTabBarViews(in: window)
    }

    // MARK: - Tab Bar Hiding

    private static let tabBarClassNamePatterns = [
        "TabBar", "NSTabViewController", "_NSTabBarView",
        "NSTitlebarTabView", "NSToolbarTabView",
        "NSTitlebarBackgroundView", "NSGlassContainerView",
    ]

    private func hideTabBarViews(in window: NSWindow) {
        if let titlebarView = window.standardWindowButton(.closeButton)?.superview?.superview {
            hideTabBarInView(titlebarView)
        }

        if let contentView = window.contentView {
            hideTabBarInView(contentView)
        }

        for view in window.contentView?.superview?.subviews ?? [] {
            if NSStringFromClass(type(of: view)).contains("Tab") {
                hideTabBarInView(view)
            }
        }
    }

    private func hideTabBarInView(_ view: NSView) {
        for subview in view.subviews {
            let className = NSStringFromClass(type(of: subview))

            let isTabBar = Self.tabBarClassNamePatterns.contains(where: { className.contains($0) })
                || className.hasSuffix("TabBarView")
            let isOurs = subview is TabBarView
            guard !isOurs else { continue }

            if isTabBar {
                if let superview = subview.superview {
                    let related = superview.constraints.filter {
                        ($0.firstItem as? NSView) == subview || ($0.secondItem as? NSView) == subview
                    }
                    superview.removeConstraints(related)
                }
                subview.removeConstraints(subview.constraints)
                subview.frame = .zero
                subview.isHidden = true
            }

            hideTabBarInView(subview)
        }
    }
}

// MARK: - NSWindowDelegate

extension WindowController: NSWindowDelegate {
    func windowWillResize(_ sender: NSWindow, to frameSize: NSSize) -> NSSize {
        NSSize(
            width: max(frameSize.width, Self.minimumWindowSize.width),
            height: max(frameSize.height, Self.minimumWindowSize.height)
        )
    }

    func windowDidResize(_ notification: Notification) {
        guard let window = notification.object as? NSWindow else { return }
        persistWindowFrame(window)
    }

    func windowDidMove(_ notification: Notification) {
        guard let window = notification.object as? NSWindow else { return }
        persistWindowFrame(window)
    }

    func windowDidBecomeMain(_ notification: Notification) {
        if let window {
            hideTabBarViews(in: window)
        }
        NotificationCenter.default.post(name: .tabDidChange, object: nil)
    }

    func windowWillClose(_ notification: Notification) {
        guard let window else { return }
        let closingConnectionInstance = connectionInstance

        if case .connection = tabType,
           let tabManager = WindowController.getTabManager(for: window) {
            let tabsToClose = tabManager.tabs.filter { $0.type != .home }
            for tab in tabsToClose {
                tabManager.closeTab(tab.id)
            }
        }

        if case .connection(let instanceId) = tabType,
           shouldTeardownConnectionOnClose {
            Task { @MainActor in
                await ConnectionService.shared.removeConnectionInstance(instanceId, closeWindow: false)
            }
        }

        if case .notebook(let notebookId) = tabType {
            let hasOtherNotebookWindow = NSApp.windows.contains { candidate in
                guard candidate != window,
                      let controller = WindowController.getController(for: candidate),
                      case .notebook(let candidateNotebookId) = controller.tabType else { return false }
                return candidateNotebookId == notebookId
            }

            if !hasOtherNotebookWindow {
                SidebarItemRegistry.shared.removeNotebook(notebookId)
            }
        }

        WindowController.unregister(window)

        window.contentView?.subviews
            .first { $0 is TabBarView }?
            .removeFromSuperview()

        NotificationCenter.default.removeObserver(self, name: NSWindow.didEnterFullScreenNotification, object: window)
        NotificationCenter.default.removeObserver(self, name: NSWindow.didExitFullScreenNotification, object: window)

        if let instance = closingConnectionInstance {
            NotificationCenter.default.removeObserver(self, name: .databasesUpdated, object: instance)
            NotificationCenter.default.removeObserver(self, name: .connectedDatabaseChanged, object: instance)
        }

        activateNextTab(closing: window)
        window.delegate = nil
        window.toolbar = nil
        environmentToolbarItem = nil
        window.contentViewController = nil
        self.window = nil
    }

    private func activateNextTab(closing window: NSWindow) {
        let tabbedWindows = window.tabbedWindows ?? [window]
        guard tabbedWindows.count > 1,
              let nextWindow = tabbedWindows.first(where: { $0 != window }) else { return }

        Task { @MainActor in
            nextWindow.makeKeyAndOrderFront(nil)
        }
    }
}

// MARK: - Sidebar Toggle Button

private struct SidebarToggleButtonView: View {
    var action: () -> Void
    @State private var isHovering = false
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Button(action: action) {
            Image(systemName: "sidebar.left")
                .font(.system(size: 16))
                .frame(width: 28, height: 28)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(isHovering ? hoverColor : .clear)
                )
        }
        .buttonStyle(.borderless)
        .customHelp("Toggle Sidebar", shortcut: .init(modifiers: [.command], key: "["))
        .onHover { hovering in
            isHovering = hovering
        }
    }

    private var hoverColor: Color {
        colorScheme == .dark
            ? Color.white.opacity(0.12)
            : Color(nsColor: .controlColor).opacity(0.8)
    }
}

// MARK: - Connection Not Found View

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
