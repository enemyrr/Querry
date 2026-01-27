//
//  TabBar.swift
//  Collection
//
//  Created by Fauzaan on 1/3/25.
//
import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct TabBar: View {
    @Environment(AppViewModel.self) private var appViewModel
    @Environment(ConnectionInstance.self) private var instance
    @Environment(\.leadingOverlayWidth) private var leadingOverlayWidth
    @State private var isScrollable = false
    @State private var isHoveringRightSidebar = false
    @State private var draggedIndex: Int?
    @State private var dropInsertionIndex: Int?

    var body: some View {
        HStack(spacing: 0) {
            HStack(alignment: .center, spacing: 0) {
                navigationButtons
                customTabButtons

                if instance.databaseType?.supportsQueryEditor == true && isScrollable {
                    newTabButton(leadingPadding: -2)
                }
            }
            .background(
                // Hidden keyboard shortcut for closing tabs
                Button(action: {
                    if let selectedTab = instance.selectedTab {
                        instance.removeTab(selectedTab)
                    }
                }) {
                    EmptyView()
                }
                .keyboardShortcut("w", modifiers: [.command])
                .opacity(0)
                .accessibilityHidden(true)
            )

            Spacer()

            rightSidebarToggle
                .padding(.leading, -4)
                .padding(.top, 2)
                .padding(.trailing, 8)
        }
        .padding(
            .leading,
            !appViewModel.isSidebarVisible ? max(leadingOverlayWidth, 120) : 0
        )
        .frame(height: 36)
        .background(
            // Add hidden buttons for Cmd+1 through Cmd+9
            ForEach(0..<9) { index in
                Button(action: {
                    instance.selectTabByIndex(index)
                }) {
                    EmptyView()
                }
                .keyboardShortcut(KeyEquivalent(Character("\(index + 1)")), modifiers: [.command])
                .opacity(0)
                .accessibilityHidden(true)
            }
        )
    }
    
    private var navigationButtons: some View {
        HStack(spacing: 0) {
            NavigationButton(
                icon: "chevron.left",
                action: {
                    instance.previousTab(
                        (instance.selectedTab ?? instance.tabs.first)!
                    )
                },
                isDisabled: instance.selectedTab == instance.tabs.first
            )
            .keyboardShortcut("[", modifiers: [.command, .shift])
            .customHelp(
                "Previous tab",
                shortcut: KeyboardShortcut(
                    modifiers: [.command, .shift],
                    key: "["
                )
            )
            
            NavigationButton(
                icon: "chevron.right",
                action: {
                    instance.nextTab(
                        (instance.selectedTab ?? instance.tabs.first)!
                    )
                },
                isDisabled: instance.selectedTab == instance.tabs.last
            )
            .keyboardShortcut("]", modifiers: [.command, .shift])
            .customHelp(
                "Next tab",
                shortcut: KeyboardShortcut(
                    modifiers: [.command, .shift],
                    key: "]"
                )
            )
        }
        .padding(.leading, 8)
        .padding(.bottom, 4)
    }

    private var customTabButtons: some View {
        GeometryReader { geometry in
            ScrollViewReader { proxy in
                tabScrollView(geometry: geometry, proxy: proxy)
            }
        }
    }

    private func tabScrollView(geometry: GeometryProxy, proxy: ScrollViewProxy) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            tabsHStack(geometry: geometry)
        }
        .onChange(of: instance.selectedTab) { _, newValue in
            if let tab = newValue {
                withAnimation(.easeInOut(duration: 0.2)) {
                    proxy.scrollTo(tab.id, anchor: .center)
                }
            }
        }
    }

    private func tabsHStack(geometry: GeometryProxy) -> some View {
        HStack(spacing: 0) {
            ForEach(Array(instance.tabs.enumerated()), id: \.element.id) { index, tab in
                draggableTab(index: index, tab: tab)
            }
            if instance.databaseType?.supportsQueryEditor == true && !isScrollable {
                newTabButton(leadingPadding: -2)
            }
        }
        .padding(.horizontal, 6)
        .background(
            GeometryReader { contentGeometry in
                Color.clear
                    .preference(key: TabsWidthPreferenceKey.self, value: contentGeometry.size.width)
                    .onAppear { isScrollable = contentGeometry.size.width > geometry.size.width }
                    .onChange(of: contentGeometry.size.width) { _, newWidth in
                        isScrollable = newWidth > geometry.size.width
                    }
            }
        )
    }

    private func draggableTab(index: Int, tab: DatabaseTab) -> some View {
        let isCollapsed = shouldCollapseTab(at: index)
        let isLastTab = index == instance.tabs.count - 1
        let trailingSpace: CGFloat = (isCollapsed || isLastTab) ? 0 : tabSpacing

        return DraggableTabWrapper(
            tabIndex: index,
            content: CustomTabButton(
                tab: tab,
                isSelected: instance.selectedTab?.id == tab.id,
                onSelect: { instance.selectTab(tab) },
                onClose: { instance.removeTab(tab) },
                databaseType: instance.connection.databaseType
            ),
            onReorder: instance.moveTab,
            snapshotTitle: tab.name,
            snapshotIcon: tabIcon(for: tab, databaseType: instance.connection.databaseType),
            onDragBegin: { instance.selectTab(tab) },
            onDragPulledOut: { draggedIndex = $0 },
            onInsertionIndexChanged: { dropInsertionIndex = $0 },
            onDragEnded: {
                var transaction = Transaction()
                transaction.disablesAnimations = true
                withTransaction(transaction) {
                    draggedIndex = nil
                    dropInsertionIndex = nil
                }
            }
        )
        .padding(.leading, gapBefore(tabIndex: index))
        .padding(.trailing, gapAfter(tabIndex: index) + trailingSpace)
        .animation(.spring(response: 0.25, dampingFraction: 0.8), value: dropInsertionIndex)
        .frame(width: isCollapsed ? 0 : nil)
        .opacity(draggedIndex == index ? 0 : 1)
        .animation(nil, value: draggedIndex)
        .id(tab.id)
    }

    private func newTabButton(leadingPadding: CGFloat) -> some View {
        Button(action: {
            instance.createSQLEditorTab()
        }) {
            Image(systemName: "plus")
                .font(.system(size: 12))
        }
        .keyboardShortcut("t", modifiers: [.command])
        .buttonStyle(NewTabButtonStyle())
        .padding(.bottom, 2)
        .customHelp(
            "New Tab",
            shortcut: KeyboardShortcut(
                modifiers: [.command],
                key: "t"
            )
        )
        .padding(.leading, leadingPadding)
    }

    private func tabIcon(for tab: DatabaseTab, databaseType: DatabaseType) -> String {
        if tab.type == .sqlEditor {
            return "terminal"
        }
        if databaseType == .mongodb && tab.viewMode == .content {
            return "text.document"
        }
        switch tab.viewMode {
        case .content:
            return "tablecells"
        case .schema:
            return "square.stack.3d.up"
        case .definition:
            return "ellipsis.curlybraces"
        }
    }

    private let tabWidth: CGFloat = 182
    private let tabSpacing: CGFloat = 4

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

    private var rightSidebarToggle: some View {
        Button(action: {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                appViewModel.isRightSidebarVisible.toggle()
            }
        }) {
            Image(systemName: "sidebar.right")
                .font(.system(size: 14))
                .foregroundStyle(appViewModel.isRightSidebarVisible ? .primary : .secondary)
                .padding(.vertical, 6)
                .padding(.horizontal, 8)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .modifier(GlassToggleBackground(isHovering: isHoveringRightSidebar, isActive: appViewModel.isRightSidebarVisible))
        .onHover { hovering in
            isHoveringRightSidebar = hovering
        }
        .customHelp(
            "Toggle Row Details",
            shortcut: KeyboardShortcut(
                modifiers: [.command],
                key: "]"
            )
        )
        .padding(.bottom, 4)
    }
}

