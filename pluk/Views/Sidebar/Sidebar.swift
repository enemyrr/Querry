//
//  Sidebar.swift
//  Collection
//
//  Created by Fauzaan on 1/1/25.
//
import SwiftUI
import MongoKitten

struct Sidebar: View {
    @Environment(SidebarViewModel.self) var viewModel: SidebarViewModel
    
    var body: some View {
        HStack(spacing: 0) {
            NavigationSidebar(model: viewModel)
                .frame(width: 50)
            
            if viewModel.activeSidebarItem != .home {
                ConnectionDetailsSidebar()
                    .environment(viewModel)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 8)
    }
}

// MARK: - Navigation Sidebar
struct NavigationSidebar: View {
    var model: SidebarViewModel
    
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
                isSelected: model.activeSidebarItem == .home
            ) {
                model.changeActiveSidebarItem(.home)
            }
            
            Divider()
                .padding(.horizontal, 12)
                .padding(.bottom, -6)
            
            ForEach(model.allInstances) { instance in
                let instanceId = instance.id
                
                DatabaseIcon(
                    color: instance.connection.color.color,
                    letter: instance.connection.name.prefix(1).uppercased(),
                    isSelected: model.activeSidebarItem == .connection(instanceId)
                ) {
                    model.changeActiveSidebarItem(.connection(instanceId))
                }
                .contextMenu {
                    Button(role: .destructive) {
                        Task {
                            await model.disconnectConnectionInstance(instanceId)
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
