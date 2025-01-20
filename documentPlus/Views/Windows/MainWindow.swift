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
        CustomSplitView {
            Sidebar()
        } detail: {
            switch appState.activeSidebarItem {
            case .home:
                HomeView()
            case .connection(let connectionIntanceId):
                DatabaseView()
            }
        }
        .background(Color(.controlBackgroundColor).opacity(0.5))
    }
}