/// A view modifier that applies glass effect on macOS 26+ when hovering or active, otherwise just shows the icon
struct GlassToggleBackground: ViewModifier {
    let isHovering: Bool
    let isActive: Bool

    func body(content: Content) -> some View {
        if #available(macOS 26.0, *) {
            if isHovering || isActive {
                content
                    .glassEffect(.regular, in: .rect(cornerRadius: 8))
            } else {
                content
            }
        } else {
            content
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill((isHovering || isActive) ? Color(.controlColor).opacity(0.8) : Color.clear)
                        .animation(.easeInOut(duration: 0.15), value: isActive)
                )
        }
    }
}

struct NSTabViewWrapper: NSViewRepresentable {
    @Environment(ConnectionInstance.self) private var instance
    
    func makeNSView(context: Context) -> NSTabView {
        let tabView = NSTabView()
        tabView.delegate = context.coordinator
        tabView.tabViewType = .noTabsNoBorder  // Hide default tabs, we'll use custom ones
        tabView.drawsBackground = false
        
        return tabView
    }
    
    func updateNSView(_ nsView: NSTabView, context: Context) {
        context.coordinator.updateTabs(nsView)
    }
    
    func makeCoordinator() -> Coordinator {
        return Coordinator(instance: instance)
    }
    
    class Coordinator: NSObject, NSTabViewDelegate {
        let instance: ConnectionInstance
        private var isUpdating = false
        
        init(instance: ConnectionInstance) {
            self.instance = instance
        }
        
