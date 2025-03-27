//
//  TabBar.swift
//  Collection
//
//  Created by Fauzaan on 1/3/25.
//
import SwiftUI

struct TabBar: View {
    var instance: ConnectionInstance
    var isSidebarVisible: Bool
    
    var body: some View {
        HStack(spacing: 0) {
            if !isSidebarVisible {
                Divider()
                    .padding(.vertical, 4)
                    .padding(.leading, 8)
            }
            
            if !instance.tabs.isEmpty {
                navigationButtons
                
                Divider()
                    .padding(.vertical, 4)
                
                tabScrollView
            }
            
        }
        .padding(.leading, !isSidebarVisible ? 120 : 0)
        .frame(height: 30)
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
        .padding(.horizontal, 10)
    }
    
    private var tabScrollView: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 4) {
                    ForEach(instance.tabs) { tab in
                        TabBarItem(
                            tab: tab.name,
                            isSelected: instance.selectedTab?.name == tab.name,
                            onSelect: {
                                instance.selectTab(tab)
                            },
                            onClose: {
                                instance.removeTab(tab)
                            }
                        )
                        .padding(.leading, instance.tabs.first?.id == tab.id ? 8 : 0)
                        .padding(.trailing, instance.tabs.last?.id == tab.id ? 8 : 0)
                    }
                }
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

struct TabBarItem: View {
    let tab: String
    let isSelected: Bool
    let onSelect: () -> Void
    let onClose: () -> Void
    @State private var isHovering = false
    
    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 10) {
                    Button(action: onClose) {
                        Image(systemName: isHovering ? "xmark" : "document.fill")
                            .font(.system(size: 9))
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(TabBarButtonStyle())
                    .frame(width: 10, height: 10)
                
                Text(tab)
                    .foregroundColor(isSelected ? .primary : .secondary)
                    .lineLimit(1)
                
                Spacer(minLength: isSelected ? 50 : 0)
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected || isHovering ? Color.black.opacity(0.5) : Color.black.opacity(0.2))
            )
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.2)) {
                isHovering = hovering
            }
        }
    }
}
