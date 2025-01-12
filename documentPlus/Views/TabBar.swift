//
//  TabBar.swift
//  DocumentPlus
//
//  Created by Fauzaan on 1/3/25.
//
import SwiftUI

struct TabBar: View {
    @Binding var tabs: [String]
    @Binding var selectedTab: String?
    
    var body: some View {
        Group {
            if !tabs.isEmpty {
                Divider()
                HStack(spacing: 0) {
                    navigationButtons
                    
                    Divider()
                    
                    tabScrollView
                }
                .frame(height: 30)
                .background(Color(NSColor.controlBackgroundColor))
                Divider()
            }
            
        }
    }
    
    private var navigationButtons: some View {
        HStack(spacing: 0) {
            NavigationButton(
                icon: "chevron.left",
                action: { previousTab((selectedTab ?? tabs.first)!) },
                isDisabled: selectedTab == tabs.first
            )
            
            NavigationButton(
                icon: "chevron.right",
                action: { nextTab((selectedTab ?? tabs.first)!) },
                isDisabled: selectedTab == tabs.last
            )
        }
        .padding(.horizontal, 10)
    }
    
    private var tabScrollView: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 0) {
                    ForEach(Array(tabs.enumerated()), id: \.offset) { index, tab in
                        TabBarItem(
                            tab: tab,
                            isSelected: selectedTab == tab,
                            onSelect: { selectedTab = tab },
                            onClose: { removeTab(tab) }
                        )
                        .id(tab)
                        .draggable(tab) {
                            Text(tab)
                                .padding(7)
                                .background(Color(NSColor.systemFill))
                        }
                        .dropDestination(for: String.self) { items, _ in
                            guard let sourceItem = items.first else { return false }
                            handleDrop(of: sourceItem, to: tab)
                            return true
                        }
                        
                        Divider()
                    }
                }
            }
            .onChange(of: tabs) { oldValue, newValue in
                handleTabsChange(oldValue: oldValue, newValue: newValue, proxy: proxy)
            }
            .onChange(of: selectedTab) { _, newValue in
                if let tab = newValue {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        proxy.scrollTo(tab, anchor: .trailing)
                    }
                }
            }
        }
    }
    
    private func handleTabsChange(oldValue: [String], newValue: [String], proxy: ScrollViewProxy) {
        if newValue.count > oldValue.count {
            if let lastTab = tabs.last {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        proxy.scrollTo(lastTab, anchor: .trailing)
                        selectedTab = lastTab
                    }
                }
            }
        }
    }
    
    private func handleDrop(of sourceItem: String, to destinationItem: String) {
        guard let sourceIndex = tabs.firstIndex(of: sourceItem),
              let destinationIndex = tabs.firstIndex(of: destinationItem),
              sourceIndex != destinationIndex else { return }
        
        tabs.remove(at: sourceIndex)
        tabs.insert(sourceItem, at: destinationIndex)
    }
    
    private func removeTab(_ item: String) {
        if let index = tabs.firstIndex(where: { $0 == item }) {
            tabs.remove(at: index)
            if selectedTab == item {
                selectedTab = tabs.last
            }
        }
    }
    
    private func nextTab(_ currentItem: String) {
        if let currentIndex = tabs.firstIndex(where: { $0 == currentItem }),
           currentIndex < tabs.count - 1 {
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedTab = tabs[currentIndex + 1]
            }
        }
    }
    
    private func previousTab(_ currentItem: String) {
        if let currentIndex = tabs.firstIndex(where: { $0 == currentItem }),
           currentIndex > 0 {
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedTab = tabs[currentIndex - 1]
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
    
    var body: some View {
        ZStack(alignment: .leading) {
            // Main tab content
            HStack {
                Text(tab)
                    .foregroundColor(isSelected ? .primary : .secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .contentShape(Rectangle())
            }
            .padding(.vertical, 7)
            .padding(.horizontal, 30)
            
            // Floating close button
            if isHovering {
                Button("Dismiss", systemImage: "xmark", action: onClose)
                    .labelStyle(.iconOnly)
                    .buttonStyle(.compactAccessory())
                    .controlSize(.small)
                    .offset(x: 8) // Fine-tune the position
                    .transition(.opacity)
            }
        }
        .background(isSelected ? Color(NSColor.systemFill) : .clear)
        .contentShape(Rectangle())
        .onTapGesture {
            onSelect()
        }
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.1)) {
                isHovering = hovering
            }
        }
    }
}