        func updateTabs(_ tabView: NSTabView) {
            guard !isUpdating else { return }
            isUpdating = true
            defer { isUpdating = false }
            
            // Remove tabs that no longer exist
            let currentTabIdentifiers = Set(
                tabView.tabViewItems.compactMap { $0.identifier as? String }
            )
            let expectedTabIdentifiers = Set(
                instance.tabs.map { $0.id.uuidString }
            )
            
            for identifier in currentTabIdentifiers {
                if !expectedTabIdentifiers.contains(identifier) {
                    if let item = tabView.tabViewItems.first(where: {
                        ($0.identifier as? String) == identifier
                    }) {
                        tabView.removeTabViewItem(item)
                    }
                }
            }
            
            // Add or update tabs
            for (index, tab) in instance.tabs.enumerated() {
                let identifier = tab.id.uuidString
                
                if let existingItem = tabView.tabViewItems.first(where: {
                    ($0.identifier as? String) == identifier
                }) {
                    // Update existing tab
                    let tabLabel = tab.hasSchemaDeviation ? "\(tab.name)*" : tab.name
                    existingItem.label = tabLabel
                    existingItem.image = NSImage(
                        systemSymbolName: getIconName(for: tab, databaseType: instance.connection.databaseType),
                        accessibilityDescription: nil
                    )
                } else {
                    // Create new tab
                    let tabViewItem = NSTabViewItem(identifier: identifier)
                    let tabLabel = tab.hasSchemaDeviation ? "\(tab.name)*" : tab.name
                    tabViewItem.label = tabLabel
                    tabViewItem.image = NSImage(
                        systemSymbolName: getIconName(for: tab, databaseType: instance.connection.databaseType),
                        accessibilityDescription: nil
                    )
                    
                    // Create the actual content view for the tab
                    let tabContentView = TabContentView(
                        tab: tab,
                        databaseType: instance.connection.databaseType
                    )
                    tabViewItem.view = tabContentView
                    
                    // Insert at correct position
                    if index < tabView.numberOfTabViewItems {
                        tabView.insertTabViewItem(tabViewItem, at: index)
                    } else {
                        tabView.addTabViewItem(tabViewItem)
                    }
                }
            }
            
            // Select the correct tab
            if let selectedTab = instance.selectedTab,
               let item = tabView.tabViewItems.first(where: {
                   ($0.identifier as? String) == selectedTab.id.uuidString
               })
            {
                tabView.selectTabViewItem(item)
            }
        }
        
        // MARK: - NSTabViewDelegate
        
        func tabView(
            _ tabView: NSTabView,
            didSelect tabViewItem: NSTabViewItem?
        ) {
            guard !isUpdating,
                  let identifier = tabViewItem?.identifier as? String,
                  let tab = instance.tabs.first(where: {
                      $0.id.uuidString == identifier
                  })
            else {
                return
            }
            
            instance.selectTab(tab)
        }
        
        func tabView(
            _ tabView: NSTabView,
            shouldSelect tabViewItem: NSTabViewItem?
        ) -> Bool {
            return true
        }
        
        // Handle tab closing via context menu or gesture
        func tabView(
            _ tabView: NSTabView,
            willSelect tabViewItem: NSTabViewItem?
        ) {
            // Remove any context menu from tab content view to prevent it from appearing on right-click
            if let item = tabViewItem {
                item.view?.menu = nil
            }
        }

        // Helper function to get icon name based on tab type and view mode
        private func getIconName(for tab: DatabaseTab, databaseType: DatabaseType) -> String {
            if tab.type == .sqlEditor {
                return "terminal"
            }

            // For MongoDB, use document icon for content mode
            if databaseType == .mongodb && tab.viewMode == .content {
                return "text.document"
            }

            // For other tabs, use icon based on view mode
            switch tab.viewMode {
            case .content:
                return "tablecells"
            case .schema:
                return "square.stack.3d.up"
            case .definition:
                return "ellipsis.curlybraces"
            }
        }
    }
}

// Custom tab button with your styling
struct CustomTabButton: View {
    @Environment(\.colorScheme) var colorScheme
    let tab: DatabaseTab
    let isSelected: Bool
    let onSelect: () -> Void
    let onClose: () -> Void
    let databaseType: DatabaseType
    @State private var isHovering = false

    private var iconName: String {
        if tab.type == .sqlEditor {
            return "terminal"
        }

        // For MongoDB, use document icon for content mode
        if databaseType == .mongodb && tab.viewMode == .content {
            return "text.document"
        }

        // For other tabs, use icon based on view mode
        switch tab.viewMode {
        case .content:
            return "tablecells"
        case .schema:
            return "square.stack.3d.up"
        case .definition:
            return "ellipsis.curlybraces"
        }
    }

