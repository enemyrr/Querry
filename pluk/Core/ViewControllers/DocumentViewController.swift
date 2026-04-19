import AppKit
import Observation
import SwiftData
import SwiftUI

final class DocumentViewController: NSViewController {

    private let instance: ConnectionInstance
    private let appViewModel: AppViewModel
    private let sidebarViewModel: SidebarViewModel
    private let tabManager: TabManager
    private let modelContainer: ModelContainer

    private var tabView: NSTabView!
    private var tabBarView: TabBarView?
    private var rightSidebarViewController: RowDetailSidebarViewController?
    private var emptyStateView: EmptyDocumentStateView?

    private var contentContainer: NSView!
    private var tabViewContainer: NSView!

    private var tabContentControllers: [String: NSViewController] = [:]

    private var isSidebarVisible = true
    private var isUpdatingTabs = false
    private var isAnimatingRightSidebar = false

    private var barHeight: CGFloat {
        if #available(macOS 26, *) { 46 } else { 44 }
    }

    private var contentLeadingConstraint: NSLayoutConstraint?
    private var rightSidebarWidthConstraint: NSLayoutConstraint?
    private var tabViewTrailingToSidebar: NSLayoutConstraint?
    private var tabViewTrailingToContainer: NSLayoutConstraint?

    init(
        instance: ConnectionInstance,
        appViewModel: AppViewModel,
        sidebarViewModel: SidebarViewModel,
        tabManager: TabManager,
        modelContainer: ModelContainer
    ) {
        self.instance = instance
        self.appViewModel = appViewModel
        self.sidebarViewModel = sidebarViewModel
        self.tabManager = tabManager
        self.modelContainer = modelContainer
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    // MARK: - Environment Injection

    private func injectEnvironments<V: View>(_ view: V) -> some View {
        view
            .environment(instance)
            .environment(appViewModel)
            .environment(sidebarViewModel)
            .environment(tabManager)
            .environment(\.currentDatabaseType, instance.connection.databaseType)
            .modelContainer(modelContainer)
    }

    // MARK: - View Lifecycle

    override func loadView() {
        let root = NSView()
        root.wantsLayer = true
        self.view = root

        setupTabView()
        setupLayout()
        startObserving()
    }

    override func viewDidAppear() {
        super.viewDidAppear()
        syncInitialSidebarState()
        syncTabsToView()
    }

    // MARK: - Tab View Setup

    private func setupTabView() {
        tabView = NSTabView()
        tabView.delegate = self
        tabView.tabViewType = .noTabsNoBorder
        tabView.drawsBackground = false
        tabView.focusRingType = .none
    }

    // MARK: - Layout

    private func setupLayout() {
        let hasTabs = !instance.tabs.isEmpty

        if hasTabs {
            setupTabsLayout()
        } else {
            setupEmptyState()
        }
    }

    private func setupTabsLayout() {
        removeEmptyState()

        let bar = TabBarView(instance: instance, appViewModel: appViewModel)
        bar.translatesAutoresizingMaskIntoConstraints = false
        tabBarView = bar

        contentContainer = NSView()
        contentContainer.wantsLayer = true
        contentContainer.translatesAutoresizingMaskIntoConstraints = false

        tabViewContainer = NSView()
        tabViewContainer.wantsLayer = true
        tabViewContainer.layer?.cornerRadius = 10
        tabViewContainer.shadow = makeShadow()
        tabViewContainer.translatesAutoresizingMaskIntoConstraints = false

        tabView.translatesAutoresizingMaskIntoConstraints = false
        tabViewContainer.addSubview(tabView)

        contentContainer.addSubview(tabViewContainer)

        view.addSubview(bar)
        view.addSubview(contentContainer)

        NSLayoutConstraint.activate([
            bar.topAnchor.constraint(equalTo: view.topAnchor),
            bar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            bar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            bar.heightAnchor.constraint(equalToConstant: barHeight),

            contentContainer.topAnchor.constraint(equalTo: bar.bottomAnchor, constant: 6),
            contentContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -12),
            contentContainer.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -12),

            tabView.topAnchor.constraint(equalTo: tabViewContainer.topAnchor),
            tabView.leadingAnchor.constraint(equalTo: tabViewContainer.leadingAnchor),
            tabView.trailingAnchor.constraint(equalTo: tabViewContainer.trailingAnchor),
            tabView.bottomAnchor.constraint(equalTo: tabViewContainer.bottomAnchor),
        ])

