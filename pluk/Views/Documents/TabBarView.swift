import AppKit
import SwiftUI

final class TabBarView: NSView {

    private let instance: ConnectionInstance
    private let appViewModel: AppViewModel

    private var prevButton: NSButton!
    private var nextButton: NSButton!
    private var scrollView: NSScrollView!
    private var tabsContainer: NSView!
    private var newTabButton: NSButton!
    private var sidebarToggleButton: NSButton!

    private var prevHoverLayer: CALayer!
    private var nextHoverLayer: CALayer!
    private var newTabHoverLayer: CALayer!
    private var sidebarHoverLayer: CALayer!

    private var tabViews: [UUID: DraggableTabNSView] = [:]
    private var draggedIndex: Int?
    private var dropInsertionIndex: Int?
    private var isScrollable = false
    private var isDragActive = false

    private var newTabInlineConstraint: NSLayoutConstraint!
    private var newTabFixedConstraint: NSLayoutConstraint!
    private var scrollViewTrailingConstraint: NSLayoutConstraint!

    private var leadingConstraint: NSLayoutConstraint!
    private var isSidebarVisible = true
    nonisolated(unsafe) private var sidebarObserver: NSObjectProtocol?

    nonisolated(unsafe) private var eventMonitor: Any?
    private var isLayoutingTabs = false

    private let tabWidth: CGFloat = 182
    private let tabHeight: CGFloat = 38
    private let tabSpacing: CGFloat = 4
    private let navButtonSize: CGFloat = 26
    private let newTabButtonWidth: CGFloat = 36
    private let newTabButtonGap: CGFloat = 6

