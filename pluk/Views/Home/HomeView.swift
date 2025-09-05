//
//  HomeView.swift
//  Collection
//
//  Created by Fauzaan on 1/17/25.
//

import AppKit
import SwiftData
import SwiftUI

struct HomeView: View {
    @Environment(\.colorScheme) var colorScheme
    @Environment(SidebarViewModel.self) private var viewModel
    @Query(sort: \Connection.createdAt, order: .forward)
    private var connections: [Connection]
    @State private var showDatabaseModal = false
    @State private var selectedConnectionId: PersistentIdentifier?
    @State private var showCreateSheet = false
    @State private var showConnectionAlert = false
    @State private var pendingConnection: Connection?
    
    var body: some View {
        VStack(alignment: .leading) {
            VStack(alignment: .leading) {
                HStack {
                    VStack(alignment: .leading) {
                        Text("My Workspace")
                            .font(.title)
                            .fontWeight(.semibold)
                        Text(
                            "To get started, connect to an existing server or create a new one."
                        )
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    }
                    
                    Spacer()
                    CreateConnection(showSheet: $showCreateSheet)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 10)
                .padding(.top, 10)
                .padding(.bottom, 6)
                
                if connections.isEmpty {
                    EmptyConnectionsState(showSheet: $showCreateSheet)
                } else {
                    ConnectionList(
                        connections: connections,
                        selectedConnectionId: $selectedConnectionId,
                        onSelect: { connection in
                            selectedConnectionId = connection.persistentModelID
                        },
                        onOpen: { connection in
                            handleConnectionOpen(connection)
                        }
                    )
                }
                
                Spacer()
            }
            .padding(.top, 20)
            .padding(.horizontal, 20)
            .frame(
                maxWidth: .infinity,
                maxHeight: .infinity,
                alignment: .leading
            )
            .background(Color(.controlColor).opacity(colorScheme == .dark ? 0.1 : 0.4))
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(.separator)
            )
            .cornerRadius(20)
            .padding(8)
        }
        .postHogScreenView("HomeView")
        .alert(pendingConnection != nil ? "\"\(pendingConnection!.name)\" is already connected" : "", isPresented: $showConnectionAlert) {
            Button("Continue Current Tab") {
                if let connection = pendingConnection,
                   let existingInstance = ConnectionService.shared.getExistingInstance(for: connection) {
                    viewModel.changeActiveSidebarItem(.connection(existingInstance.id))
                }
                pendingConnection = nil
            }
            Button("Create New Tab") {
                if let connection = pendingConnection {
                    let instanceId = viewModel.createNewConnectionInstance(for: connection)
                    viewModel.changeActiveSidebarItem(.connection(instanceId))
                }
                pendingConnection = nil
            }
            Button("Cancel", role: .cancel) {
                pendingConnection = nil
            }
        } message: {
            if let connection = pendingConnection {
                Text("You’re already connected to \(connection.name) in another tab. Continuing will reuse the existing tab. Want to open a new one instead?")
            }
        }
    }
    
    private func handleConnectionOpen(_ connection: Connection) {
        if ConnectionService.shared.getExistingInstance(for: connection) != nil {
            pendingConnection = connection
            showConnectionAlert = true
        } else {
            let instanceId = viewModel.createNewConnectionInstance(for: connection)
            viewModel.changeActiveSidebarItem(.connection(instanceId))
        }
    }
}

struct EmptyConnectionsState: View {
    @Binding var showSheet: Bool
    
    var body: some View {
        VStack(spacing: 24) {
            ContentUnavailableView {
                Label("No Connections", systemImage: "server.rack")
                    .font(.title2)
            } description: {
                Text("Connect your first database to get started with managing your data.")
            } actions: {
                Button("Connect") {
                    showSheet.toggle()
                }
                .buttonStyle(OutlineSecondaryButtonStyle())
            }
        }
        .frame(maxWidth: 400)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.vertical, 40)
    }
}

struct ConnectionList: View {
    let connections: [Connection]
    @Binding var selectedConnectionId: PersistentIdentifier?
    let onSelect: (Connection) -> Void
    let onOpen: (Connection) -> Void
    
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Name")
                    .frame(width: 200, alignment: .leading)
                
                Spacer()
                
                Text("Last Opened")
                    .frame(width: 120, alignment: .leading)
                
