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
    @State private var sidebarViewModel: SidebarViewModel
    
    @Environment(\.modelContext) private var modelContext
    @State private var isSidebarVisible = true
    @Query private var connections: [Connection]
    @State private var activeConnection: Connection?
    
    init() {
        _sidebarViewModel = State(wrappedValue: SidebarViewModel(connectionManager: ConnectionManager.shared))
    }
    
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
                    Sidebar() // TODO:  - Do not pass shared instances on Env Space. Shared istances are GLOBAL CONSTANT variables depends on the App life cycle
                        .environment(sidebarViewModel)
                },
                detail: {
                    switch sidebarViewModel.activeSidebarItem {
                    case .home:
                        HomeView()
                            .environment(sidebarViewModel)
                    case .connection(_):
                        if let activeInstance = sidebarViewModel.activeInstance {
                            DocumentView(instance: activeInstance, isSidebarVisible: isSidebarVisible)
                        } else {
                            ConnectionErrorView()
                        }
                    }
                },
                isFullScreenView: sidebarViewModel.activeSidebarItem == .home,
                isSidebarVisible: $isSidebarVisible
            )
            
        }
        .toolbarBackground(.hidden, for: .windowToolbar)
        .containerBackground(.thickMaterial, for: .window)
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