    init(instance: ConnectionInstance, appViewModel: AppViewModel) {
        self.instance = instance
        self.appViewModel = appViewModel
        super.init(frame: .zero)
        wantsLayer = true
        setupLayout()
        startObserving()
        setupKeyboardShortcuts()
        syncTabs()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
        if let observer = sidebarObserver {
            NotificationCenter.default.removeObserver(observer)
        }
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
        }
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if window != nil {
            syncInitialSidebarState()
        }
    }

    // MARK: - Layout

    private func setupLayout() {
        prevButton = makeNavButton(symbolName: "chevron.left")
        prevButton.target = self
        prevButton.action = #selector(prevTabAction)
        prevButton.installCustomTooltip("Previous Tab", shortcut: .init(modifiers: [.shift, .command], key: "["))
        addSubview(prevButton)

        nextButton = makeNavButton(symbolName: "chevron.right")
        nextButton.target = self
        nextButton.action = #selector(nextTabAction)
        nextButton.installCustomTooltip("Next Tab", shortcut: .init(modifiers: [.shift, .command], key: "]"))
        addSubview(nextButton)

        scrollView = NonDraggingScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.contentView = NonDraggingClipView()
        scrollView.hasHorizontalScroller = false
        scrollView.hasVerticalScroller = false
        scrollView.drawsBackground = false
        scrollView.contentView.postsBoundsChangedNotifications = true

        tabsContainer = NonDraggingView()
        tabsContainer.wantsLayer = true
        tabsContainer.autoresizingMask = [.height]
        scrollView.documentView = tabsContainer

        scrollView.horizontalScrollElasticity = .none
        scrollView.verticalScrollElasticity = .none
        addSubview(scrollView)

        newTabButton = makeNavButton(symbolName: "plus", fontSize: 12)
        newTabButton.target = self
        newTabButton.action = #selector(newTabAction)
        newTabButton.installCustomTooltip("New Tab", shortcut: .init(modifiers: [.command], key: "T"))
        newTabButton.isHidden = true
        addSubview(newTabButton)

        sidebarToggleButton = makeNavButton(symbolName: "sidebar.right")
        sidebarToggleButton.target = self
        sidebarToggleButton.action = #selector(toggleSidebarAction)
        sidebarToggleButton.installCustomTooltip("Toggle Row Details", shortcut: .init(modifiers: [.command], key: "]"))
        addSubview(sidebarToggleButton)

        prevHoverLayer = makeHoverLayer()
        prevButton.layer?.addSublayer(prevHoverLayer)

        nextHoverLayer = makeHoverLayer()
        nextButton.layer?.addSublayer(nextHoverLayer)

        newTabHoverLayer = makeHoverLayer()
        newTabButton.layer?.addSublayer(newTabHoverLayer)

        sidebarHoverLayer = makeHoverLayer()
        sidebarToggleButton.layer?.addSublayer(sidebarHoverLayer)

        setupTrackingArea(for: prevButton, hoverLayer: prevHoverLayer)
        setupTrackingArea(for: nextButton, hoverLayer: nextHoverLayer)
        setupTrackingArea(for: newTabButton, hoverLayer: newTabHoverLayer)
        setupTrackingArea(for: sidebarToggleButton, hoverLayer: sidebarHoverLayer)

        setupConstraints()
    }

    private func setupConstraints() {
        prevButton.translatesAutoresizingMaskIntoConstraints = false
        nextButton.translatesAutoresizingMaskIntoConstraints = false
        newTabButton.translatesAutoresizingMaskIntoConstraints = false
        sidebarToggleButton.translatesAutoresizingMaskIntoConstraints = false

        leadingConstraint = prevButton.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8)
        scrollViewTrailingConstraint = scrollView.trailingAnchor.constraint(equalTo: sidebarToggleButton.leadingAnchor, constant: -4)

        newTabInlineConstraint = newTabButton.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor, constant: 0)
        newTabFixedConstraint = newTabButton.trailingAnchor.constraint(equalTo: sidebarToggleButton.leadingAnchor, constant: -4)

        NSLayoutConstraint.activate([
            leadingConstraint,
            prevButton.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -8),
            prevButton.widthAnchor.constraint(equalToConstant: navButtonSize),
            prevButton.heightAnchor.constraint(equalToConstant: navButtonSize),

            nextButton.leadingAnchor.constraint(equalTo: prevButton.trailingAnchor),
            nextButton.centerYAnchor.constraint(equalTo: prevButton.centerYAnchor),
            nextButton.widthAnchor.constraint(equalToConstant: navButtonSize),
            nextButton.heightAnchor.constraint(equalToConstant: navButtonSize),

            scrollView.leadingAnchor.constraint(equalTo: nextButton.trailingAnchor),
            scrollView.topAnchor.constraint(equalTo: topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: bottomAnchor),
            scrollViewTrailingConstraint,

            sidebarToggleButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),
            sidebarToggleButton.centerYAnchor.constraint(equalTo: prevButton.centerYAnchor),
            sidebarToggleButton.widthAnchor.constraint(equalToConstant: 34),
            sidebarToggleButton.heightAnchor.constraint(equalToConstant: navButtonSize),

            newTabButton.centerYAnchor.constraint(equalTo: prevButton.centerYAnchor),
            newTabButton.widthAnchor.constraint(equalToConstant: newTabButtonWidth),
            newTabButton.heightAnchor.constraint(equalToConstant: navButtonSize),
        ])

        newTabInlineConstraint.isActive = true
    }

    // MARK: - Factory Methods

    private func makeNavButton(symbolName: String, fontSize: CGFloat = 14) -> NSButton {
        let button = NSButton(frame: .zero)
        button.bezelStyle = .inline
        button.isBordered = false
        button.image = NSImage(systemSymbolName: symbolName, accessibilityDescription: nil)
        button.imagePosition = .imageOnly
        button.symbolConfiguration = .init(pointSize: fontSize, weight: .regular)
        button.wantsLayer = true
        button.layer?.cornerRadius = 6
        button.contentTintColor = .secondaryLabelColor
        return button
    }

    private func makeHoverLayer() -> CALayer {
        let layer = CALayer()
        layer.cornerRadius = 6
        layer.opacity = 0
        return layer
    }

    private func setupTrackingArea(for button: NSButton, hoverLayer: CALayer) {
        let tracker = HoverTracker(hoverLayer: hoverLayer, owner: button)
        button.addTrackingArea(NSTrackingArea(
            rect: .zero,
            options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
            owner: tracker,
            userInfo: nil
        ))
        objc_setAssociatedObject(button, &HoverTracker.associatedKey, tracker, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
    }

    // MARK: - Tab Syncing

    func syncTabs() {
        if isDragActive { return }
        draggedIndex = nil
        dropInsertionIndex = nil
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        newTabHoverLayer.opacity = 0
        CATransaction.commit()
        let currentTabs = instance.tabs
        let currentIds = Set(currentTabs.map(\.id))
        let existingIds = Set(tabViews.keys)

        for id in existingIds where !currentIds.contains(id) {
            if let view = tabViews.removeValue(forKey: id) {
                view.removeFromSuperview()
            }
        }

        for (index, tab) in currentTabs.enumerated() {
            if let existingView = tabViews[tab.id] {
                existingView.tabIndex = index
                if let tabButton = existingView.hostedView as? TabButtonView {
                    tabButton.update(
                        tab: tab,
                        isSelected: instance.selectedTab?.id == tab.id,
                        databaseType: instance.connection.databaseType
                    )
                }
            } else {
                let draggable = makeDraggableTab(for: tab, at: index)
                tabsContainer.addSubview(draggable)
                tabViews[tab.id] = draggable
            }
        }

        layoutTabs(animated: false)
        updateScrollability()
        updateNavigationButtons()
        updateSidebarToggleAppearance()
        scrollToSelectedTab(animated: true)
    }

    private func makeDraggableTab(for tab: DatabaseTab, at index: Int) -> DraggableTabNSView {
        let draggable = DraggableTabNSView()
        draggable.tabIndex = index
        draggable.snapshotTitle = tab.name
        draggable.snapshotIcon = getTabIconName(for: tab, databaseType: instance.connection.databaseType)
        draggable.onReorder = { [weak self] from, to in
            guard let self else { return }
            if from < self.instance.tabs.count {
                let movingTab = self.instance.tabs[from]
                self.tabViews[movingTab.id]?.alphaValue = 0
            }
            self.instance.moveTab(fromIndex: from, toIndex: to)
            self.isDragActive = false
            self.syncTabs()
        }
        draggable.onDragBegin = { [weak self] in
            guard let self else { return }
            self.isDragActive = true
            for (id, draggableView) in self.tabViews {
                guard let tabButton = draggableView.hostedView as? TabButtonView else { continue }
                tabButton.isDragActive = true
                if let current = self.instance.tabs.first(where: { $0.id == id }) {
                    tabButton.update(tab: current, isSelected: current.id == tab.id, databaseType: self.instance.connection.databaseType)
                }
            }
            instance.selectTab(tab)
        }
        draggable.onDragPulledOut = { [weak self] dragIndex, insertionIndex in
            guard let self else { return }
            self.draggedIndex = dragIndex
            self.dropInsertionIndex = insertionIndex
            self.layoutTabs(animated: true)
        }
        draggable.onInsertionIndexChanged = { [weak self] insertionIndex in
            self?.dropInsertionIndex = insertionIndex
            self?.layoutTabs(animated: true)
        }
        draggable.onDragEnded = { [weak self] willReorder in
            guard let self else { return }
            for draggableView in self.tabViews.values {
                (draggableView.hostedView as? TabButtonView)?.isDragActive = false
            }
            if !willReorder {
                self.draggedIndex = nil
                self.isDragActive = false
            }
            self.dropInsertionIndex = nil
            self.layoutTabs(animated: false)
        }
        draggable.onSelect = { [weak self] in
            self?.instance.selectTab(tab)
        }

        draggable.wantsLayer = true
        draggable.layer?.backgroundColor = .clear
        draggable.layer?.masksToBounds = false

        let tabButton = TabButtonView(
            tab: tab,
            isSelected: instance.selectedTab?.id == tab.id,
            databaseType: instance.connection.databaseType,
            onClose: { [weak self] in
                self?.instance.removeTab(tab)
                self?.syncTabs()
            }
        )
        tabButton.frame = NSRect(x: 0, y: 0, width: tabWidth, height: tabHeight)
        tabButton.autoresizingMask = []
        draggable.addSubview(tabButton)
        draggable.hostedView = tabButton

        draggable.registerForDraggedTypes([.string])
        return draggable
    }

    // MARK: - Tab Layout

    func layoutTabs(animated: Bool) {
        let tabs = instance.tabs
        guard !tabs.isEmpty else {
            tabsContainer.setFrameSize(NSSize(width: 0, height: scrollView.bounds.height))
            return
        }

        let containerHeight = scrollView.bounds.height
        var xOffset: CGFloat = 6 // Horizontal padding

        for (index, tab) in tabs.enumerated() {
            guard let draggable = tabViews[tab.id] else { continue }

            let isCollapsed = shouldCollapseTab(at: index)
            let isLastTab = index == tabs.count - 1
            let isDragged = draggedIndex == index

            // Insert gap before this tab if needed
            xOffset += gapBefore(tabIndex: index)

            if isCollapsed {
                draggable.alphaValue = 0
            } else {
                let trailingSpace: CGFloat = isLastTab ? 0 : tabSpacing
                let targetFrame = NSRect(x: xOffset, y: 0, width: tabWidth, height: tabHeight)
                let targetAlpha: CGFloat = isDragged ? 0 : 1

                if animated && !isDragged {
                    NSAnimationContext.runAnimationGroup { context in
                        context.duration = 0.25
                        context.timingFunction = CAMediaTimingFunction(name: .easeOut)
                        draggable.animator().frame = targetFrame
                        draggable.animator().alphaValue = targetAlpha
                    }
                } else {
                    draggable.frame = targetFrame
                    draggable.alphaValue = targetAlpha
                }

                xOffset += tabWidth + trailingSpace
            }

            // Insert gap after this tab if needed
            xOffset += gapAfter(tabIndex: index)
        }

        // Always keep inline constraint constant up to date
        newTabInlineConstraint?.constant = xOffset + newTabButtonGap
        if !isScrollable {
            xOffset += newTabButtonGap + newTabButtonWidth + newTabButtonGap
        }

        xOffset += 6 // Trailing padding

        let containerWidth = max(xOffset, scrollView.bounds.width)
        let newSize = NSSize(width: containerWidth, height: containerHeight)
        if tabsContainer.frame.size != newSize {
            tabsContainer.setFrameSize(newSize)
        }
    }

    private func gapWidth(forDraggedIndex dragged: Int) -> CGFloat {
        let isDraggedTabLast = dragged == instance.tabs.count - 1
        return isDraggedTabLast ? tabWidth : tabWidth + tabSpacing
    }

    private func isDraggingToOriginalPosition(insertion: Int, dragged: Int) -> Bool {
        insertion == dragged || insertion == dragged + 1
    }

    private func gapBefore(tabIndex: Int) -> CGFloat {
        guard !shouldCollapseTab(at: tabIndex),
              let insertion = dropInsertionIndex,
              let dragged = draggedIndex,
              !isDraggingToOriginalPosition(insertion: insertion, dragged: dragged),
              insertion == tabIndex else {
            return 0
        }
        return gapWidth(forDraggedIndex: dragged)
    }

    private func gapAfter(tabIndex: Int) -> CGFloat {
        guard !shouldCollapseTab(at: tabIndex),
              let insertion = dropInsertionIndex,
              let dragged = draggedIndex,
              !isDraggingToOriginalPosition(insertion: insertion, dragged: dragged),
              tabIndex == instance.tabs.count - 1,
              insertion == instance.tabs.count else {
            return 0
        }
        return gapWidth(forDraggedIndex: dragged)
    }

    private func shouldCollapseTab(at index: Int) -> Bool {
        guard let dragged = draggedIndex,
              let insertion = dropInsertionIndex,
              index == dragged else {
            return false
        }
        return !isDraggingToOriginalPosition(insertion: insertion, dragged: dragged)
    }

    // MARK: - Scrollability

    private func updateScrollability() {
        let viewWidth = scrollView.bounds.width
        guard viewWidth > 0 else { return }

        let contentWidth = tabsContainer.frame.width
        let wasScrollable = isScrollable
        isScrollable = contentWidth > viewWidth

        newTabButton.isHidden = false

        if isScrollable {
            guard !newTabFixedConstraint.isActive else { return }
            newTabInlineConstraint.isActive = false
            newTabFixedConstraint.isActive = true
            scrollViewTrailingConstraint.constant = -(newTabButtonWidth + newTabButtonGap)
        } else {
            guard !newTabInlineConstraint.isActive else { return }
            newTabFixedConstraint.isActive = false
            newTabInlineConstraint.isActive = true
        }

        if wasScrollable != isScrollable {
            layoutTabs(animated: false)
        }

        needsLayout = true
    }

    private func scrollToSelectedTab(animated: Bool) {
        guard let selectedTab = instance.selectedTab,
              let draggable = tabViews[selectedTab.id] else { return }

        let tabFrame = draggable.frame
        let visibleRect = scrollView.contentView.bounds

        if tabFrame.minX < visibleRect.minX || tabFrame.maxX > visibleRect.maxX {
            let targetX = tabFrame.midX - visibleRect.width / 2
            let clampedX = max(0, min(targetX, tabsContainer.frame.width - visibleRect.width))
            let targetPoint = NSPoint(x: clampedX, y: 0)

            if animated {
                NSAnimationContext.runAnimationGroup { context in
                    context.duration = 0.2
                    context.timingFunction = CAMediaTimingFunction(name: .easeOut)
                    scrollView.contentView.animator().setBoundsOrigin(targetPoint)
                }
            } else {
                scrollView.contentView.scroll(to: targetPoint)
            }
            scrollView.reflectScrolledClipView(scrollView.contentView)
        }
    }

    // MARK: - Navigation State

    private func updateNavigationButtons() {
        let tabs = instance.tabs
        prevButton.isEnabled = instance.selectedTab != tabs.first
        nextButton.isEnabled = instance.selectedTab != tabs.last
        prevButton.contentTintColor = prevButton.isEnabled ? .secondaryLabelColor : .tertiaryLabelColor
        nextButton.contentTintColor = nextButton.isEnabled ? .secondaryLabelColor : .tertiaryLabelColor
    }

    private func updateSidebarToggleAppearance() {
        let isActive = appViewModel.isRightSidebarVisible
        sidebarToggleButton.contentTintColor = isActive ? .labelColor : .secondaryLabelColor

        guard let tracker = objc_getAssociatedObject(sidebarToggleButton!, &HoverTracker.associatedKey) as? HoverTracker else { return }
        tracker.isActive = isActive

        if isActive {
            tracker.showHover()
        } else {
            tracker.hideHover()
        }
    }

    // MARK: - Actions

    @objc private func prevTabAction() {
        guard let currentTab = instance.selectedTab ?? instance.tabs.first else { return }
        instance.previousTab(currentTab)
    }

    @objc private func nextTabAction() {
        guard let currentTab = instance.selectedTab ?? instance.tabs.first else { return }
        instance.nextTab(currentTab)
    }

    @objc private func newTabAction() {
        instance.createSQLEditorTab()
    }

    @objc private func toggleSidebarAction() {
        NotificationCenter.default.post(name: .toggleRightSidebar, object: nil)
    }

    // MARK: - Observation

    private func startObserving() {
        observeTabs()
        observeDatabaseType()
        observeSidebarToggle()

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAppearanceChange),
            name: .appAppearanceDidChange,
            object: nil
        )

        sidebarObserver = NotificationCenter.default.addObserver(
            forName: .sidebarAnimationWillStart,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            let isCollapsing = notification.userInfo?["isCollapsing"] as? Bool ?? false
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.isSidebarVisible = !isCollapsing
                await NSAnimationContext.runAnimationGroup { context in
                    context.duration = 0.17
                    context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                    self.leadingConstraint.animator().constant = isCollapsing ? 120 : 8
                }
            }
        }
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
                self.syncTabs()
                self.observeTabs()
            }
        }
    }

    private func observeDatabaseType() {
        withObservationTracking {
            _ = self.instance.databaseType
        } onChange: { [weak self] in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.layoutTabs(animated: false)
                self.updateScrollability()
                self.observeDatabaseType()
            }
        }
    }

    private func observeSidebarToggle() {
        withObservationTracking {
            _ = self.appViewModel.isRightSidebarVisible
        } onChange: { [weak self] in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.updateSidebarToggleAppearance()
                self.observeSidebarToggle()
            }
        }
    }

    private func syncInitialSidebarState() {
        var current: NSView? = superview
        while let view = current {
            if let splitView = view as? HoverDividerSplitView {
                isSidebarVisible = !splitView.isSidebarCollapsed
                leadingConstraint.constant = isSidebarVisible ? 8 : 120
                return
            }
            current = view.superview
        }
    }

    // MARK: - Keyboard Shortcuts

    private func setupKeyboardShortcuts() {
        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self, self.window?.isKeyWindow == true else { return event }

            let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            let key = event.charactersIgnoringModifiers

            if flags == .command {
                switch key {
                case "w":
                    guard let selectedTab = instance.selectedTab else { return event }
                    instance.removeTab(selectedTab)
                    self.syncTabs()
                    return nil
                case "t":
                    instance.createSQLEditorTab()
                    return nil
                default:
                    if let char = key, let digit = Int(char), (1...9).contains(digit) {
                        instance.selectTabByIndex(digit - 1)
                        return nil
                    }
                }
            }

            if flags == [.command, .shift] {
                switch key {
                case "[":
                    self.prevTabAction()
                    return nil
                case "]":
                    self.nextTabAction()
                    return nil
                default:
                    break
                }
            }

            return event
        }
    }

    // MARK: - Appearance

    override var mouseDownCanMoveWindow: Bool { false }

    @objc private func handleAppearanceChange() {
        refreshAppearance()
    }

    private func refreshAppearance() {
        for draggable in tabViews.values {
            if let tabButton = draggable.hostedView as? TabButtonView {
                tabButton.updateAppearance()
            }
        }
        updateSidebarToggleAppearance()
    }

    override func layout() {
        super.layout()
        guard bounds.height > 0, !isLayoutingTabs else { return }
        isLayoutingTabs = true
        prevHoverLayer.frame = prevButton.bounds
        nextHoverLayer.frame = nextButton.bounds
        newTabHoverLayer.frame = newTabButton.bounds
        sidebarHoverLayer.frame = sidebarToggleButton.bounds
        layoutTabs(animated: false)
        updateScrollability()
        isLayoutingTabs = false
    }
}

