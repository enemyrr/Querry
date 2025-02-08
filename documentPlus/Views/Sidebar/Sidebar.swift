//
//  Sidebar.swift
//  DocumentPlus
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
        VStack(spacing: 12) {
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
                    color: instance.accentColor,
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
private struct ConnectionDetailsSidebar: View {
    @Environment(SidebarViewModel.self) private var sidebarViewModel
    @State private var searchText: String = ""
    
    var body: some View {
        VStack(spacing: 0) {
            if let instance = sidebarViewModel.activeInstance {
                ConnectionHeader(instance: instance).padding(.bottom, 4)
                
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.gray)
                        .font(.system(size: 14))
                    
                    TextField("Search", text: $searchText)
                        .textFieldStyle(.plain)
                        .font(.system(size: 14))
                        .foregroundColor(.white)
                    
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .background {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.black.opacity(0.2))
                }
                
                DatabaseHeader(instance: instance)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 4)
                
                ScrollView {
                    SiderbarDatabaseList()
                }
            }
        }
        .padding(20)
        .padding(.vertical, 0)
        .background {
            RoundedRectangle(cornerRadius: 10)
                .stroke(.separator, lineWidth: 1)
        }
    }
}

// MARK: - Connection Header
private struct ConnectionHeader: View {
    let instance: ConnectionInstance
    @State private var isHovering = false
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 0) {
                    HStack(spacing: 8) {
                        Text(instance.connection.name).font(.system(size: 14))
                        
                        ConnectionStatusBadge(status: instance.connectionStatus, onRetry: {})
                        
//                        Image(systemName: "chevron.down")
//                            .font(.footnote)
//                            .opacity(0.7)
                        
                        Spacer()
                        Button(action: {
                            // Implement search
                        }) {
                            Image(systemName: "chevron.down").foregroundStyle(.secondary)
                        }
                        .padding(.trailing, -8)
                        .buttonStyle(ActionButtonStyle())
                        .opacity(isHovering ? 1 : 0)
                    }
                    .padding(.horizontal, 8)
                    .padding(.bottom, 12)
//                    .background(
//                        RoundedRectangle(cornerRadius: 8)
//                            .fill(
//                                (isHovering)
//                                ? (colorScheme == .dark ? Color.black : Color.white)
//                                    .opacity(
//                                        isHovering ? 0.2 : 0.3
//                                    )
//                                : Color.clear
//                            )
//                    )
                    .onHover { hovering in
                        withAnimation(.easeOut(duration: 0.05)) {
                            isHovering = hovering
                        }
                    }
                
            }
            .frame(alignment: .leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
//        .padding(.bottom, 8)
//        .background(
//               RoundedRectangle(cornerRadius: 8)
//                   .fill(Color.black.opacity(0.2))
//           )
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
//                Image(systemName: "arrowtriangle.down.fill")
//                    .font(.footnote)
//                    .scaleEffect(CGSize(width: 1, height: 0.7))
//                    .opacity(0.7)
                HStack(spacing: 4) {
                    Text(instance.database?.name ?? "No Database")
                        .font(.system(size: 12, weight: .semibold)) // Force unwrap NSFont
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                    
                    if (isHovering) {
                        Image(systemName: "chevron.down")
                            .font(.footnote)
                            .opacity(0.7)
                    }
               }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    RoundedRectangle(cornerRadius: 6)
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
            
            HStack(spacing: 4) {
                Button(action: {
                    // Implement search
                }) {
                    Image(systemName: "plus.circle").foregroundStyle(.secondary)
                }
                .buttonStyle(ActionButtonStyle())
                
//                Button(action: {
//                    // Implement search
//                }) {
//                    Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
//                }
//                .buttonStyle(ActionButtonStyle())
            }
        }.padding(.bottom, 5)
    }
}