    var body: some View {
        VStack {
            ZStack {
                HStack(spacing: 8) {
                    Image(systemName: iconName)
                        .foregroundStyle(.secondary)
                        .font(.system(size: 12))
                        .frame(width: 14, alignment: .center)

                    Text(tab.name)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    
                    if tab.hasSchemaDeviation {
                        Text("*")
                            .font(.system(size: 14, weight: .bold))
                            .padding(.leading, -7)
                    }
                    
                    Spacer()
                }
                
                if isHovering {
                    HStack {
                        Spacer()
                        Button(action: onClose) {
                            Image(systemName: "xmark")
                                .font(.system(size: 12))
                        }
                        .buttonStyle(TabCloseButtonStyle())
                        .frame(width: 10, height: 10)
                    }
                }
            }
            .padding(.bottom, 4)
        }
        .frame(width: 160)
        .padding(.vertical, 8)
        .padding(.leading, 10)
        .padding(.trailing, 12)
        .background(
            Group {
                if colorScheme == .dark {
                    TabShape(isSelected: isSelected)
                        .fill(
                            Color(.black).opacity(0.40)
                        )
                        .shadow(
                            color: Color(.sRGBLinear, white: 0, opacity: 0.02),
                            radius: 4
                        )
                } else {
                    TabShape(isSelected: isSelected)
                        .fill(
                            isSelected
                            ? Color(.controlBackgroundColor).opacity(0.86)
                            : .clear
                        )
                        .shadow(
                            color: Color(.sRGBLinear, white: 0, opacity: 0.02),
                            radius: 4
                        )
                }
            }
        )
        .contentShape(Rectangle())
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(
                    isHovering ? Color(.controlColor).opacity(0.8) : Color.clear
                )
                .padding(.bottom, 4)
                .opacity(isSelected ? 0 : 1)
        ).onHover { hovering in
            withAnimation(.easeInOut(duration: 0.2)) {
                isHovering = hovering
            }
        }
        .onTapGesture {
            onSelect()
        }
    }
}

// Custom tab shape for styling
struct TabShape: Shape {
    let isSelected: Bool
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        
        if isSelected {
            let radius: CGFloat = 10
            let curveRadius: CGFloat = 10
            let smoothness: CGFloat = 1
            
            // Start from bottom left (extended)
            path.move(to: CGPoint(x: -curveRadius, y: rect.height))
            
            // Bottom left outward curve
            path.addQuadCurve(
                to: CGPoint(x: 0, y: rect.height - curveRadius),
                control: CGPoint(x: -2 * smoothness, y: rect.height)
            )
            
            // Left side line up
            path.addLine(to: CGPoint(x: 0, y: radius))
            
            // Top left rounded corner
            path.addQuadCurve(
                to: CGPoint(x: radius, y: 0),
                control: CGPoint(x: 0, y: 0)
            )
            
            // Top line
            path.addLine(to: CGPoint(x: rect.width - radius, y: 0))
            
            // Top right rounded corner
            path.addQuadCurve(
                to: CGPoint(x: rect.width, y: radius),
                control: CGPoint(x: rect.width, y: 0)
            )
            
            // Right side line down
            path.addLine(
                to: CGPoint(x: rect.width, y: rect.height - curveRadius)
            )
            
            // Bottom right outward curve
            path.addQuadCurve(
                to: CGPoint(x: rect.width + curveRadius, y: rect.height),
                control: CGPoint(x: rect.width + 2 * smoothness, y: rect.height)
            )
            
            // Bottom line to close
            path.addLine(to: CGPoint(x: -curveRadius, y: rect.height))
        }
        
        return path
    }
}

// Custom border shape that excludes bottom border for selected tabs
struct TabBorderShape: Shape {
    let isSelected: Bool
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        
        if isSelected {
            let radius: CGFloat = 10
            let curveRadius: CGFloat = 10
            let smoothness: CGFloat = 1
            
            // Start from bottom left outward curve
            path.move(to: CGPoint(x: -curveRadius, y: rect.height))
            
            // Bottom left outward curve
            path.addQuadCurve(
                to: CGPoint(x: 0, y: rect.height - curveRadius),
                control: CGPoint(x: -2 * smoothness, y: rect.height)
            )
            
            // Left side line up
            path.addLine(to: CGPoint(x: 0, y: radius))
            
            // Top left rounded corner
            path.addQuadCurve(
                to: CGPoint(x: radius, y: 0),
                control: CGPoint(x: 0, y: 0)
            )
            
            // Top line
            path.addLine(to: CGPoint(x: rect.width - radius, y: 0))
            
            // Top right rounded corner
            path.addQuadCurve(
                to: CGPoint(x: rect.width, y: radius),
                control: CGPoint(x: rect.width, y: 0)
            )
            
            // Right side line down
            path.addLine(
                to: CGPoint(x: rect.width, y: rect.height - curveRadius)
            )
            
            // Bottom right outward curve
            path.addQuadCurve(
                to: CGPoint(x: rect.width + curveRadius, y: rect.height),
                control: CGPoint(x: rect.width + 2 * smoothness, y: rect.height)
            )
        }
        
        return path
    }
}

