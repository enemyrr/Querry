//
//  Sidebar.swift
//  DocumentPlus
//
//  Created by Fauzaan on 1/1/25.
//
import SwiftUI
import MongoKitten

struct Sidebar: View {
    private var appState = AppState.shared
    private var connectionManager = ConnectionManager.shared
    
    private var activeInstance: ConnectionInstance? {
        appState.activeConnectionInstanceId.flatMap(connectionManager.getInstance)
    }
    
    var body: some View {
        HStack(spacing: 0) {
            NavigationSidebar()
                .frame(width: 50)
            
            if appState.activeSidebarItem != .home {
                DetailSidebar()
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 8)
    }
}

// MARK: - Navigation Sidebar
private struct NavigationSidebar: View {
    private var appState = AppState.shared
    private var connectionManager = ConnectionManager.shared
    
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
                isSelected: appState.activeSidebarItem == .home
            ) {
                appState.activeSidebarItem = .home
            }
            
            Divider()
                .padding(.horizontal, 12)
                .padding(.bottom, -6)
            
            ForEach(connectionManager.allInstances) { instance in
                DatabaseIcon(
                    color: instance.accentColor,
                    letter: instance.connection.name.prefix(1).uppercased(),
                    isSelected: appState.activeSidebarItem == .connection(instance.id)
                ) {
                    appState.changeActiveSidebarItem(.connection(instance.id))
                    appState.changeActiveTab(.connection_details)
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

// MARK: - Detail Sidebar
private struct DetailSidebar: View {
    private var appState = AppState.shared
    private var connectionManager = ConnectionManager.shared
    
    var body: some View {
        VStack(spacing: 0) {
            if let instance = activeInstance {
                ConnectionHeader(instance: instance)
                SiderbarConnectionDetailsHeader(instance: instance)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 10)
                
                ScrollView {
                    SidebarConnectionDetailsView()
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
    
    private var activeInstance: ConnectionInstance? {
        appState.activeConnectionInstanceId.flatMap(connectionManager.getInstance)
    }
}

// MARK: - Connection Header
private struct ConnectionHeader: View {
    let instance: ConnectionInstance
    
    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .center, spacing: 4) {
                HStack {
                    Text(instance.connection.name)
                    Image(systemName: "chevron.down")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    Spacer()
                    ConnectionStatusBadge(status: .connected, onRetry: {})
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Supporting Types
enum SidebarItem: Hashable {
    case home
    case connection(UUID)
}

enum SidebarTab: Equatable {
    case connections
    case connection_details
}
