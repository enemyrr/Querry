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
    @State private var tabPositions: [TabPosition] = []
    
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
        .coordinateSpace(name: "TabBar")
        .onPreferenceChange(TabPositionPreferenceKey.self) { positions in
            self.tabPositions = positions
        }
        .overlay(
            // Draw border at TabBar level so it can extend over navigation buttons
            TabBarBorderViewWithPositions(
                selectedTabId: instance.selectedTab?.id.uuidString ?? "",
                isVisible: instance.selectedTab != nil,
                tabPositions: tabPositions
            )
        )
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
                            tabId: tab.id.uuidString,
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
                .padding(.trailing, 20) // Add right side scroll offset
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
    let tabId: String
    let isSelected: Bool
    let onSelect: () -> Void
    let onClose: () -> Void
    let databaseType: DatabaseType
    @State private var isHovering = false
    
    var body: some View {
        Button(action: onSelect) {
            VStack {
                ZStack {
                    HStack(spacing: 8) {
                        Image(systemName: databaseType == .mongodb ? "document.fill" : "table")
                            .font(.system(size: 12))
                        
                        Text(tab)
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
                GeometryReader { geometry in
                    TabShape(isSelected: isSelected)
                        .fill(isSelected ? Color(.controlBackgroundColor).opacity(0.6) : Color.clear)
                        .preference(key: TabPositionPreferenceKey.self, value: [
                            TabPosition(id: tabId, frame: geometry.frame(in: .named("TabBar")))
                        ])
                }
            )
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isHovering ? Color(.controlColor).opacity(0.5) : Color.clear)
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
            let smoothness: CGFloat = 1 // Controls corner smoothness
            
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

// Extension to add border functionality
extension TabShape {
    func borderPath(in rect: CGRect) -> Path {
        var path = Path()
        
        if isSelected {
            let radius: CGFloat = 8
            let curveRadius: CGFloat = 10
            let smoothness: CGFloat = 1
            let extensionWidth: CGFloat = 5000  // How far to extend beyond bounds
            let extensionHeight: CGFloat = 1000 // How far to extend below
            
            // Start from bottom left curve point
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
            
            // EXTENSION BEYOND BOUNDS STARTS HERE
            
            // Extend further right beyond the view bounds
            path.addLine(to: CGPoint(x: rect.width + curveRadius + extensionWidth, y: rect.height))
            
            // Drop down to create extended border
            path.addLine(to: CGPoint(x: rect.width + curveRadius + extensionWidth, y: rect.height + extensionHeight))
            
            // Go back to the left side (creating bottom border)
            path.addLine(to: CGPoint(x: -curveRadius - extensionWidth, y: rect.height + extensionHeight))
            
            // Go back up on the left side
            path.addLine(to: CGPoint(x: -curveRadius - extensionWidth, y: rect.height))
            
            // Connect back to the starting point
            path.addLine(to: CGPoint(x: -curveRadius, y: rect.height))
            
            // Close the path to create a complete shape
            path.closeSubpath()
        }
        
        return path
    }
}

// Preference key to collect tab positions
struct TabPosition: Equatable {
    let id: String
    let frame: CGRect
}

struct TabPositionPreferenceKey: PreferenceKey {
    static var defaultValue: [TabPosition] = []
    
    static func reduce(value: inout [TabPosition], nextValue: () -> [TabPosition]) {
        value.append(contentsOf: nextValue())
    }
}

struct TabBarBorderViewWithPositions: View {
    let selectedTabId: String
    let isVisible: Bool
    let tabPositions: [TabPosition]
    
    var body: some View {
        GeometryReader { geometry in
            if isVisible, let selectedTabPosition = tabPositions.first(where: { $0.id == selectedTabId }) {
                return AnyView(
                    TabBarBorderShape(
                        tabFrame: selectedTabPosition.frame,
                        totalWidth: geometry.size.width
                    )
                    .stroke(Color(.separatorColor))
                    .allowsHitTesting(false)
                )
            } else {
                return AnyView(EmptyView())
            }
        }
    }
}

struct TabBarBorderShape: Shape {
    let tabFrame: CGRect
    let totalWidth: CGFloat
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        
        let radius: CGFloat = 8
        let curveRadius: CGFloat = 10
        let smoothness: CGFloat = 1
        let tabHeight = rect.height
        
        // Start from far left (covering navigation buttons)
        path.move(to: CGPoint(x: 22, y: tabHeight))
        
        // Draw line to the start of the left curve
        path.addLine(to: CGPoint(x: tabFrame.minX - curveRadius, y: tabHeight))
        
        // Bottom left outward curve
        path.addQuadCurve(
            to: CGPoint(x: tabFrame.minX, y: tabHeight - curveRadius),
            control: CGPoint(x: tabFrame.minX - 2 * smoothness, y: tabHeight)
        )
        
        // Left side line up
        path.addLine(to: CGPoint(x: tabFrame.minX, y: radius))
        
        // Top left rounded corner
        path.addQuadCurve(
            to: CGPoint(x: tabFrame.minX + radius, y: 0),
            control: CGPoint(x: tabFrame.minX, y: 0)
        )
        
        // Top line
        path.addLine(to: CGPoint(x: tabFrame.maxX - radius, y: 0))
        
        // Top right rounded corner
        path.addQuadCurve(
            to: CGPoint(x: tabFrame.maxX, y: radius),
            control: CGPoint(x: tabFrame.maxX, y: 0)
        )
        
        // Right side line down
        path.addLine(to: CGPoint(x: tabFrame.maxX, y: tabHeight - curveRadius))
        
        // Bottom right outward curve
        path.addQuadCurve(
            to: CGPoint(x: tabFrame.maxX + curveRadius, y: tabHeight),
            control: CGPoint(x: tabFrame.maxX + 2 * smoothness, y: tabHeight)
        )
        
        // Continue line to the far right
        path.addLine(to: CGPoint(x: totalWidth - 22, y: tabHeight))
        
        return path
    }
}

struct TabConnectedBorder: View {
    var body: some View {
        GeometryReader { geometry in
            Path { path in
                let rect = geometry.frame(in: .local)
                let cornerRadius: CGFloat = 10
                let topBorderLength: CGFloat = 14
                
                // Start from top-right corner with short top border
                path.move(to: CGPoint(x: rect.width - topBorderLength, y: 0))
                
                // Short top border on the right
                path.addLine(to: CGPoint(x: rect.width - cornerRadius, y: 0))
                
                // Top-right corner
                path.addQuadCurve(
                    to: CGPoint(x: rect.width, y: cornerRadius),
                    control: CGPoint(x: rect.width, y: 0)
                )
                
                // Right border
                path.addLine(to: CGPoint(x: rect.width, y: rect.height - cornerRadius))
                
                // Bottom-right corner
                path.addQuadCurve(
                    to: CGPoint(x: rect.width - cornerRadius, y: rect.height),
                    control: CGPoint(x: rect.width, y: rect.height)
                )
                
                // Bottom border
                path.addLine(to: CGPoint(x: cornerRadius, y: rect.height))
                
                // Bottom-left corner
                path.addQuadCurve(
                    to: CGPoint(x: 0, y: rect.height - cornerRadius),
                    control: CGPoint(x: 0, y: rect.height)
                )
                
                // Left border
                path.addLine(to: CGPoint(x: 0, y: cornerRadius))
                
                // Top-left corner
                path.addQuadCurve(
                    to: CGPoint(x: cornerRadius, y: 0),
                    control: CGPoint(x: 0, y: 0)
                )
                
                // Short top border on the left
                path.addLine(to: CGPoint(x: topBorderLength, y: 0))
            }
            .stroke(Color(.separatorColor), lineWidth: 1)
        }
    }
}
