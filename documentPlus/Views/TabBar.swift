//
//  TabBar.swift
//  DocumentPlus
//
//  Created by Fauzaan on 1/3/25.
//
import SwiftUI

struct TabBar: View {
    var instance: ConnectionInstance
    
    var body: some View {
        HStack(spacing: 0) {
            if !instance.tabs.isEmpty {
               navigationButtons
            
            Divider()
                .padding(.vertical, 6)
                .padding(.trailing, 10)
            
            tabScrollView 
            }
            
        }
        .frame(height: 30)
    }
    
    private var navigationButtons: some View {
        HStack(spacing: 0) {
            NavigationButton(
                icon: "chevron.left",
                action: {
                    previousTab((instance.selectedTab ?? instance.tabs.first)!)
                },
                isDisabled: instance.selectedTab == instance.tabs.first
            )
            
            NavigationButton(
                icon: "chevron.right",
                action: {
                    nextTab((instance.selectedTab ?? instance.tabs.first)!)
                },
                isDisabled: instance.selectedTab == instance.tabs.last
            )
        }
        .padding(.horizontal, 10)
    }
    
    private var tabScrollView: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack() {
                    ForEach(instance.tabs) { tab in
                        TabBarItem(
                            tab: tab.name,
                            isSelected: instance.selectedTab?.name == tab.name,
                            onSelect: {
                                selectTab(tab)
                            },
                            onClose: {
                                removeTab(tab)
                            }
                        )
                        .id(tab.id)
                        .draggable(tab) {
                            Text(tab.name)
                                .padding(7)
                                .background(Color(NSColor.systemFill))
                        }
                        .dropDestination(for: DatabaseTab.self) { tabs, _ in
                            guard let sourceItem = tabs.first else { return false }
                            handleDrop(of: sourceItem, to: tab)
                            return true
                        }
                        
                    }
                }
            }
            .onChange(of: instance.tabs) { oldValue, newValue in
                handleTabsChange(oldValue: oldValue, newValue: newValue, proxy: proxy)
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
    
    private func handleTabsChange(oldValue: [DatabaseTab], newValue: [DatabaseTab], proxy: ScrollViewProxy) {
        if newValue.count > oldValue.count {
            if let lastTab = instance.tabs.last {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectTab(lastTab)
                    }
                }
            }
        }
    }
    
    private func handleDrop(of sourceTab: DatabaseTab, to destinationTab: DatabaseTab) {
        guard let sourceIndex = instance.tabs.firstIndex(where: {
            $0.id == sourceTab.id
        }),
              
                let destinationIndex = instance.tabs.firstIndex(where: {
                    $0.id == destinationTab.id
                }),
              
                sourceIndex != destinationIndex else { return }
        
        
        instance.tabs.swapAt(sourceIndex, destinationIndex)
    }
    
    private func nextTab(_ currentTab: DatabaseTab) {
        if let currentIndex = instance.tabs.firstIndex(where: { $0.id == currentTab.id }),
           currentIndex < instance.tabs.count - 1 {
            instance.selectedTab = instance.tabs[currentIndex + 1]
        }
    }
    
    private func previousTab(_ currentTab: DatabaseTab) {
        if let currentIndex = instance.tabs.firstIndex(where: { $0.id == currentTab.id }),
           currentIndex > 0 {
            instance.selectedTab = instance.tabs[currentIndex - 1]
        }
    }
    
    private func selectTab(_ tab: DatabaseTab) {
        instance.selectedTab = tab
    }
    
    private func removeTab(_ tab: DatabaseTab) {
        if instance.tabs.count > 0 {
            instance.tabs.removeAll { $0.id == tab.id }
            
            if let firstTab = instance.tabs.first {
                instance.selectedTab = firstTab
            } else {
                instance.selectedTab = nil
            }
        }
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
                .padding(.vertical, 6)
                .padding(.horizontal, 8)
                .contentShape(Rectangle())
        }
        .disabled(isDisabled)
        .buttonStyle(.plain)
    }
}

struct TabBarItem: View {
    let tab: String
    let isSelected: Bool
    let onSelect: () -> Void
    let onClose: () -> Void
    @State private var isHovering: Bool = false
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        Button(action: onSelect) {
            ZStack(alignment: .leading) {
                // Main tab content
                HStack {
                    Text(tab)
                        .foregroundColor(isSelected ? .primary : .secondary)
                        .lineLimit(1)
                    Spacer(minLength: 0)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
                .padding(.horizontal, 30)
                
                // Floating close button
                if isHovering {
                    Button(action: onClose) {
                        Image(systemName: "xmark")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(CloseButtonStyle())
                    .offset(x: 8)
                    .transition(.opacity)
                }
            }
        }
        .buttonStyle(TabBarButtonStyle(isActive: isSelected, isHovering: isHovering))
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.1)) {
                isHovering = hovering
            }
        }
    }
}

