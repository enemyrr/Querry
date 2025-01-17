import MongoKitten
//
//  Sidebar.swift
//  DocumentPlus
//
//  Created by Fauzaan on 1/1/25.
//
import SwiftUI

enum SidebarItem: Hashable {
    case home
    case database(String)
}

struct SidebarButtonStyle: ButtonStyle {
    @Environment(\.colorScheme) var colorScheme
    @State private var isHovering = false
    let isActive: Bool
    
    func makeBody(configuration: Configuration) -> some View {
        HStack {
            configuration.label
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 8)
        .padding(.horizontal, 10)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(
                    (isActive || isHovering)
                    ? (colorScheme == .dark ? Color.black : Color.white)
                        .opacity(
                            (isActive && isHovering) ? 0.2 : 0.3
                        )
                    : Color.clear
                )
        )
        .onHover { hovering in
            isHovering = hovering
        }
    }
}

struct ActionButtonStyle: ButtonStyle {
    @Environment(\.colorScheme) var colorScheme
    @State private var isHovering = false
    
    func makeBody(configuration: Configuration) -> some View {
        HStack {
            configuration.label
        }
        .padding(5)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(
                    isHovering
                    ? (colorScheme == .dark ? Color.black : Color.white)
                        .opacity(0.3)
                    : Color.clear
                )
        )
        .onHover { hovering in
            isHovering = hovering
        }
    }
}

struct Sidebar: View {
    @Binding var activeSidebarItem: SidebarItem
    @Binding var activeConnection: Connection?
    @State private var selectedDatabase: MongoDatabase?
    @State private var databases: [MongoDatabase] = []
    @State private var isFetchingDatabases = false
    
    init(
        activeSidebarItem: Binding<SidebarItem>,
        activeConnection: Binding<Connection?>
    ) {
        _activeSidebarItem = activeSidebarItem
        _activeConnection = activeConnection
    }
    
    var body: some View {
        VStack(spacing: 0) {
            Button(action: { activeSidebarItem = .home }) {
                Image(systemName: "house.fill").opacity(0.7)
                Text("Home")
            }
            .buttonStyle(
                SidebarButtonStyle(isActive: activeSidebarItem == .home))
            
            Button(action: {}) {
                HStack {
                    Image(systemName: "plus.app").opacity(0.7)
                    Text("New Connection")
                    Spacer()
                }
            }
            .buttonStyle(SidebarButtonStyle(isActive: false))
            
            Divider().padding(.vertical, 10)
            
            if let activeConnection = activeConnection {
                Button(action: {}) {
                    HStack {
                        Text(activeConnection.name)
                        Spacer()
                        Image(systemName: "chevron.down")
                    }
                }
                .buttonStyle(SidebarButtonStyle(isActive: false))
            }
            
            HStack {
                Text("Databases")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .padding(.leading, 4)
                
                if (isFetchingDatabases) {
                    Spacer()
                    ProgressView()
                        .controlSize(.small)
                }
                
                Spacer()
                Button(action: {}) {
                    Image(systemName: "plus.circle")
                }
                .buttonStyle(ActionButtonStyle())
                .tint(.secondary)
                .foregroundStyle(.secondary)
            }
            .task(id: activeConnection?.name) {
                if let activeConnection = activeConnection {
                    isFetchingDatabases = true
                    await DatabaseProvider.shared.setupDatabase(
                        connectionString: activeConnection.url, databaseName: activeConnection.name
                    )
                    self.databases = await DatabaseProvider.shared
                        .fetchDatabases()
                    
                    isFetchingDatabases = false

                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 10)
            .padding(.bottom, 4)
            
            VStack(spacing: 0) {
                if databases.isEmpty {
                    Text("Select a connection to view databases")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .padding(.leading, 4)
                }
                
                ForEach(databases, id: \.name) { database in
                    Button(action: { activeSidebarItem = .database(database.name) }) {
                        HStack {
                            Image(systemName: "cylinder.split.1x2").opacity(0.7)
                            Text(database.name)
                            Spacer()
                        }
                    }
                    .buttonStyle(
                        SidebarButtonStyle(
                            isActive: activeSidebarItem == .database(database.name)
                        ))
                }
                
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
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


