//
//  Sidebar.swift
//  Collection
//
//  Created by Fauzaan on 1/1/25.
//
import SwiftUI

struct Sidebar: View {
    @Environment(SidebarViewModel.self) var viewModel: SidebarViewModel
    
    var body: some View {
        HStack(spacing: 0) {
            NavigationSidebar(viewModel: viewModel)
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
    var viewModel: SidebarViewModel
    
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
                isSelected: viewModel.activeSidebarItem == .home
            ) {
                viewModel.changeActiveSidebarItem(.home)
            }
            
            Divider()
                .padding(.horizontal, 12)
                .padding(.bottom, -6)
            
            ForEach(viewModel.connections) { instance in
                let instanceId = instance.id
                
                DatabaseIcon(
                    color: instance.connection.color.color,
                    letter: instance.connection.name.prefix(1).uppercased(),
                    isSelected: viewModel.activeSidebarItem == .connection(instanceId)
                ) {
                    viewModel.changeActiveSidebarItem(.connection(instanceId))
                }
                .contextMenu {
                    Button(role: .destructive) {
                        Task {
                            await viewModel.disconnectConnectionInstance(instanceId)
                        }
                    } label: {
                        Label("Disconnect", systemImage: "xmark.circle.fill")
                    }
                    
                    Divider()
                    
//                    Button {
//                        // Refresh connection action
//                    } label: {
//                        Label("Refresh", systemImage: "arrow.clockwise")
//                    }
                    
                    Button {
                        let connectionURI = instance.connection.connectionUri
                        let pasteboard = NSPasteboard.general
                        pasteboard.clearContents()
                        pasteboard.setString(connectionURI, forType: .string)
                    } label: {
                        Label("Copy Connection String", systemImage: "doc.on.doc")
                    }
                }
            }
        }
        .background(.clear)
    }
    
    var bottomNavigationItems: some View {
        IconButtonWithoutBorder(
            systemName: "exclamationmark.bubble.fill",
            isSelected: false
        ) {
            viewModel.showFeedbackForm()
        }
        .popover(
            isPresented: Binding<Bool>(
                get: { viewModel.isShowingFeedback },
                set: { viewModel.isShowingFeedback = $0 }
            ),
            arrowEdge: .trailing
        ) {
            FeedbackForm(viewModel: viewModel)
        }
        .padding(.bottom, 16)
    }
}