        let leading = contentContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: isSidebarVisible ? 2 : 14)
        leading.isActive = true
        contentLeadingConstraint = leading

        setupTabViewContainerConstraints()
        updateRightSidebar()
    }

    private func setupTabViewContainerConstraints() {
        guard let contentContainer else { return }

        let trailingConstraint = tabViewContainer.trailingAnchor.constraint(equalTo: contentContainer.trailingAnchor)
        tabViewTrailingToContainer = trailingConstraint

        NSLayoutConstraint.activate([
            tabViewContainer.topAnchor.constraint(equalTo: contentContainer.topAnchor),
            tabViewContainer.leadingAnchor.constraint(equalTo: contentContainer.leadingAnchor),
            tabViewContainer.bottomAnchor.constraint(equalTo: contentContainer.bottomAnchor),
            trailingConstraint,
        ])
    }

    private func setupEmptyState() {
        removeTabsLayout()

        let emptyView = EmptyDocumentStateView(instance: instance)
        emptyView.translatesAutoresizingMaskIntoConstraints = false
        emptyStateView = emptyView

        view.addSubview(emptyView)

        let leading = emptyView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: isSidebarVisible ? 2 : 14)
        contentLeadingConstraint = leading

        let topInset: CGFloat = if #available(macOS 26, *) { 52 } else { 50 }

        NSLayoutConstraint.activate([
            emptyView.topAnchor.constraint(equalTo: view.topAnchor, constant: topInset),
            leading,
            emptyView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -12),
            emptyView.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -12),
        ])
    }

    private func removeTabsLayout() {
        contentLeadingConstraint = nil
        tabBarView?.removeFromSuperview()
        tabBarView = nil
        contentContainer?.removeFromSuperview()
        contentContainer = nil
        tabViewContainer = nil
        rightSidebarViewController?.view.removeFromSuperview()
        rightSidebarViewController?.removeFromParent()
        rightSidebarViewController = nil
        tabViewTrailingToContainer = nil
        tabViewTrailingToSidebar = nil

        for vc in tabContentControllers.values {
            vc.removeFromParent()
        }
        tabContentControllers.removeAll()

        view.window?.isMovable = true
    }

    private func removeEmptyState() {
        contentLeadingConstraint = nil
        emptyStateView?.tearDown()
        emptyStateView?.removeFromSuperview()
        emptyStateView = nil
    }

    private func makeShadow() -> NSShadow {
        let shadow = NSShadow()
        shadow.shadowColor = NSColor.black.withAlphaComponent(0.10)
        shadow.shadowBlurRadius = 1
        shadow.shadowOffset = .zero
        return shadow
    }

    // MARK: - Right Sidebar

    private func updateRightSidebar() {
        guard !isAnimatingRightSidebar, contentContainer != nil, tabViewContainer != nil else { return }

        if appViewModel.isRightSidebarVisible {
            showRightSidebar()
            applyRightSidebarWidth()
        } else {
            hideRightSidebar()
        }
    }

    private func showRightSidebar(initialWidth: CGFloat? = nil) {
        guard rightSidebarViewController == nil,
              let contentContainer,
              let tabViewContainer else { return }

        let sidebarViewController = RowDetailSidebarViewController(
            instance: instance,
            appViewModel: appViewModel,
            onWidthChange: { [weak self] _ in
                self?.applyRightSidebarWidth()
            }
        )
        addChild(sidebarViewController)

        let sidebarView = sidebarViewController.view
        sidebarView.translatesAutoresizingMaskIntoConstraints = false
        sidebarView.shadow = makeShadow()
        rightSidebarViewController = sidebarViewController

        contentContainer.addSubview(sidebarView)

        tabViewTrailingToContainer?.isActive = false

        let trailingToSidebar = tabViewContainer.trailingAnchor.constraint(equalTo: sidebarView.leadingAnchor)
        let widthConstraint = sidebarView.widthAnchor.constraint(equalToConstant: initialWidth ?? appViewModel.rightSidebarWidth)
        tabViewTrailingToSidebar = trailingToSidebar
        rightSidebarWidthConstraint = widthConstraint

        NSLayoutConstraint.activate([
            sidebarView.topAnchor.constraint(equalTo: contentContainer.topAnchor),
            sidebarView.trailingAnchor.constraint(equalTo: contentContainer.trailingAnchor),
            sidebarView.bottomAnchor.constraint(equalTo: contentContainer.bottomAnchor),
            widthConstraint,
            trailingToSidebar,
        ])
    }

    private func hideRightSidebar() {
        guard rightSidebarViewController != nil else { return }

        tabViewTrailingToSidebar?.isActive = false
        tabViewTrailingToSidebar = nil
        rightSidebarWidthConstraint = nil

        rightSidebarViewController?.view.removeFromSuperview()
        rightSidebarViewController?.removeFromParent()
        rightSidebarViewController = nil

        tabViewTrailingToContainer?.isActive = true
    }

    private func applyRightSidebarWidth() {
        guard appViewModel.isRightSidebarVisible,
              let contentContainer,
              let widthConstraint = rightSidebarWidthConstraint
        else { return }

        let targetWidth = appViewModel.rightSidebarWidth
        guard widthConstraint.constant != targetWidth else { return }

        widthConstraint.constant = targetWidth
        contentContainer.layoutSubtreeIfNeeded()
        rightSidebarViewController?.view.layoutSubtreeIfNeeded()
    }

    // MARK: - Tab Syncing

    private func syncTabsToView() {
        guard !isUpdatingTabs else { return }
        isUpdatingTabs = true
        defer { isUpdatingTabs = false }

        let currentIds = Set(tabView.tabViewItems.compactMap { $0.identifier as? String })
        let expectedIds = Set(instance.tabs.map { $0.id.uuidString })

        for id in currentIds where !expectedIds.contains(id) {
            if let item = tabView.tabViewItems.first(where: { ($0.identifier as? String) == id }) {
                tabView.removeTabViewItem(item)
            }
            if let vc = tabContentControllers.removeValue(forKey: id) {
                vc.removeFromParent()
            }
        }

        for (index, tab) in instance.tabs.enumerated() {
            let identifier = tab.id.uuidString
            let tabLabel = tab.hasSchemaDeviation ? "\(tab.name)*" : tab.name
            let iconName = getTabIconName(for: tab, databaseType: instance.connection.databaseType)

            if let existingItem = tabView.tabViewItems.first(where: { ($0.identifier as? String) == identifier }) {
                existingItem.label = tabLabel
                existingItem.image = NSImage(systemSymbolName: iconName, accessibilityDescription: nil)
            } else {
                let tabViewItem = NSTabViewItem(identifier: identifier)
                tabViewItem.label = tabLabel
                tabViewItem.image = NSImage(systemSymbolName: iconName, accessibilityDescription: nil)
                tabViewItem.view = makeTabContentView(for: tab)

                if index < tabView.numberOfTabViewItems {
                    tabView.insertTabViewItem(tabViewItem, at: index)
                } else {
                    tabView.addTabViewItem(tabViewItem)
                }
            }
        }

        if let selectedTab = instance.selectedTab,
           let item = tabView.tabViewItems.first(where: { ($0.identifier as? String) == selectedTab.id.uuidString }) {
            tabView.selectTabViewItem(item)
        }
    }

    private func makeTabContentView(for tab: DatabaseTab) -> NSView {
        let dbType = instance.connection.databaseType

        let isTableTab = tab.type == .browse || tab.type == .aggregate || tab.type == .schema || tab.type == .indexes
        if isTableTab, [.postgres, .sqlite, .mysql, .convex].contains(dbType) {
            let tableVC = TableContentViewController(
                tab: tab,
                instance: instance,
                appViewModel: appViewModel,
                sidebarViewModel: sidebarViewModel,
                tabManager: tabManager,
                modelContainer: modelContainer
            )
            addChild(tableVC)
            tabContentControllers[tab.id.uuidString] = tableVC
            return tableVC.view
        }

        return TabContentView(tab: tab, databaseType: dbType, environmentInjector: { [weak self] view in
            guard let self else { return AnyView(view) }
            return AnyView(injectEnvironments(view))
        }, instance: instance)
    }

    private func syncInitialSidebarState() {
        var current: NSViewController? = parent
        while let vc = current {
            if let splitVC = vc as? SidebarSplitViewController {
                isSidebarVisible = !splitVC.isCollapsed
                contentLeadingConstraint?.constant = isSidebarVisible ? 2 : 14
                return
            }
            current = vc.parent
        }
    }

    // MARK: - Observation

    private func startObserving() {
        observeTabs()
        observeRightSidebar()

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleToggleRightSidebar),
            name: .toggleRightSidebar,
            object: nil
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleSidebarAnimationWillStart(_:)),
            name: .sidebarAnimationWillStart,
            object: nil
        )
    }

    private func observeTabs() {
        withObservationTracking {
            _ = self.instance.tabs
            _ = self.instance.tabs.map(\.id)
            _ = self.instance.tabs.map(\.name)
            _ = self.instance.tabs.map(\.hasSchemaDeviation)
            _ = self.instance.selectedTab
        } onChange: { [weak self] in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.handleTabsChanged()
                self.observeTabs()
            }
        }
    }

    private func observeRightSidebar() {
        withObservationTracking {
            _ = self.appViewModel.isRightSidebarVisible
            _ = self.appViewModel.rightSidebarWidth
        } onChange: { [weak self] in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.updateRightSidebar()
                self.observeRightSidebar()
            }
        }
    }

    private func handleTabsChanged() {
        let hasTabs = !instance.tabs.isEmpty
        let hasTabsLayout = tabBarView != nil

        if hasTabs && !hasTabsLayout {
            setupTabsLayout()
        } else if !hasTabs && hasTabsLayout {
            setupEmptyState()
        }

        if hasTabs {
            syncTabsToView()
        }
    }

    @objc private func handleToggleRightSidebar() {
        guard !isAnimatingRightSidebar else { return }

        appViewModel.isRightSidebarVisible.toggle()

        if appViewModel.isRightSidebarVisible {
            showRightSidebarAnimated()
        } else {
            hideRightSidebarAnimated()
        }
    }

    private func showRightSidebarAnimated() {
        isAnimatingRightSidebar = true
        showRightSidebar(initialWidth: 0)
        contentContainer?.layoutSubtreeIfNeeded()

        rightSidebarViewController?.view.alphaValue = 0

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.2
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            context.allowsImplicitAnimation = true
            self.rightSidebarWidthConstraint?.constant = self.appViewModel.rightSidebarWidth
            self.rightSidebarViewController?.view.animator().alphaValue = 1
            self.contentContainer?.layoutSubtreeIfNeeded()
        } completionHandler: { [weak self] in
            Task { @MainActor [weak self] in
                self?.isAnimatingRightSidebar = false
            }
        }
    }

    private func hideRightSidebarAnimated() {
        guard rightSidebarViewController != nil else { return }
        isAnimatingRightSidebar = true

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.15
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            context.allowsImplicitAnimation = true
            self.rightSidebarWidthConstraint?.constant = 0
            self.rightSidebarViewController?.view.animator().alphaValue = 0
            self.contentContainer?.layoutSubtreeIfNeeded()
        } completionHandler: { [weak self] in
            Task { @MainActor [weak self] in
                self?.hideRightSidebar()
                self?.isAnimatingRightSidebar = false
            }
        }
    }

    @objc private func handleSidebarAnimationWillStart(_ notification: Notification) {
        guard notification.object as? NSWindow == view.window else { return }
        let isCollapsing = notification.userInfo?["isCollapsing"] as? Bool ?? false
        isSidebarVisible = !isCollapsing
        contentLeadingConstraint?.constant = isSidebarVisible ? 2 : 14
        view.layoutSubtreeIfNeeded()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}

