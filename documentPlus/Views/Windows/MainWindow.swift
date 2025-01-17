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
    @Query private var connections: [Connection]
    @State private var activeSidebarItem: SidebarItem = .home
    @State private var activeConnection: Connection?
    
    var body: some View {
        CustomSplitView {
            Sidebar(
                activeSidebarItem: $activeSidebarItem,
                activeConnection: $activeConnection
            )
            
        } detail: {
            switch activeSidebarItem {
            case .home:
                HomeView(
                    activeSidebarItem: $activeSidebarItem,
                    activeConnection: $activeConnection
                )
            case .database(let name):
                DatabaseView(databaseName: name)
            }
        }
    }
}