// MARK: - Hover Tracker

private class HoverTracker: NSResponder {
    static var associatedKey: UInt8 = 0

    let hoverLayer: CALayer
    weak var owner: NSButton?
    var isActive = false

    init(hoverLayer: CALayer, owner: NSButton) {
        self.hoverLayer = hoverLayer
        self.owner = owner
        super.init()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    func showHover() {
        NSApp.effectiveAppearance.performAsCurrentDrawingAppearance {
            let isDark = NSAppearance.currentDrawing().isDarkMode
            hoverLayer.backgroundColor = isDark
                ? NSColor.white.withAlphaComponent(0.12).cgColor
                : NSColor.controlColor.withAlphaComponent(0.8).cgColor
            hoverLayer.opacity = 1
        }
    }

    func hideHover() {
        hoverLayer.opacity = 0
    }

    override func mouseEntered(with event: NSEvent) {
        guard !isActive else { return }
        showHover()
    }

    override func mouseExited(with event: NSEvent) {
        guard !isActive else { return }
        hideHover()
    }
}

// MARK: - TabButtonView

final class TabButtonView: NSView {

    private var tab: DatabaseTab
    private var isSelected: Bool
    private var databaseType: DatabaseType
    private var onClose: () -> Void

    private var tabShapeLayer: CAShapeLayer!
    private var hoverBackgroundLayer: CALayer!

