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
    
    var body: some View {
        HStack(spacing: 0) {
            if !appViewModel.isSidebarVisible {
                Divider()
                    .padding(.vertical, 6)
                    .padding(.leading, 8)
            }
            
            if !instance.tabs.isEmpty {
                navigationButtons
                
                customTabButtons
                    .background(
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
            }
        }
        .padding(.leading, !appViewModel.isSidebarVisible ? 120 : 0)
        .frame(height: 36)
        
    }
    
    private var navigationButtons: some View {
        HStack(spacing: 0) {
            NavigationButton(
                icon: "chevron.left",
                action: {
                    instance.previousTab((instance.selectedTab ?? instance.tabs.first)!)
                },
                isDisabled: instance.selectedTab == instance.tabs.first
            )
            .keyboardShortcut("[", modifiers: [.command, .shift])
            .customHelp("Previous tab", position: .bottom, shortcut: KeyboardShortcut(
                modifiers: [.command, .shift],
                key: "["
            ))
            
            NavigationButton(
                icon: "chevron.right",
                action: {
                    instance.nextTab((instance.selectedTab ?? instance.tabs.first)!)
                },
                isDisabled: instance.selectedTab == instance.tabs.last
            )
            .keyboardShortcut("]", modifiers: [.command, .shift])
            .customHelp("Next tab", position: .bottom, shortcut: KeyboardShortcut(
                modifiers: [.command, .shift],
                key: "]"
            ))
        }
        .padding(.leading, 10)
    }
    
    private var customTabButtons: some View {
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
                        .padding(.leading, instance.tabs.first?.id == tab.id ? 8 : 0)
                        .padding(.trailing, instance.tabs.last?.id == tab.id ? 8 : 0)
                    }
                }
                .padding(.trailing, 20)
            }
            .onChange(of: instance.selectedTab) { _, newValue in
                if let tab = newValue {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        proxy.scrollTo(tab.id, anchor: .trailing)
                    }
                }
            }
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
        Coordinator(instance: instance)
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
            let currentTabIdentifiers = Set(tabView.tabViewItems.compactMap { $0.identifier as? String })
            let expectedTabIdentifiers = Set(instance.tabs.map { $0.id.uuidString })
            
            for identifier in currentTabIdentifiers {
                if !expectedTabIdentifiers.contains(identifier) {
                    if let item = tabView.tabViewItems.first(where: { ($0.identifier as? String) == identifier }) {
                        tabView.removeTabViewItem(item)
                    }
                }
            }
            
            // Add or update tabs
            for (index, tab) in instance.tabs.enumerated() {
                let identifier = tab.id.uuidString
                
                if let existingItem = tabView.tabViewItems.first(where: { ($0.identifier as? String) == identifier }) {
                    // Update existing tab
                    existingItem.label = tab.name
                    existingItem.image = NSImage(systemSymbolName: instance.connection.databaseType == .mongodb ? "document.fill" : "table", accessibilityDescription: nil)
                } else {
                    // Create new tab
                    let tabViewItem = NSTabViewItem(identifier: identifier)
                    tabViewItem.label = tab.name
                    tabViewItem.image = NSImage(systemSymbolName: instance.connection.databaseType == .mongodb ? "document.fill" : "table", accessibilityDescription: nil)
                    
                    // Create the actual content view for the tab
                    let tabContentView = TabContentView(tab: tab, databaseType: instance.connection.databaseType, selectedTab: instance.selectedTab)
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
               let item = tabView.tabViewItems.first(where: { ($0.identifier as? String) == selectedTab.id.uuidString }) {
                tabView.selectTabViewItem(item)
            }
        }
        
        // MARK: - NSTabViewDelegate
        
        func tabView(_ tabView: NSTabView, didSelect tabViewItem: NSTabViewItem?) {
            guard !isUpdating,
                  let identifier = tabViewItem?.identifier as? String,
                  let tab = instance.tabs.first(where: { $0.id.uuidString == identifier }) else {
                return
            }
            
            instance.selectTab(tab)
        }
        
        func tabView(_ tabView: NSTabView, shouldSelect tabViewItem: NSTabViewItem?) -> Bool {
            return true
        }
        
        // Handle tab closing via context menu or gesture
        func tabView(_ tabView: NSTabView, willSelect tabViewItem: NSTabViewItem?) {
            // Add context menu for tab closing
            if let item = tabViewItem,
               let identifier = item.identifier as? String,
               let tab = instance.tabs.first(where: { $0.id.uuidString == identifier }) {
                
                let menu = NSMenu()
                let closeItem = NSMenuItem(title: "Close Tab", action: #selector(closeTab(_:)), keyEquivalent: "w")
                closeItem.keyEquivalentModifierMask = [.command]
                closeItem.representedObject = tab
                closeItem.target = self
                menu.addItem(closeItem)
                
                // Add close other tabs option
                let closeOthersItem = NSMenuItem(title: "Close Other Tabs", action: #selector(closeOtherTabs(_:)), keyEquivalent: "")
                closeOthersItem.representedObject = tab
                closeOthersItem.target = self
                menu.addItem(closeOthersItem)
                
                item.view?.menu = menu
            }
        }
        
        @objc private func closeTab(_ sender: NSMenuItem) {
            if let tab = sender.representedObject as? DatabaseTab {
                instance.removeTab(tab)
            }
        }
        
        @objc private func closeOtherTabs(_ sender: NSMenuItem) {
            if let currentTab = sender.representedObject as? DatabaseTab {
                let tabsToClose = instance.tabs.filter { $0.id != currentTab.id }
                for tab in tabsToClose {
                    instance.removeTab(tab)
                }
            }
        }
    }
}

// Custom tab button with your styling
struct CustomTabButton: View {
    let tab: DatabaseTab
    let isSelected: Bool
    let onSelect: () -> Void
    let onClose: () -> Void
    let databaseType: DatabaseType
    @State private var isHovering = false
    
    var body: some View {
        VStack {
            ZStack {
                HStack(spacing: 8) {
                    Image(systemName: databaseType == .mongodb ? "document.fill" : "table")
                        .font(.system(size: 12))
                    
                    Text(tab.name)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    
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
            TabShape(isSelected: isSelected)
                .fill(isSelected ? Color(.controlBackgroundColor).opacity(0.3) : Color.clear)
        )
        .overlay(
            TabBorderShape(isSelected: isSelected)
                .stroke(isSelected ? Color(.separatorColor) : Color.clear, lineWidth: 1)
        )
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isHovering ? Color(.controlColor).opacity(0.5) : Color.clear)
                .padding(.bottom, 4)
                .opacity(isSelected ? 0 : 1)
        ).onHover { hovering in
            withAnimation(.easeInOut(duration: 0.2)) {
                isHovering = hovering
            }
        }.onTapGesture {
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
            let radius: CGFloat = 8
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
            path.addLine(to: CGPoint(x: rect.width, y: rect.height - curveRadius))
            
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
            let radius: CGFloat = 8
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
            path.addLine(to: CGPoint(x: rect.width, y: rect.height - curveRadius))
            
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
    
    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 6, height: 12)
                .padding(8)
                .contentShape(Rectangle())
        }
        .disabled(isDisabled)
        .buttonStyle(.plain)
    }
}