struct NavigationButton: View {
    let icon: String
    let action: () -> Void
    let isDisabled: Bool
    @State private var isHovering = false
    
    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .padding(.vertical, 6)
                .padding(.horizontal, 8)
                .contentShape(Rectangle())
        }
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(
                    isHovering
                    ? Color(.controlColor).opacity(0.8)
                    : Color.clear
                )
        )
        .disabled(isDisabled)
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovering = hovering
        }
    }
}

struct TabsWidthPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

// MARK: - Draggable Tab Wrapper

struct DraggableTabWrapper<Content: View>: NSViewRepresentable {
    let tabIndex: Int
    let content: Content
    let onReorder: (Int, Int) -> Void
    var snapshotTitle: String = ""
    var snapshotIcon: String = "doc"
    var onDragBegin: (() -> Void)?
    var onDragPulledOut: ((Int) -> Void)?
    var onInsertionIndexChanged: ((Int?) -> Void)?
    var onDragEnded: (() -> Void)?

    func makeNSView(context: Context) -> DraggableTabNSView {
        let view = DraggableTabNSView()
        view.tabIndex = tabIndex
        view.onReorder = onReorder
        view.snapshotTitle = snapshotTitle
        view.snapshotIcon = snapshotIcon
        view.onDragBegin = onDragBegin
        view.onDragPulledOut = onDragPulledOut
        view.onInsertionIndexChanged = onInsertionIndexChanged
        view.onDragEnded = onDragEnded
        view.wantsLayer = true
        view.layer?.backgroundColor = .clear
        view.layer?.masksToBounds = false

        let hostingView = NonDraggingHostingView(rootView: content)
        hostingView.translatesAutoresizingMaskIntoConstraints = false
        hostingView.wantsLayer = true
        hostingView.layer?.backgroundColor = .clear
        hostingView.layer?.masksToBounds = false
        view.addSubview(hostingView)
        view.hostedView = hostingView
        NSLayoutConstraint.activate([
            hostingView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            hostingView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            hostingView.topAnchor.constraint(equalTo: view.topAnchor),
            hostingView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])

        view.registerForDraggedTypes([.string])
        return view
    }

    func updateNSView(_ nsView: DraggableTabNSView, context: Context) {
        nsView.tabIndex = tabIndex
        nsView.onReorder = onReorder
        nsView.snapshotTitle = snapshotTitle
        nsView.snapshotIcon = snapshotIcon
        nsView.onDragBegin = onDragBegin
        nsView.onDragPulledOut = onDragPulledOut
        nsView.onInsertionIndexChanged = onInsertionIndexChanged
        nsView.onDragEnded = onDragEnded
        if let hostingView = nsView.hostedView as? NonDraggingHostingView<Content> {
            hostingView.rootView = content
        }
    }
}

class NonDraggingHostingView<Content: View>: NSHostingView<Content> {
    override var mouseDownCanMoveWindow: Bool { false }

    override func mouseDown(with event: NSEvent) {
        // Let SwiftUI handle clicks first
        super.mouseDown(with: event)
        // Also notify superview for potential drag tracking
        superview?.mouseDown(with: event)
    }

    override func mouseDragged(with event: NSEvent) {
        superview?.mouseDragged(with: event)
    }

    override func mouseUp(with event: NSEvent) {
        super.mouseUp(with: event)
        superview?.mouseUp(with: event)
    }
}

extension Notification.Name {
    static let tabFramesNeedUpdate = Notification.Name("tabFramesNeedUpdate")
}

class DraggableTabNSView: NSView, NSDraggingSource {
    var tabIndex: Int = 0
    var onReorder: ((Int, Int) -> Void)?
    var hostedView: NSView?
    var snapshotTitle: String = ""
    var snapshotIcon: String = "doc"
    var onDragBegin: (() -> Void)?
    var onDragPulledOut: ((Int) -> Void)?
    var onInsertionIndexChanged: ((Int?) -> Void)?
    var onDragEnded: (() -> Void)?
    private let dragThreshold: CGFloat = 3
    private var mouseDownLocation: NSPoint?
    private var trackingArea: NSTrackingArea?
    private var frameUpdateObserver: NSObjectProtocol?

    // Track if this view is currently being dragged (for direct layer opacity control)
    private var isDragging = false
    // Track if the tab has been "pulled out" (moved far enough from original position)
    private var hasBeenPulledOut = false
    // Initial screen position when drag started (for detecting pull-out)
    private var initialDragScreenPosition: NSPoint = .zero
    // How far horizontally to drag before "pulling out" the tab
    private let pullOutThreshold: CGFloat = 12
    // Horizontal offset from cursor to left edge of drag preview (preserves click position)
    private var dragOffsetX: CGFloat = 0