    private var iconView: NSImageView!
    private var titleLabel: NSTextField!
    private var deviationLabel: NSTextField!
    private var closeButton: NSButton!

    private var isHovering = false
    private var trackingArea: NSTrackingArea?

    init(tab: DatabaseTab, isSelected: Bool, databaseType: DatabaseType, onClose: @escaping () -> Void) {
        self.tab = tab
        self.isSelected = isSelected
        self.databaseType = databaseType
        self.onClose = onClose
        super.init(frame: .zero)
        wantsLayer = true
        layer?.masksToBounds = false
        setupSubviews()
        updateVisuals()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    override var mouseDownCanMoveWindow: Bool { false }

    override func hitTest(_ point: NSPoint) -> NSView? {
        let local = convert(point, from: superview)
        if !closeButton.isHidden {
            let closeLocal = closeButton.convert(point, from: superview)
            if closeButton.bounds.contains(closeLocal) {
                return closeButton
            }
        }
        if bounds.contains(local) {
            return self
        }
        return nil
    }

    override func mouseDown(with event: NSEvent) {
        superview?.mouseDown(with: event)
    }

    override func mouseDragged(with event: NSEvent) {
        superview?.mouseDragged(with: event)
    }

    override func mouseUp(with event: NSEvent) {
        superview?.mouseUp(with: event)
    }

    func update(tab: DatabaseTab, isSelected: Bool, databaseType: DatabaseType) {
        let needsVisualUpdate = self.isSelected != isSelected
            || self.tab.name != tab.name
            || self.tab.hasSchemaDeviation != tab.hasSchemaDeviation

        self.tab = tab
        self.isSelected = isSelected
        self.databaseType = databaseType

        if needsVisualUpdate {
            updateVisuals()
        }
    }

    func updateAppearance() {
        updateVisuals()
    }

    // MARK: - Setup

    private func setupSubviews() {
        tabShapeLayer = CAShapeLayer()
        tabShapeLayer.masksToBounds = false
        layer?.addSublayer(tabShapeLayer)

        hoverBackgroundLayer = CALayer()
        hoverBackgroundLayer.cornerRadius = 8
        hoverBackgroundLayer.opacity = 0
        hoverBackgroundLayer.shadowColor = NSColor.black.cgColor
        hoverBackgroundLayer.shadowOpacity = 0.10
        hoverBackgroundLayer.shadowRadius = 1
        hoverBackgroundLayer.shadowOffset = .zero
        layer?.addSublayer(hoverBackgroundLayer)

        iconView = NSImageView()
        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconView.imageScaling = .scaleProportionallyDown
        iconView.contentTintColor = .secondaryLabelColor
        iconView.symbolConfiguration = .init(pointSize: 13, weight: .regular)
        addSubview(iconView)

        titleLabel = NSTextField(labelWithString: "")
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.lineBreakMode = .byTruncatingMiddle
        titleLabel.maximumNumberOfLines = 1
        titleLabel.font = .systemFont(ofSize: NSFont.systemFontSize)
        titleLabel.cell?.truncatesLastVisibleLine = true
        addSubview(titleLabel)

        deviationLabel = NSTextField(labelWithString: "*")
        deviationLabel.translatesAutoresizingMaskIntoConstraints = false
        deviationLabel.font = .systemFont(ofSize: 14, weight: .bold)
        deviationLabel.isHidden = true
        addSubview(deviationLabel)

        closeButton = NSButton(frame: .zero)
        closeButton.bezelStyle = .inline
        closeButton.isBordered = false
        closeButton.image = NSImage(systemSymbolName: "xmark", accessibilityDescription: "Close tab")
        closeButton.imagePosition = .imageOnly
        closeButton.symbolConfiguration = .init(pointSize: 12, weight: .semibold)
        closeButton.target = self
        closeButton.action = #selector(closeAction)
        closeButton.translatesAutoresizingMaskIntoConstraints = false
        closeButton.isHidden = true
        closeButton.wantsLayer = true
        closeButton.layer?.cornerRadius = 6
        addSubview(closeButton)

        NSLayoutConstraint.activate([
            iconView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
            iconView.centerYAnchor.constraint(equalTo: centerYAnchor, constant: -2),
            iconView.widthAnchor.constraint(equalToConstant: 20),
            iconView.heightAnchor.constraint(equalToConstant: 20),

            titleLabel.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: 8),
            titleLabel.centerYAnchor.constraint(equalTo: iconView.centerYAnchor),
            titleLabel.trailingAnchor.constraint(lessThanOrEqualTo: closeButton.leadingAnchor, constant: -4),

            deviationLabel.leadingAnchor.constraint(equalTo: titleLabel.trailingAnchor, constant: 1),
            deviationLabel.centerYAnchor.constraint(equalTo: titleLabel.centerYAnchor),

            closeButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -6),
            closeButton.centerYAnchor.constraint(equalTo: iconView.centerYAnchor),
            closeButton.widthAnchor.constraint(equalToConstant: 22),
            closeButton.heightAnchor.constraint(equalToConstant: 18),
        ])
    }

