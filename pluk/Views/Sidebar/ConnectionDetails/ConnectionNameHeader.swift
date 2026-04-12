//
//  ConnectionNameHeader.swift
//  Collection
//
//  Created by Fauzaan on 3/23/25.
//

import SwiftUI

struct ConnectionNameHeader: View {
    @Environment(ConnectionInstance.self) private var connectionInstance
    @Environment(SidebarViewModel.self) private var viewModel
    @State private var isHovering = false
    @State private var showConnectionDetails = false
    @State private var showEditSheet = false
    @State private var showEditConfirmation = false
    @State private var showCreateCollectionPopover = false

    var body: some View {
        HStack(alignment: .center, spacing: 8) {
            DatabaseTypeIcon(databaseType: connectionInstance.connection.databaseType)

            VStack(alignment: .leading, spacing: 2) {
                Text(connectionInstance.connection.name)
                    .font(.headline)
                    .fontWeight(.regular)
                    .lineLimit(1)

                StatusBadge(status: connectionInstance.connectionStatus)
            }

            Spacer()

            // Action buttons
            HStack(spacing: 0) {
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        viewModel.isSearchVisible.toggle()
                        if !viewModel.isSearchVisible {
                            viewModel.searchText = ""
                        }
                    }
                }) {
                    Image(systemName: "magnifyingglass")
                        .font(.body)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(ActionButtonStyle())
                .keyboardShortcut("f", modifiers: [.command, .shift])
                .customHelp("Find Tables", shortcut: KeyboardShortcut(
                    modifiers: [KeyboardModifier.command, KeyboardModifier.shift],
                    key: "F"
                ))

                Button(action: {
                    showCreateCollectionPopover.toggle()
                }) {
                    Image(systemName: "plus.circle")
                        .font(.body)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(ActionButtonStyle())
                .keyboardShortcut("N", modifiers: [.command, .shift])
                .customHelp(
                    connectionInstance.databaseType?.dataModelType == .sql ? "New Table" : "New Collection",
                    shortcut: KeyboardShortcut(modifiers: [.command, .shift], key: "N")
                )
                .popover(isPresented: $showCreateCollectionPopover) {
                    CreateTableForm(onCreated: handleCollectionCreated)
                }
            }
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 6)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isHovering ? Color(.separatorColor).opacity(0.3) : Color.clear)
        )
        .onHover { hovering in
            isHovering = hovering
        }
        .contentShape(Rectangle())
        .onTapGesture {
            showConnectionDetails = true
        }
        .popover(isPresented: $showConnectionDetails, arrowEdge: .trailing) {
            ConnectionDetailsPopover(
                connection: connectionInstance.connection,
                databaseType: connectionInstance.connection.databaseType,
                environment: connectionInstance.connection.environment,
                version: connectionInstance.connectionVersion,
                connectedDatabase: connectionInstance.connectedDatabase?.name,
                onDisconnect: {
                    showConnectionDetails = false
                    await viewModel.disconnectConnectionInstance(connectionInstance.id)
                },
                onReconnect: {
                    showConnectionDetails = false
                    Task {
                        try await connectionInstance.reconnect()
                    }
                },
                onEdit: {
                    showConnectionDetails = false
                    if connectionInstance.connectionStatus == .connected {
                        showEditConfirmation = true
                    } else {
                        showEditSheet = true
                    }
                }
            )
        }
        .sheet(isPresented: $showEditSheet) {
            ZStack {
                VisualEffectView(material: .hudWindow, blendingMode: .behindWindow)
                    .ignoresSafeArea()

                CreateConnectionForm(
                    connection: connectionInstance.connection,
                    onDisconnect: {
                        await viewModel.disconnectConnectionInstance(connectionInstance.id)
                    }
                )
                .frame(width: 560)
            }
        }
        .alert("Edit Connection", isPresented: $showEditConfirmation) {
            Button("Continue") {
                showEditSheet = true
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Are you sure you want to edit this active connection?")
        }
        .padding(.bottom, 8)
    }

    private func handleCollectionCreated(_ createdName: String) {
        Task { @MainActor in
            let currentSchema = connectionInstance.databaseService.currentSchema
            connectionInstance.createNewTab(name: createdName, databaseSchema: currentSchema)

            do {
                try await connectionInstance.loadCollectionsForCurrentDatabase(schema: currentSchema)
            } catch {
                debugLog("Failed to refresh collections after create: \(error)")
            }
        }
    }
}

// MARK: - Status Badge
private struct StatusBadge: View {
    let status: ConnectionStatus

    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: statusIcon)
                .font(.system(size: 8, weight: .semibold))
                .foregroundStyle(statusColor)
                .if(status == .connecting) { view in
                    view.symbolEffect(.rotate.clockwise.byLayer, options: .repeat(.periodic(delay: 1)))
                }

            Text(statusText)
                .font(.caption)
                .foregroundStyle(statusColor)
        }
    }

    private var statusText: String {
        switch status {
        case .connected: "Connected"
        case .connecting: "Connecting"
        case .disconnected: "Disconnected"
        case .error: "Error"
        }
    }

    private var statusColor: Color {
        switch status {
        case .connected: .green
        case .connecting: .orange
        case .disconnected, .error: .secondary
        }
    }

    private var statusIcon: String {
        switch status {
        case .connected: "server.rack"
        case .connecting: "arrow.2.circlepath"
        case .disconnected, .error: "network.slash"
        }
    }
}
