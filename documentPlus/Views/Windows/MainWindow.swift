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
    @Environment(\.modelContext) private var modelContext
    @State private var appState = AppState.shared
    @Query private var connections: [Connection]
    @State private var activeConnection: Connection?
    
    var body: some View {
        CustomSplitView(
            sidebar: {
                Sidebar()
            },
            detail: {
                switch appState.activeSidebarItem {
                case .home:
                    HomeView()
                case .connection(let connectionIntanceId):
                    if let instance = ConnectionManager.shared.getInstance(connectionIntanceId) {
                        DatabaseView(instance: instance)
                    } else {
                        ConnectionErrorView()
                    }
                }
            },
            isFullScreenView: appState.activeSidebarItem == .home
        )
        .background(Color(.controlBackgroundColor).opacity(0.5))
    }
}

struct ConnectionErrorView: View {
    var body: some View {
        Text("Connection Error")
    }
}
