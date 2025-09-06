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
    @State private var tabManager = TabManager.shared
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        ZStack {
            VibrantBackgroundView()
                .edgesIgnoringSafeArea(.all)
            
            if colorScheme == .dark {
                Color(hex: 0x030303)
                    .opacity(0.3)
                    .blendMode(.multiply)
                    .edgesIgnoringSafeArea(.all)
            } else {
                Color(hex: 0xFCFCFC)
                    .opacity(0.5)
                    .blendMode(.multiply)
                    .edgesIgnoringSafeArea(.all)
            }
            
// Show connection color for active connection tab
//            if let activeTab = tabManager.activeTab,
//               case .connection(let instanceId) = activeTab.type,
//               let connectionInstance = ConnectionService.shared.getInstance(instanceId) {
//                connectionInstance.connection.color.color
//                    .opacity(0.10)
//                    .blendMode(.multiply)
//                    .edgesIgnoringSafeArea(.all)
//            }
//            
            CustomSplitView(
                sidebar: {
                    Sidebar()
                        .environment(getCurrentConnection())
                },
                detail: {
                    PlukTabContentView()
                },
                isFullScreenView: tabManager.activeTab?.type == .home,
                isSidebarVisible: $appViewModel.isSidebarVisible
            )
        }
        .environment(appViewModel)
        .environment(sidebarViewModel)
        .environment(tabManager)
        .onAppear {
            // Ensure sidebar starts with home selected
            sidebarViewModel.changeActiveSidebarItem(.home)
        }
    }
    
    private func getCurrentConnection() -> ConnectionInstance? {
        guard let activeTab = tabManager.activeTab,
              case .connection(let instanceId) = activeTab.type else {
            return nil
        }
        return ConnectionService.shared.getInstance(instanceId)
    }
    
}

struct VibrantBackgroundView: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = .sidebar
//        view.blendingMode = .behindWindow
        view.state = .active
        view.wantsLayer = true
        return view
    }
    
    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {}
}