                Text("Created")
                    .frame(width: 120, alignment: .leading)
            }
            .foregroundStyle(.secondary)
            .font(.system(size: 12))
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            
            Divider().padding(.bottom, 6)
            
            ScrollView {
                LazyVStack(spacing: 4) {
                    ForEach(connections) { connection in
                        ConnectionListItem(connection: connection, isSelected: connection.persistentModelID == selectedConnectionId, onSelect: self.onSelect, onOpen: self.onOpen)
                    }
                }
                .padding(.bottom, 0)
            }
        }
    }
}

struct DatabaseTypeIcon: View {
    let databaseType: DatabaseType
    
    var body: some View {
        HStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(databaseType.backgroundColor)
                .frame(width: 28, height: 28)
                .overlay(
                    Image(databaseType.homeIcon)
                        .resizable()
                        .frame(width: 18, height: 18)
                        .aspectRatio(contentMode: .fit)
                )
        }
    }
}

struct ConnectionListItem: View {
    let connection: Connection
    let isSelected: Bool
    let onSelect: (Connection) -> Void
    let onOpen: (Connection) -> Void
    @Environment(\.modelContext) private var modelContext
    @State private var isHovering = false
    @State private var showEditSheet = false
    @State private var showDeleteConfirmation = false
    @State private var connectionToDelete: Connection?
    
    var body: some View {
        HStack {
            HStack(spacing: 12) {
                HStack {
                    VStack(alignment: .leading) {
                        HStack {
                            DatabaseTypeIcon(databaseType: connection.databaseType)
                            
                            Text(connection.name)
                                .foregroundStyle(.primary)
                            
                            EnvironmentTag(environment: connection.environment)
                        }
                        
                        Text(connection.displayUrl)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
            }
            .frame(alignment: .leading)
            
            Spacer()
            
            Text(
                Date().timeIntervalSince(connection.lastOpenedAt) < 60
                ? "a moment ago"
                : connection.lastOpenedAt.formatted(.relative(presentation: .named))
            )
            .foregroundStyle(.secondary)
            .frame(width: 120, alignment: .leading)
            
            Text(
                connection.createdAt
                    .formatted(date: .abbreviated, time: .omitted)
            )
            .foregroundStyle(.secondary)
            .frame(width: 120, alignment: .leading)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(
                    isSelected || isHovering ? Color(.controlColor).opacity(0.3)  : Color.clear
                )
                .onTapGesture {
                    onSelect(connection)
                }
        )
        .simultaneousGesture(
            TapGesture(count: 2)
                .onEnded {
                    onOpen(connection)
                    connection.lastOpenedAt = Date()
                }
        )
        .onHover { hovering in
            isHovering = hovering
        }
        .sheet(isPresented: $showEditSheet) {
            ZStack {
                VisualEffectView(material: .hudWindow, blendingMode: .behindWindow)
                    .ignoresSafeArea()
                
                CreateConnectionForm(connection: connection)
                    .frame(width: 500)
            }
        }
        .contextMenu {
            Button {
                onOpen(connection)
                connection.lastOpenedAt = Date()
            } label: {
                Text("Connect")
            }
            
            Divider()
            
            Button {
                showEditSheet.toggle()
            } label: {
                Text("Edit")
            }
            
            Divider()
            
            Button {
                let connectionURI = connection.connectionUri
                
                let pasteboard = NSPasteboard.general
                pasteboard.clearContents()
                pasteboard.setString(connectionURI, forType: .string)
            } label: {
                Text("Copy connection string")
            }
            
            
            Divider()
            
            Button(role: .destructive) {
                // Store the connection to delete and show confirmation
                connectionToDelete = connection
                showDeleteConfirmation = true
            } label: {
                Text("Delete")
            }
        }
        .confirmationDialog(
            "Delete Connection",
            isPresented: $showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                if let connection = connectionToDelete {
                    // Clean up keychain before deleting the connection
                    connection.cleanupKeychain()
                    modelContext.delete(connection)
                    connectionToDelete = nil
                }
            }
            
            Button("Cancel", role: .cancel) {
                connectionToDelete = nil
            }
        } message: {
            Text("Are you sure you want to delete this connection? This action cannot be undone.")
        }
        .dialogSeverity(.critical)
    }
}