    // MARK: - Visuals

    private func updateVisuals() {
        let iconName = getTabIconName(for: tab, databaseType: databaseType)
        iconView.image = NSImage(systemSymbolName: iconName, accessibilityDescription: nil)
        titleLabel.stringValue = tab.name
        deviationLabel.isHidden = !tab.hasSchemaDeviation

        updateColors()
        needsLayout = true
    }

    private func updateColors() {
        NSApp.effectiveAppearance.performAsCurrentDrawingAppearance {
            let isDark = NSAppearance.currentDrawing().isDarkMode

            if isSelected {
                tabShapeLayer.fillColor = isDark
                    ? NSColor.black.withAlphaComponent(0.30).cgColor
                    : NSColor.controlBackgroundColor.withAlphaComponent(0.86).cgColor
                if isDark {
                    tabShapeLayer.shadowOpacity = 0
                } else {
                    tabShapeLayer.shadowColor = NSColor(white: 0, alpha: 1).cgColor
                    tabShapeLayer.shadowOpacity = 0.10
                    tabShapeLayer.shadowRadius = 1
                    tabShapeLayer.shadowOffset = .zero
                }
            } else {
                tabShapeLayer.fillColor = NSColor.clear.cgColor
                tabShapeLayer.shadowOpacity = 0
            }

            hoverBackgroundLayer.backgroundColor = isDark
                ? NSColor.white.withAlphaComponent(0.12).cgColor
                : NSColor.controlColor.withAlphaComponent(0.8).cgColor
            hoverBackgroundLayer.opacity = (isHovering && !isSelected) ? 1 : 0
        }
    }

