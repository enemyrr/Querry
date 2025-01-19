//
//  Sidebar.swift
//  DocumentPlus
//
//  Created by Fauzaan on 1/1/25.
//
import SwiftUI
import MongoKitten

struct Sidebar: View {
    @State private var appState = AppState.shared
    @State private var selectedDatabase: MongoDatabase?
    @State private var databases: [MongoDatabase] = []
    @State private var isFetchingDatabases = false

    var body: some View {
        VStack(spacing: 0) {
            Button(action: { appState.activeSidebarItem = .home }) {
                Image(systemName: "house.fill").opacity(0.7)
                Text("Home")
            }
            .buttonStyle(
                SidebarButtonStyle(
                    isActive: appState.activeSidebarItem == .home))

            Button(action: {}) {
                HStack {
                    Image(systemName: "plus.app").opacity(0.7)
                    Text("New Connection")
                    Spacer()
                }
            }
            .buttonStyle(SidebarButtonStyle(isActive: false))

            Divider().padding(.vertical, 10)

            HStack {
                switch appState.activeSidebarTab {
                case .connections:
                    SiderbarConnectionsHeader()
                case .connection_details:
                    SiderbarConnectionDetailsHeader()
                }
            }
            .frame(height: 40)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 10)
            .padding(.bottom, 4)

            SidebarTabView()

            Spacer()

            Divider().padding(.vertical, 10)
            Button(action: {}) {
                HStack {
                    Image(systemName: "exclamationmark.bubble.fill").opacity(
                        0.7)
                    Text("Feedback")
                    Spacer()
                }
            }
            .buttonStyle(SidebarButtonStyle(isActive: false))
        }
        .padding(20)
    }
}

enum SidebarItem: Hashable {
    case home
    case database(String)
}

enum SidebarTab: Equatable {
    case connections
    case connection_details
}
