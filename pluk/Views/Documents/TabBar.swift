//
//  TabBar.swift
//  Collection
//
//  Created by Fauzaan on 1/3/25.
//
import SwiftUI
import AppKit

struct TabBar: View {
    @Environment(AppViewModel.self) private var appViewModel
    @Environment(ConnectionInstance.self) private var instance
    @Environment(\.leadingOverlayWidth) private var leadingOverlayWidth
    @State private var isScrollable = false

    var body: some View {
        HStack(spacing: 0) {
            HStack(alignment: .center, spacing: 0) {
                navigationButtons
                customTabButtons

                if instance.databaseType?.supportsQueryEditor == true && isScrollable {
                    newTabButton(leadingPadding: -2)
                }
            }
            .padding(.trailing, 12)
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
                .padding(.trailing, 8)
        }
        .padding(
            .leading,
            !appViewModel.isSidebarVisible ? max(leadingOverlayWidth, 120) : 0
        )
        .frame(height: 36)
        .contentShape(Rectangle())
        .onTapGesture {
            // Consume background clicks to prevent window minimize/maximize
        }
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
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 4) {
                        ForEach(instance.tabs) { tab in
                            CustomTabButton(
                                tab: tab,
                                isSelected: instance.selectedTab?.id == tab.id,
                                onSelect: {
                                    instance.selectTab(tab)
                                },
                                onClose: {
                                    instance.removeTab(tab)
                                },
                                databaseType: instance.connection.databaseType
                            )
                            .padding(
                                .leading,
                                instance.tabs.first?.id == tab.id ? 6 : 0
                            )
                            .padding(
                                .trailing,
                                instance.tabs.last?.id == tab.id ? 6 : 0
                            )
                            .id(tab.id)
                        }
                        if instance.databaseType?.supportsQueryEditor == true && !isScrollable {
                            newTabButton(leadingPadding: -6)
                        }
                    }
                    .background(
                        GeometryReader { contentGeometry in
                            Color.clear
                                .preference(
                                    key: TabsWidthPreferenceKey.self,
                                    value: contentGeometry.size.width
                                )
                                .onAppear {
                                    isScrollable = contentGeometry.size.width > geometry.size.width
                                }
                                .onChange(of: contentGeometry.size.width) { _, newWidth in
                                    isScrollable = newWidth > geometry.size.width
                                }
                        }
                    )
                }
                .onChange(of: instance.selectedTab) { _, newValue in
                    if let tab = newValue {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            proxy.scrollTo(tab.id, anchor: .center)
                        }
                    }
                }
            }
        }
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
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(appViewModel.isRightSidebarVisible ? Color(.controlColor).opacity(0.8) : Color.clear)
                .animation(.easeInOut(duration: 0.15), value: appViewModel.isRightSidebarVisible)
        )
        .keyboardShortcut("\\", modifiers: [.command, .option])
        .customHelp(
            "Toggle Row Details",
            shortcut: KeyboardShortcut(
                modifiers: [.command, .option],
                key: "\\"
            )
        )
        .padding(.bottom, 4)
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
