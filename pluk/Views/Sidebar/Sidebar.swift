//
//  Sidebar.swift
//  Collection
//
//  Created by Fauzaan on 1/1/25.
//
import SwiftUI

struct Sidebar: View {
    @Environment(SidebarViewModel.self) var viewModel: SidebarViewModel
    @Environment(ConnectionInstance.self) var connectionInstance: ConnectionInstance?

    var body: some View {
        HStack(spacing: 0) {
            NavigationSidebar(viewModel: viewModel)
                .frame(width: 46, alignment: .leading)

            if connectionInstance != nil {
                ConnectionDetailsSidebar()
                    .environment(viewModel)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Navigation Sidebar
struct NavigationSidebar: View {
    var viewModel: SidebarViewModel
    @State private var tabChangeCounter = 0

    var body: some View {
        VStack {
            topNavigationItems
            Spacer()
            bottomNavigationItems
        }
        .frame(width: 50)
        .onReceive(NotificationCenter.default.publisher(for: .tabDidChange)) { _ in
            tabChangeCounter += 1
        }
    }


    private var isHomeTabActive: Bool {
        _ = tabChangeCounter // Force dependency on state change
        guard let activeTabType = WindowController.getCurrentActiveTabType() else {
            return true
        }

        if case .home = activeTabType {
            return true
        }
        return false
    }

    private func isConnectionTabActive(_ instanceId: UUID) -> Bool {
        _ = tabChangeCounter // Force dependency on state change
        if case .connection(let activeInstanceId) = WindowController.getCurrentActiveTabType() {
            return activeInstanceId == instanceId
        }
        return false
    }

    private var topNavigationItems: some View {
        Group {
            IconButton(
                systemName: "house.fill",
                isSelected: isHomeTabActive
            ) {
                WindowController.switchToTab(.home)
            }
            .padding(.bottom, -6)
            
            if !viewModel.connections.isEmpty {
                Divider()
                    .padding(.horizontal, 12)
                    .padding(.bottom, -6)
            }
            
            ForEach(viewModel.connections) { instance in
                let instanceId = instance.id
                
                DatabaseIcon(
                    color: instance.connection.color.color,
                    letter: instance.connection.name.prefix(1).uppercased(),
                    isSelected: isConnectionTabActive(instanceId)
                ) {
                    WindowController.switchToTab(.connection(instanceId))
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
                        let connectionURI = instance.connection.copyableConnectionUri
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
