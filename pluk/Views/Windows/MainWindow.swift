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
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        ZStack {
            VibrantBackgroundView()
                .edgesIgnoringSafeArea(.all)
            
            if colorScheme == .dark {
                Color(hex: 0x030303)
                    .opacity(0.2)
                    .blendMode(.multiply)
                    .edgesIgnoringSafeArea(.all)
            } else {
                Color(hex: 0xFCFCFC)
                    .opacity(0.015)
                    .blendMode(.multiply)
                    .edgesIgnoringSafeArea(.all)
            }
            
            if let connectionColor = sidebarViewModel.activeConnection?.connection.color, sidebarViewModel.activeSidebarItem != .home {
                connectionColor.color
                    .opacity(0.20)
                    .blendMode(.multiply)
                    .edgesIgnoringSafeArea(.all)
            }
            
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
                            DocumentView()
                                .environment(activeConnection)
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
        view.material = .sidebar
        view.blendingMode = .behindWindow
        view.state = .active
        view.wantsLayer = true
        return view
    }
    
    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {}
}

struct ConnectionErrorView: View {
    var body: some View {
        Text("Connection Error")
    }
}
