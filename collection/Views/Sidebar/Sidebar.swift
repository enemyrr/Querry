//
//  Sidebar.swift
//  Collection
//
//  Created by Fauzaan on 1/1/25.
//
import SwiftUI
import MongoKitten

struct Sidebar: View {
    @Environment(SidebarViewModel.self) private var sidebarViewModel
    
    var body: some View {
        HStack(spacing: 0) {
            NavigationSidebar()
                .frame(width: 50)
            
            if sidebarViewModel.activeSidebarItem != .home {
                ConnectionDetailsSidebar()
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 8)
    }
}

// MARK: - Navigation Sidebar
struct NavigationSidebar: View {
    @Environment(SidebarViewModel.self) private var sidebarViewModel
    
    var body: some View {
        VStack {
            topNavigationItems
            Spacer()
            bottomNavigationItems
        }
        .frame(width: 50)
    }
    
    private var topNavigationItems: some View {
        Group {
            IconButton(
                systemName: "house.fill",
                isSelected: sidebarViewModel.activeSidebarItem == .home
            ) {
                sidebarViewModel.changeActiveSidebarItem(.home)
            }
            
            Divider()
                .padding(.horizontal, 12)
                .padding(.bottom, -6)
            
            ForEach(sidebarViewModel.allInstances) { instance in
                DatabaseIcon(
                    color: instance.connection.color.color,
                    letter: instance.connection.name.prefix(1).uppercased(),
                    isSelected: sidebarViewModel.activeSidebarItem == .connection(instance.id)
                ) {
                    sidebarViewModel.changeActiveSidebarItem(.connection(instance.id))
                }
                .contextMenu {
                    Button(role: .destructive) {
                        Task {
                            sidebarViewModel.disconnectConnectionInstance(instance.id)
                        }
                    } label: {
                        Label("Disconnect", systemImage: "xmark.circle.fill")
                    }
                    
                    Divider()
                    
                    Button {
                        // Refresh connection action
                    } label: {
                        Label("Refresh", systemImage: "arrow.clockwise")
                    }
                    
                    Button {
                        // Copy connection string action
                    } label: {
                        Label("Copy Connection String", systemImage: "doc.on.doc")
                    }
                    
                    Button {
                        // Show connection details
                    } label: {
                        Label("Connection Details", systemImage: "info.circle")
                    }
                }
            }
        }
        .background(.clear)
    }
    
    private var bottomNavigationItems: some View {
        IconButtonWithoutBorder(
            systemName: "exclamationmark.bubble.fill",
            isSelected: false
        ) {}
            .padding(.bottom, 16)
    }
}

// MARK: - ConnectionDetailsSidebar
// MARK: - ConnectionDetailsSidebar
private struct ConnectionDetailsSidebar: View {
    @Environment(SidebarViewModel.self) private var sidebarViewModel
    @State private var isScrolled = false
    @Environment(\.colorScheme) private var colorScheme
    @Namespace private var scrollSpace
    
    var body: some View {
        VStack(spacing: 0) {
            // Fixed header content
            VStack {
                if let instance = sidebarViewModel.activeInstance {
                    ConnectionHeader(instance: instance)
                    SearchInput()
                }
            }
            .padding([.horizontal, .top])
            
            // Sticky database header with conditional separator
            if let instance = sidebarViewModel.activeInstance {
                VStack(spacing: 0) {
                    DatabaseHeader(instance: instance)
                        .padding(.horizontal)
                        .padding(.vertical, 4)
                    
                    SoftSeparator()
                        .opacity(isScrolled ? 1 : 0)
                }
                .animation(.easeOut(duration: 0.15), value: isScrolled)
            }
            
            // Scrollable content with scroll detection
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 0, pinnedViews: []) {
                        // Invisible marker view to detect when scrolled past
                        Color.clear
                            .frame(height: 1)
                            .id("scrollMarker")
                            .onAppear {
                                isScrolled = false
                            }
                            .onDisappear {
                                isScrolled = true
                            }
                        
                        SiderbarDatabaseList()
                    }
                }
            }
        }
        .background {
            RoundedRectangle(cornerRadius: 10)
                .stroke(.separator, lineWidth: 1)
        }
        .task(id: sidebarViewModel.activeSidebarItem.hashValue) {
            await sidebarViewModel.loadActiveConnection()
        }
    }
}

// Define a preference key to track scroll position
struct ScrollOffsetPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}


// MARK: - Connection Header
private struct ConnectionHeader: View {
    let instance: ConnectionInstance
    @State private var isHovered = false
    @State private var bubbleOffset = CGSize.zero
    
    // Get color based on connection status
    private var statusColor: Color {
        switch instance.connectionStatus {
        case .connected:
            return .green
        case .connecting:
            return .yellow
        case .disconnected:
            return .red
        case .error:
            return .red
        }
    }
    
