//
//  WelcomeWindow.swift
//  Collection
//
//  Created by Fauzaan on 1/4/25.
//

import SwiftUI
import SwiftData
import AppKit
import MongoKitten

struct MainWindow: View {
    @State private var viewModel = SidebarViewModel(connectionManager: ConnectionManager.shared)
    
    @Environment(\.modelContext) private var modelContext
    @State private var isSidebarVisible = true
    @Query private var connections: [Connection]
    @State private var activeConnection: Connection?
    
    var body: some View {
        ZStack {
            VibrantBackgroundView()
                .edgesIgnoringSafeArea(.all)
            
            // Main Background color:
            // Replace on light theme
            Color(hex: 0x030303)
                .opacity(0.3)
                .edgesIgnoringSafeArea(.all)

            CustomSplitView(
                sidebar: {
                    Sidebar()
                        .environment(viewModel)
                },
                detail: {
                    switch viewModel.activeSidebarItem {
                    case .home:
                        HomeView()
                            .environment(viewModel)
                    case .connection(_):
                        if let activeInstance = viewModel.activeInstance {
                            DocumentView(instance: activeInstance, isSidebarVisible: isSidebarVisible)
                        } else {
                            ConnectionErrorView()
                        }
                    }
                },
                isFullScreenView: viewModel.activeSidebarItem == .home,
                isSidebarVisible: $isSidebarVisible
            )
            
        }
        .toolbarBackground(.hidden, for: .windowToolbar)
        .onAppear {
            _ = ConnectionManager.shared
        }
    }
}

struct VibrantBackgroundView: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = .sidebar  // Matches macOS sidebar effect
        view.blendingMode = .behindWindow
        view.state = .active
        return view
    }
    
    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {}
}

struct ConnectionErrorView: View {
    var body: some View {
        Text("Connection Error")
    }
}