// MARK: - NSTabViewDelegate

extension DocumentViewController: NSTabViewDelegate {
    func tabView(_ tabView: NSTabView, didSelect tabViewItem: NSTabViewItem?) {
        guard !isUpdatingTabs,
              let identifier = tabViewItem?.identifier as? String,
              let tab = instance.tabs.first(where: { $0.id.uuidString == identifier })
        else { return }
        instance.selectTab(tab)
    }

    func tabView(_ tabView: NSTabView, willSelect tabViewItem: NSTabViewItem?) {
        tabViewItem?.view?.menu = nil
    }
}

// MARK: - Empty Document State

private final class EmptyDocumentStateView: NSView {

    private let instance: ConnectionInstance
    private var emptyStateVC: EmptyStateViewController?

    init(instance: ConnectionInstance) {
        self.instance = instance
        super.init(frame: .zero)
        wantsLayer = true
        setupAppearance()
        setupEmptyStateContent()

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAppearanceChange),
            name: .appAppearanceDidChange,
            object: nil
        )
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    private func setupAppearance() {
        layer?.cornerRadius = 10

        let s = NSShadow()
        s.shadowColor = NSColor.black.withAlphaComponent(0.10)
        s.shadowBlurRadius = 1
        s.shadowOffset = .zero
        shadow = s

        updateBackgroundColor()
    }

    override var mouseDownCanMoveWindow: Bool { true }

    override func updateLayer() {
        updateBackgroundColor()
    }

    private func updateBackgroundColor() {
        NSApp.effectiveAppearance.performAsCurrentDrawingAppearance {
            let isDark = NSAppearance.currentDrawing().isDarkMode
            layer?.backgroundColor = isDark
                ? NSColor.black.withAlphaComponent(0.25).cgColor
                : NSColor.white.cgColor
        }
    }

    @objc private func handleAppearanceChange() {
        updateBackgroundColor()
    }

    // MARK: Empty State Content

    private func setupEmptyStateContent() {
        let vc = EmptyStateViewController(instance: instance)
        emptyStateVC = vc

        let contentView = vc.view
        contentView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(contentView)

        let preferredWidth = contentView.widthAnchor.constraint(equalToConstant: 500)
        preferredWidth.priority = .defaultHigh

        let proportionalTop = NSLayoutConstraint(
            item: contentView, attribute: .top,
            relatedBy: .equal,
            toItem: self, attribute: .bottom,
            multiplier: 0.15, constant: 0
        )
        proportionalTop.priority = .defaultLow

        NSLayoutConstraint.activate([
            contentView.topAnchor.constraint(greaterThanOrEqualTo: topAnchor, constant: 10),
            proportionalTop,
            contentView.centerXAnchor.constraint(equalTo: centerXAnchor),
            preferredWidth,
            contentView.widthAnchor.constraint(lessThanOrEqualTo: widthAnchor, constant: -40),
            contentView.bottomAnchor.constraint(lessThanOrEqualTo: bottomAnchor, constant: -20),
        ])
    }

    func tearDown() {
        emptyStateVC?.tearDown()
        emptyStateVC?.view.removeFromSuperview()
        emptyStateVC = nil
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}