    override func layout() {
        super.layout()

        let rect = bounds
        tabShapeLayer.frame = rect
        if isSelected {
            tabShapeLayer.path = makeTabShapePath(in: rect)

            let shadowPadding: CGFloat = 10
            let maskLayer = CAShapeLayer()
            maskLayer.path = CGPath(rect: CGRect(
                x: -shadowPadding,
                y: 0,
                width: rect.width + shadowPadding * 2,
                height: rect.height + shadowPadding
            ), transform: nil)
            layer?.mask = maskLayer
        } else {
            tabShapeLayer.path = nil
            layer?.mask = nil
        }

        hoverBackgroundLayer.frame = NSRect(
            x: 0,
            y: 4,
            width: rect.width,
            height: rect.height - 4
        )
    }

    private func makeTabShapePath(in rect: CGRect) -> CGPath {
        let path = CGMutablePath()
        let radius: CGFloat = 10
        let curveRadius: CGFloat = 10
        let smoothness: CGFloat = 1
        let h = rect.height

        path.move(to: CGPoint(x: -curveRadius, y: 0))
        path.addQuadCurve(to: CGPoint(x: 0, y: curveRadius), control: CGPoint(x: -2 * smoothness, y: 0))
        path.addLine(to: CGPoint(x: 0, y: h - radius))
        path.addQuadCurve(to: CGPoint(x: radius, y: h), control: CGPoint(x: 0, y: h))
        path.addLine(to: CGPoint(x: rect.width - radius, y: h))
        path.addQuadCurve(to: CGPoint(x: rect.width, y: h - radius), control: CGPoint(x: rect.width, y: h))
        path.addLine(to: CGPoint(x: rect.width, y: curveRadius))
        path.addQuadCurve(to: CGPoint(x: rect.width + curveRadius, y: 0), control: CGPoint(x: rect.width + 2 * smoothness, y: 0))
        path.addLine(to: CGPoint(x: -curveRadius, y: 0))

        return path
    }