    private static var dragWindow: NSPanel?
    private static var dragWindowYPosition: CGFloat = 0
    private static var currentInsertionIndex: Int?
    private static var currentDraggedIndex: Int?
    // Store tab frames in screen coordinates for position-based drop calculation
    private static var tabFrames: [Int: NSRect] = [:]
    // Scroll view bounds for clamping drag preview position
    private static var scrollViewMinX: CGFloat = 0
    private static var scrollViewMaxX: CGFloat = CGFloat.greatestFiniteMagnitude
    // Auto-scroll support
    private static var scrollView: NSScrollView?
    private static var autoScrollTimer: Timer?
    private static var autoScrollDirection: CGFloat = 0 // -1 for left, 1 for right, 0 for none
    private static let autoScrollEdgeZone: CGFloat = 40 // pixels from edge to trigger auto-scroll
    private static let autoScrollSpeed: CGFloat = 8 // pixels per timer tick

    override var mouseDownCanMoveWindow: Bool { false }

    // MARK: - Tracking Area (disable window movement when mouse is over tab)

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let existing = trackingArea {
            removeTrackingArea(existing)
        }
        trackingArea = NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .activeAlways],
            owner: self,
            userInfo: nil
        )
        if let trackingArea {
            addTrackingArea(trackingArea)
        }
    }

    override func mouseEntered(with event: NSEvent) {
        super.mouseEntered(with: event)
        window?.isMovable = false
    }

    override func mouseExited(with event: NSEvent) {
        super.mouseExited(with: event)
        window?.isMovable = true
    }

    override func layout() {
        super.layout()
        updateStoredFrame()
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        updateStoredFrame()

        // Set up observer for frame updates during auto-scroll
        if window != nil && frameUpdateObserver == nil {
            frameUpdateObserver = NotificationCenter.default.addObserver(
                forName: .tabFramesNeedUpdate,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                self?.updateStoredFrame()
            }
        } else if window == nil, let observer = frameUpdateObserver {
            NotificationCenter.default.removeObserver(observer)
            frameUpdateObserver = nil
        }
    }

    deinit {
        if let observer = frameUpdateObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    private func updateStoredFrame() {
        guard let window = window else { return }
        let frameInWindow = convert(bounds, to: nil)
        let screenFrame = window.convertToScreen(frameInWindow)
        Self.tabFrames[tabIndex] = screenFrame
    }

    private func findEnclosingScrollView() -> NSScrollView? {
        var current: NSView? = self
        while let view = current {
            if let scrollView = view as? NSScrollView {
                return scrollView
            }
            current = view.superview
        }
        return nil
    }

    private static func startAutoScroll(direction: CGFloat) {
        guard direction != 0, autoScrollDirection != direction else {
            return
        }
        // Stop existing timer first (without resetting direction)
        autoScrollTimer?.invalidate()
        autoScrollTimer = nil
        autoScrollDirection = direction

        // Create timer and add to common modes so it fires during event tracking
        let timer = Timer(timeInterval: 0.016, repeats: true) { _ in
            guard let scrollView = scrollView else {
                return
            }
            let clipView = scrollView.contentView
            var newOrigin = clipView.bounds.origin
            let oldX = newOrigin.x
            newOrigin.x += autoScrollSpeed * autoScrollDirection

            // Clamp to valid scroll range
            guard let documentView = scrollView.documentView else { return }
            let maxScrollX = max(0, documentView.frame.width - clipView.bounds.width)
            newOrigin.x = max(0, min(newOrigin.x, maxScrollX))

            // Skip if no change needed
            guard abs(newOrigin.x - oldX) > 0.01 else { return }

            // Use scroll(to:) for proper SwiftUI integration
            clipView.scroll(to: newOrigin)
            scrollView.reflectScrolledClipView(clipView)

            // Force layout update on document view to update tab positions
            documentView.needsLayout = true
            documentView.layoutSubtreeIfNeeded()

            // Update stored scroll view bounds after scrolling
            if let window = scrollView.window {
                let visibleRect = clipView.bounds
                let frameInWindow = clipView.convert(visibleRect, to: nil)
                let screenFrame = window.convertToScreen(frameInWindow)
                scrollViewMinX = screenFrame.minX
                scrollViewMaxX = screenFrame.maxX
            }

            // Post notification to update all tab frames
            NotificationCenter.default.post(name: .tabFramesNeedUpdate, object: nil)
        }
        // Add to common modes so timer fires during event tracking (mouse drag)
        RunLoop.main.add(timer, forMode: .common)
        autoScrollTimer = timer
    }

    private static func stopAutoScroll() {
        autoScrollTimer?.invalidate()
        autoScrollTimer = nil
        autoScrollDirection = 0
    }

    private static func updateAutoScroll(forScreenX screenX: CGFloat) {
        let leftEdge = scrollViewMinX + autoScrollEdgeZone
        let rightEdge = scrollViewMaxX - autoScrollEdgeZone

        if screenX < leftEdge {
            startAutoScroll(direction: -1)
        } else if screenX > rightEdge {
            startAutoScroll(direction: 1)
        } else {
            stopAutoScroll()
        }
    }

    /// Calculate insertion index based on screen X position
    private static func calculateInsertionIndex(forScreenX screenX: CGFloat) -> Int? {
        guard !tabFrames.isEmpty else { return nil }

        // Sort frames by X position
        let sortedFrames = tabFrames.sorted { $0.value.minX < $1.value.minX }

        for (tabIndex, frame) in sortedFrames {
            let midX = frame.midX

            // If cursor is to the left of this tab's center, insert before it
            if screenX < midX {
                return tabIndex
            }
        }

        // Cursor is past all tabs, insert at end
        if let lastTab = sortedFrames.last {
            return lastTab.key + 1
        }

        return nil
    }

    // MARK: - Drag Source

    func draggingSession(_ session: NSDraggingSession,
                         sourceOperationMaskFor context: NSDraggingContext) -> NSDragOperation {
        return .move
    }

    func draggingSession(_ session: NSDraggingSession,
                         movedTo screenPoint: NSPoint) {
        let panelWidth: CGFloat = 180

        // Clamp X to keep panel within scroll view bounds (using offset to preserve click position)
        let desiredX = screenPoint.x - dragOffsetX
        let clampedX = max(Self.scrollViewMinX, min(desiredX, Self.scrollViewMaxX - panelWidth))

        Self.dragWindow?.setFrameOrigin(NSPoint(
            x: clampedX,
            y: Self.dragWindowYPosition
        ))

        // Update auto-scroll based on cursor position near edges
        Self.updateAutoScroll(forScreenX: screenPoint.x)

        // Calculate insertion index from screen position for gap animation
        // This works even when cursor is in gaps between tabs
        if let insertionIndex = Self.calculateInsertionIndex(forScreenX: screenPoint.x) {
            if Self.currentInsertionIndex != insertionIndex {
                Self.currentInsertionIndex = insertionIndex
                onInsertionIndexChanged?(insertionIndex)
            }
        }
    }

    // Note: draggingSession delegate methods are not used since we use custom mouse tracking
    // for instant drop response. Keeping the protocol conformance for potential future use.

    private func performHapticFeedback(_ pattern: NSHapticFeedbackManager.FeedbackPattern) {
        NSHapticFeedbackManager.defaultPerformer.perform(pattern, performanceTime: .now)
    }

    override func mouseDown(with event: NSEvent) {
        mouseDownLocation = event.locationInWindow
    }

    override func mouseDragged(with event: NSEvent) {
        guard let startLocation = mouseDownLocation else { return }

        let currentLocation = event.locationInWindow
        let distance = hypot(currentLocation.x - startLocation.x,
                            currentLocation.y - startLocation.y)

        if distance > dragThreshold && !isDragging {
            // Start custom mouse-based drag (no system drag session for instant response)
            isDragging = true
            hasBeenPulledOut = false

            // Notify immediately that drag began (e.g., to select the tab)
            onDragBegin?()

            // Store initial screen position for pull-out detection and calculate drag offset
            if let window = self.window {
                initialDragScreenPosition = window.convertPoint(toScreen: currentLocation)
                let frameInWindow = convert(bounds, to: nil)
                let tabScreenFrame = window.convertToScreen(frameInWindow)
                Self.dragWindowYPosition = tabScreenFrame.origin.y
                // Calculate offset from cursor to left edge of tab (preserves click position in preview)
                dragOffsetX = initialDragScreenPosition.x - tabScreenFrame.minX
            }

            // Don't hide yet - wait until pulled out
            Self.currentDraggedIndex = tabIndex
            Self.currentInsertionIndex = nil

            // Find scroll view for auto-scroll and bounds clamping
            if let scrollView = findEnclosingScrollView(), let window = scrollView.window {
                Self.scrollView = scrollView
                let clipView = scrollView.contentView
                let visibleRect = clipView.bounds
                let frameInWindow = clipView.convert(visibleRect, to: nil)
                let screenFrame = window.convertToScreen(frameInWindow)
                Self.scrollViewMinX = screenFrame.minX
                Self.scrollViewMaxX = screenFrame.maxX
            }

            // Start mouse tracking loop (drag window created when pulled out)
            trackMouseForDrag(initialEvent: event)
        }
    }

    private func trackMouseForDrag(initialEvent: NSEvent) {
        guard let window = self.window else { return }

        // Track mouse until released
        window.trackEvents(matching: [.leftMouseDragged, .leftMouseUp], timeout: .infinity, mode: .eventTracking) { event, stop in
            guard let event = event else { return }

            let screenPoint = window.convertPoint(toScreen: event.locationInWindow)

            if event.type == .leftMouseUp {
                // Mouse released - end drag immediately
                Self.stopAutoScroll()
                Self.scrollView = nil

                // Hide and close drag window
                Self.dragWindow?.orderOut(nil)
                Self.dragWindow?.close()
                Self.dragWindow = nil

                // Only process reorder if tab was pulled out
                if self.hasBeenPulledOut {
                    // Calculate insertion index
                    let insertionIndex = Self.calculateInsertionIndex(forScreenX: screenPoint.x)
                    let draggedIndex = Self.currentDraggedIndex

                    // Clear SwiftUI state FIRST to avoid stale indices during re-render
                    self.onDragEnded?()

                    // Then perform reorder
                    if let draggedIndex = draggedIndex,
                       let insertionIndex = insertionIndex,
                       draggedIndex != insertionIndex,
                       draggedIndex + 1 != insertionIndex {
                        self.performHapticFeedback(.alignment)
                        self.onReorder?(draggedIndex, insertionIndex)
                    }
                }

                // Clear static state
                Self.currentDraggedIndex = nil
                Self.currentInsertionIndex = nil

                self.isDragging = false
                self.hasBeenPulledOut = false
                self.mouseDownLocation = nil

                stop.pointee = true
            } else {
                // Mouse dragged - check if we should "pull out" the tab
                if !self.hasBeenPulledOut {
                    // Check if mouse has moved far enough horizontally from initial position
                    let horizontalDistance = abs(screenPoint.x - self.initialDragScreenPosition.x)
                    if horizontalDistance > self.pullOutThreshold {
                        // Pull out the tab!
                        self.hasBeenPulledOut = true
                        self.performHapticFeedback(.levelChange)

                        // Calculate insertion index FIRST so SwiftUI knows where we are
                        if let insertionIndex = Self.calculateInsertionIndex(forScreenX: screenPoint.x) {
                            Self.currentInsertionIndex = insertionIndex
                            self.onInsertionIndexChanged?(insertionIndex)
                        }

                        // Notify SwiftUI that drag started (sets draggedIndex)
                        // SwiftUI will handle collapse/show based on insertion position
                        self.onDragPulledOut?(self.tabIndex)

                        // Create and show drag preview window
                        let panel = self.createDragWindow()
                        panel.setFrameOrigin(NSPoint(x: screenPoint.x - self.dragOffsetX, y: Self.dragWindowYPosition))
                        panel.orderFront(nil)
                        Self.dragWindow = panel
                    }
                }

                // Only update drag UI if pulled out
                if self.hasBeenPulledOut {
                    // Update drag window position (using offset to preserve click position)
                    let panelWidth: CGFloat = 180
                    let desiredX = screenPoint.x - self.dragOffsetX
                    let clampedX = max(Self.scrollViewMinX, min(desiredX, Self.scrollViewMaxX - panelWidth))
                    Self.dragWindow?.setFrameOrigin(NSPoint(x: clampedX, y: Self.dragWindowYPosition))

                    // Update auto-scroll
                    Self.updateAutoScroll(forScreenX: screenPoint.x)

                    // Update insertion index
                    if let insertionIndex = Self.calculateInsertionIndex(forScreenX: screenPoint.x) {
                        if Self.currentInsertionIndex != insertionIndex {
                            Self.currentInsertionIndex = insertionIndex
                            self.performHapticFeedback(.alignment)
                            self.onInsertionIndexChanged?(insertionIndex)
                        }
                    }
                }
            }
        }
    }

    private func createDragWindow() -> NSPanel {
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 180, height: 36),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.level = .floating
        panel.hasShadow = true

        let hostingView = NSHostingView(rootView: TabDragPreview(title: snapshotTitle, icon: snapshotIcon))
        panel.contentView = hostingView
        return panel
    }

    // MARK: - Drop Destination (not used - we use custom mouse tracking)

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        return .move
    }

    override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation {
        return .move
    }

    override func draggingExited(_ sender: NSDraggingInfo?) {
    }

    override func prepareForDragOperation(_ sender: NSDraggingInfo) -> Bool {
        return true
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        return true
    }

}

// MARK: - Tab Drag Preview

struct TabDragPreview: View {
    @Environment(\.colorScheme) var colorScheme
    let title: String
    let icon: String

    var body: some View {
        VStack {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .foregroundStyle(.secondary)
                    .font(.system(size: 12))
                    .frame(width: 14, alignment: .center)

                Text(title)
                    .lineLimit(1)
                    .truncationMode(.middle)

                Spacer()
            }
            .padding(.bottom, 4)
        }
        .frame(width: 160)
        .padding(.vertical, 8)
        .padding(.leading, 10)
        .padding(.trailing, 12)
        .background(
            Group {
                if colorScheme == .dark {
                    TabShape(isSelected: true)
                        .fill(Color(.black).opacity(0.40))
                        .shadow(
                            color: Color(.sRGBLinear, white: 0, opacity: 0.02),
                            radius: 4
                        )
                } else {
                    TabShape(isSelected: true)
                        .fill(Color(.controlBackgroundColor).opacity(0.86))
                        .shadow(
                            color: Color(.sRGBLinear, white: 0, opacity: 0.02),
                            radius: 4
                        )
                }
            }
        )
        // Extra horizontal padding to accommodate the TabShape's curved feet
        .padding(.horizontal, 10)
    }
}
