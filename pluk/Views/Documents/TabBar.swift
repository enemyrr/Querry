//
//  TabBar.swift
//  Collection
//
//  Created by Fauzaan on 1/3/25.
//
import SwiftUI

struct TabBar: View {
    @Environment(AppViewModel.self) private var appViewModel
    var instance: ConnectionInstance
    
    var body: some View {
        HStack(spacing: 0) {
            if !appViewModel.isSidebarVisible {
                Divider()
                    .padding(.vertical, 6)
                    .padding(.leading, 8)
            }
            
            if !instance.tabs.isEmpty {
                navigationButtons
                
                tabScrollView
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
                            },
                            databaseType: instance.connection.databaseType
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
    let databaseType: DatabaseType
    @State private var isHovering = false
    
    var body: some View {
        Button(action: onSelect) {
            VStack {
                HStack(spacing: 8) {
                    Image(systemName: databaseType == .mongodb ? "document.fill" : "table")
                        .font(.system(size: 12))
                    
                    Text(tab)
                        .lineLimit(1)
                    
                    Spacer()
                    
                    if isHovering {
                        Button(action: onClose) {
                            Image(systemName: "xmark")
                                .font(.system(size: 12))
                        }
                        .buttonStyle(TabCloseButtonStyle())
                        .frame(width: 10, height: 10)
                    }
                }
                .padding(.bottom, 4)
            }
            .frame(width: 160)
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .background(
                TabShape(isSelected: isSelected)
                    .fill(isSelected ? Color(NSColor.controlColor).opacity(0.1) : Color.clear)
            )
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isHovering ? Color(.controlColor).opacity(0.6) : Color.clear)
                    .padding(.bottom, 4)
                    .opacity(isSelected ? 0 : 1)
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


struct TabShape: Shape {
    let isSelected: Bool
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        
        if isSelected {
            let radius: CGFloat = 8
            let curveRadius: CGFloat = 10
            let smoothness: CGFloat =  1 // Controls corner smoothness
            
            // Start from bottom left (extended)
            path.move(to: CGPoint(x: -curveRadius, y: rect.height))
            
            // Bottom left outward curve - more pronounced with smoothness
            path.addQuadCurve(
                to: CGPoint(x: 0, y: rect.height - curveRadius),
                control: CGPoint(x: -2 * smoothness, y: rect.height)
            )
            
            // Left side line up
            path.addLine(to: CGPoint(x: 0, y: radius))
            
            // Top left rounded corner with smoothness
            path.addQuadCurve(
                to: CGPoint(x: radius, y: 0),
                control: CGPoint(x: 0, y: 0)
            )
            
            // Top line
            path.addLine(to: CGPoint(x: rect.width - radius, y: 0))
            
            // Top right rounded corner with smoothness
            path.addQuadCurve(
                to: CGPoint(x: rect.width, y: radius),
                control: CGPoint(x: rect.width, y: 0)
            )
            
            // Right side line down
            path.addLine(to: CGPoint(x: rect.width, y: rect.height - curveRadius))
            
            // Bottom right outward curve - more pronounced with smoothness
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