    var body: some View {
        VStack(spacing: 6) {
            // Main content
            HStack(alignment: .center) {
                // Left side
                VStack(alignment: .leading, spacing: 4) {
                    Text(instance.connection.name)
                        .lineLimit(1)
                    ConnectionStatusBadge(status: instance.connectionStatus, onRetry: {})
                }
                
                Spacer(minLength: 16)
                
                // Right side
                EnvironmentTag(environment: instance.connection.environment)
                    .opacity(isHovered ? 1 : 0.8)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity)
        .background(
            ZStack {
                // Base background
                statusColor.opacity(0.06)
                
                // Inner glow layer
                Group {
                    ForEach(0..<4) { i in
                        RoundedRectangle(cornerRadius: 8)
                            .inset(by: Double(i) * 0.5)
                            .stroke(
                                statusColor.opacity(isHovered ? 0.1 : 0.05),
                                lineWidth: 1
                            )
                    }
                }
                .blur(radius: 4)
                .blendMode(.plusLighter)
                
                // Moving bubble with dynamic color
                Circle()
                    .fill(
                        RadialGradient(
                            gradient: Gradient(stops: [
                                .init(color: statusColor.opacity(0.4), location: 0),
                                .init(color: statusColor.opacity(0.2), location: 0.5),
                                .init(color: .clear, location: 1)
                            ]),
                            center: .leading,
                            startRadius: 1,
                            endRadius: 120
                        )
                    )
                    .frame(width: 240, height: 240)
                    .blur(radius: 30)
                    .offset(bubbleOffset)
                    .onAppear {
                        withAnimation(
                            .easeInOut(duration: 8)
                            .repeatForever(autoreverses: true)
                        ) {
                            bubbleOffset = CGSize(width: 50, height: 20)
                        }
                        
                        withAnimation(
                            .easeInOut(duration: 6)
                            .repeatForever(autoreverses: true)
                            .delay(1)
                        ) {
                            bubbleOffset.height = -20
                        }
                    }
            }
        )
        .cornerRadius(8)
        // Add inner shadow for depth
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(
                    statusColor.opacity(isHovered ? 0.3 : 0.15))
                .blendMode(.plusLighter)
                .padding(1)
        )
        .animation(.easeInOut(duration: 0.3), value: instance.connectionStatus)
        .animation(.easeInOut(duration: 0.2), value: isHovered)
        .onHover { hover in
            isHovered = hover
        }
    }
}
// MARK: - Detail Sidebar
struct DatabaseHeader: View {
    @Environment(\.colorScheme) var colorScheme
    var instance: ConnectionInstance
    @State private var isHovering = false
    
    var body: some View {
        HStack {
            HStack(spacing: 2) {
                HStack(spacing: 4) {
                    Text(instance.database?.name ?? "No Database")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                    
                    if (isHovering) {
                        Image(systemName: "chevron.down")
                            .font(.footnote)
                            .opacity(0.7)
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(
                            (isHovering)
                            ? (colorScheme == .dark ? Color.black : Color.white)
                                .opacity(
                                    isHovering ? 0.2 : 0.3
                                )
                            : Color.clear
                        )
                )
                .onHover { hovering in
                    withAnimation(.easeOut(duration: 0.05)) {
                        isHovering = hovering
                    }
                }
                
            }
            
            Spacer()
            
            HStack(spacing: 0) {
                Button(action: {
                    // Implement search
                }) {
                    Image(systemName: "plus.circle").foregroundStyle(.secondary)
                }
                .buttonStyle(ActionButtonStyle())
//                
//                                Button(action: {
//                                    // Implement search
//                                }) {
//                                    Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
//                                }
//                                .buttonStyle(ActionButtonStyle())
            }
        }
    }
}

// MARK: - SearchInput
struct SearchInput: View {
    @Environment(SidebarViewModel.self) private var viewModel
    
    var body: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.gray)
                .font(.system(size: 14))
            
            TextField("Search", text: Binding(
                get: { viewModel.searchText },
                set: { viewModel.searchText = $0 }
            ))
            .textFieldStyle(.plain)
            .font(.system(size: 14))
            .foregroundColor(.white)
            
            if !viewModel.searchText.isEmpty {
                Button(action: { viewModel.searchText = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.gray)
                        .font(.system(size: 12))
                }
                .buttonStyle(.plain)
                .onHover { hovering in
                    if hovering {
                        NSCursor.pointingHand.push()
                    } else {
                        NSCursor.pop()
                    }
                }
                .transition(.opacity)
                .padding(.horizontal, 2)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.black.opacity(0.2))
        }
        .animation(.easeInOut(duration: 0.2), value: viewModel.searchText)
    }
}
