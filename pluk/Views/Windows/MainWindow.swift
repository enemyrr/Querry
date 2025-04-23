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
    @State private var appViewModel = AppViewModel()
    @State private var sidebarViewModel = SidebarViewModel()
    @Environment(\.modelContext) private var modelContext

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
                },
                detail: {
                    switch sidebarViewModel.activeSidebarItem {
                    case .home:
                        HomeView()
                    case .connection(_):
                        if let activeConnection = sidebarViewModel.activeConnection {
                            DocumentView(instance: activeConnection)
                        } else {
                            ConnectionErrorView()
                        }
                    }
                },
                isFullScreenView: sidebarViewModel.activeSidebarItem == .home,
                isSidebarVisible: $appViewModel.isSidebarVisible
            )
            
        }
        .environment(appViewModel)
        .environment(sidebarViewModel)
        .toolbarBackground(.hidden, for: .windowToolbar)
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