    // MARK: - Hover Tracking

    private var isCloseButtonHovering = false

    var isDragActive = false {
        didSet {
            if isDragActive {
                isHovering = false
                isCloseButtonHovering = false
                closeButton.isHidden = true
                closeButton.layer?.backgroundColor = NSColor.clear.cgColor
                hoverBackgroundLayer.opacity = 0
            }
        }
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let existing = trackingArea {
            removeTrackingArea(existing)
        }
        trackingArea = NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .mouseMoved, .activeInActiveApp],
            owner: self,
            userInfo: nil
        )
        if let trackingArea {
            addTrackingArea(trackingArea)
        }

        if let window, isHovering {
            let mouseInWindow = window.mouseLocationOutsideOfEventStream
            let localPoint = convert(mouseInWindow, from: nil)
            if !bounds.contains(localPoint) {
                isHovering = false
                closeButton.isHidden = true
                closeButton.layer?.backgroundColor = NSColor.clear.cgColor
                hoverBackgroundLayer.opacity = 0
            }
        }
    }

    override func mouseEntered(with event: NSEvent) {
        super.mouseEntered(with: event)
        guard !isDragActive else { return }
        isHovering = true
        closeButton.isHidden = false

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.15
            if !isSelected {
                hoverBackgroundLayer.opacity = 1
            }
        }

        updateCloseButtonHover(with: event)
    }

    override func mouseMoved(with event: NSEvent) {
        super.mouseMoved(with: event)
        guard !isDragActive else { return }
        updateCloseButtonHover(with: event)
    }

    override func mouseExited(with event: NSEvent) {
        super.mouseExited(with: event)
        isHovering = false
        isCloseButtonHovering = false
        closeButton.isHidden = true
        closeButton.layer?.backgroundColor = NSColor.clear.cgColor

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.15
            hoverBackgroundLayer.opacity = 0
        }
    }

    private func updateCloseButtonHover(with event: NSEvent) {
        let locationInSelf = convert(event.locationInWindow, from: nil)
        let locationInClose = closeButton.convert(locationInSelf, from: self)
        let isOver = closeButton.bounds.contains(locationInClose) && !closeButton.isHidden

        guard isOver != isCloseButtonHovering else { return }
        isCloseButtonHovering = isOver

        NSApp.effectiveAppearance.performAsCurrentDrawingAppearance {
            let isDark = NSAppearance.currentDrawing().isDarkMode
            closeButton.layer?.backgroundColor = isOver
                ? (isDark ? NSColor.white.withAlphaComponent(0.3).cgColor : NSColor.secondarySystemFill.cgColor)
                : NSColor.clear.cgColor
        }
    }

    @objc private func closeAction() {
        onClose()
    }
}

// MARK: - Non-Dragging Scroll View

private class NonDraggingScrollView: NSScrollView {
    override var mouseDownCanMoveWindow: Bool { false }

    override func scrollWheel(with event: NSEvent) {
        guard let cgEvent = event.cgEvent?.copy() else { return }
        cgEvent.setDoubleValueField(.scrollWheelEventPointDeltaAxis1, value: 0)
        if event.hasPreciseScrollingDeltas {
            cgEvent.setDoubleValueField(.scrollWheelEventFixedPtDeltaAxis1, value: 0)
        }
        guard let cleaned = NSEvent(cgEvent: cgEvent) else { return }
        super.scrollWheel(with: cleaned)
    }
}

private class NonDraggingClipView: NSClipView {
    override var mouseDownCanMoveWindow: Bool { false }
}

private class NonDraggingView: NSView {
    override var mouseDownCanMoveWindow: Bool { false }
}
