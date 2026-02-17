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
    @Environment(\.modelContext) private var modelContext
    @Environment(SidebarViewModel.self) private var viewModel
    @Query(sort: \Connection.lastOpenedAt, order: .reverse)
    private var connections: [Connection]
    @Query(sort: \Notebook.updatedAt, order: .reverse)
    private var notebooks: [Notebook]
    @State private var showCreateSheet = false
    @State private var showConnectionAlert = false
    @State private var pendingConnection: Connection?

    private var allItems: [WorkspaceItem] {
        let items: [WorkspaceItem] =
            connections.map { .connection($0) } +
            notebooks.map { .notebook($0) }
        return items.sorted { $0.lastAccessedAt > $1.lastAccessedAt }
    }

    private var recentItems: [WorkspaceItem] {
        Array(allItems.prefix(8))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading) {
                Text("My Workspace")
                    .font(.title)
                    .fontWeight(.semibold)
                Text(
                    "Notebooks, connections, and everything in between."
                )
                .font(.subheadline)
                .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 20)
            .padding(.horizontal, 28)
            .padding(.bottom, 16)

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    RecentsSection(
                        items: recentItems,
                        onOpen: handleItemOpen
                    )

                    WorkspaceList(
                        items: allItems,
                        onOpenConnection: handleConnectionOpen,
                        onOpenNotebook: handleNotebookOpen,
                        onCreateConnection: { showCreateSheet = true },
                        onCreateNotebook: createAndOpenNotebook
                    )
                }
                .padding(.horizontal, 28)
                .padding(.bottom, 28)
            }
            .contentMargins(.trailing, 8, for: .scrollIndicators)
            .contentMargins(.bottom, 8, for: .scrollIndicators)
            .padding(.bottom, 8)
        }
        .frame(
            maxWidth: .infinity,
            maxHeight: .infinity,
            alignment: .leading
        )
        .postHogScreenView("HomeView")
        .sheet(isPresented: $showCreateSheet) {
            ZStack {
                VisualEffectView(
                    material: .hudWindow,
                    blendingMode: .behindWindow
                )
                .ignoresSafeArea()

                CreateConnectionForm()
                    .frame(width: 560)
            }
        }
        .alert("\"\(pendingConnection?.name ?? "")\" is already connected", isPresented: $showConnectionAlert) {
            Button("Continue Current Tab") {
                if let connection = pendingConnection,
                   let existingInstance = ConnectionService.shared.getExistingInstance(for: connection) {
                    connection.lastOpenedAt = Date()
                    viewModel.changeActiveSidebarItem(.connection(existingInstance.id))
                    Task { @MainActor in
                        AnalyticsService.shared.trackConnectionOpened(
                            databaseType: connection.databaseType,
                            isFirstConnection: false
                        )
                    }
                }
                pendingConnection = nil
            }
            Button("Create New Tab") {
                if let connection = pendingConnection {
                    connection.lastOpenedAt = Date()
                    let instanceId = viewModel.createNewConnectionInstance(for: connection)

                    if let connectionInstance = ConnectionService.shared.getInstance(instanceId) {
                        WindowController.newTab(
                            tabType: .connection(instanceId),
                            connectionInstance: connectionInstance
                        )
                        Task { @MainActor in
                            AnalyticsService.shared.trackConnectionOpened(
                                databaseType: connection.databaseType,
                                isFirstConnection: false
                            )
                        }
                    }
                }
                pendingConnection = nil
            }
            Button("Cancel", role: .cancel) {
                pendingConnection = nil
            }
        } message: {
            if let connection = pendingConnection {
                Text("You're already connected to \(connection.name) in another tab. Continuing will reuse the existing tab. Want to open a new one instead?")
            }
        }
    }

    // MARK: - Actions

    private func handleItemOpen(_ item: WorkspaceItem) {
        switch item {
        case .connection(let connection):
            handleConnectionOpen(connection)
        case .notebook(let notebook):
            handleNotebookOpen(notebook)
        }
    }

    private func createAndOpenNotebook() {
        let notebook = Notebook()
        modelContext.insert(notebook)
        handleNotebookOpen(notebook)
    }

    private func handleNotebookOpen(_ notebook: Notebook) {
        notebook.updatedAt = Date()
        SidebarItemRegistry.shared.addNotebook(id: notebook.id, title: notebook.title)
        WindowController.newTab(tabType: .notebook(notebook.id))
    }

    private func handleConnectionOpen(_ connection: Connection) {
        let isFirstConnection = connections.count == 1 && ConnectionService.shared.connectionInstances.isEmpty

        if ConnectionService.shared.getExistingInstance(for: connection) != nil {
            pendingConnection = connection
            showConnectionAlert = true
        } else {
            connection.lastOpenedAt = Date()
            let instanceId = viewModel.createNewConnectionInstance(for: connection)

            if let connectionInstance = ConnectionService.shared.getInstance(instanceId) {
                WindowController.newTab(
                    tabType: .connection(instanceId),
                    connectionInstance: connectionInstance
                )

                Task { @MainActor in
                    AnalyticsService.shared.trackConnectionOpened(
                        databaseType: connection.databaseType,
                        isFirstConnection: isFirstConnection
                    )
                }
            }
        }
    }
}

struct DatabaseTypeIcon: View {
    let databaseType: DatabaseType

    var body: some View {
        RoundedRectangle(cornerRadius: 8)
            .fill(databaseType.backgroundColor)
            .frame(width: 28, height: 28)
            .overlay(
                Image(databaseType.homeIcon)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 18, height: 18)
            )
    }
}
