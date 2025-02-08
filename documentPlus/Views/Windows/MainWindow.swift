//
//  WelcomeWindow.swift
//  DocumentPlus
//
//  Created by Fauzaan on 1/4/25.
//

import SwiftUI
import SwiftData
import AppKit
import MongoKitten

struct MainWindow: View {
    @State private var connectionManager = ConnectionManager.shared
    @State private var sidebarViewModel = SidebarViewModel(connectionManager: ConnectionManager.shared)
    
    @Environment(\.modelContext) private var modelContext
    @Query private var connections: [Connection]
    @State private var activeConnection: Connection?
    
    var body: some View {
        CustomSplitView(
            sidebar: {
                Sidebar()
                    .environment(sidebarViewModel)
                    .environment(connectionManager)
            },
            detail: {
                switch sidebarViewModel.activeSidebarItem {
                case .home:
                    HomeView()
                        .environment(sidebarViewModel)
                case .connection(_):
                    if let activeInstance = sidebarViewModel.activeInstance {
                        DatabaseView(instance: activeInstance)
                    } else {
                        ConnectionErrorView()
                    }
                }
            },
            isFullScreenView: sidebarViewModel.activeSidebarItem == .home
        )
        .background(Color(.controlBackgroundColor).opacity(0.5))
    }
}

struct ConnectionErrorView: View {
    var body: some View {
        Text("Connection Error")
    }
}
