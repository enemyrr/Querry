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
    private var authService = WorkOSAuthService.shared
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

    private var titleText: String {
        allItems.isEmpty ? "Welcome to Pluk" : "My Workspace"
    }

    private var subtitleText: String {
        allItems.isEmpty
            ? "Start by connecting your first database."
            : "Notebooks, connections, and everything in between."
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top, spacing: 16) {
                VStack(alignment: .leading) {
                    Text(titleText)
                        .font(.title)
                        .fontWeight(.semibold)
                    Text(subtitleText)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                if !authService.isPro {
                    FreePlanBadge()
                        .padding(.top, 4)
                }
            }
            .padding(.top, 20)
            .padding(.horizontal, 28)
            .padding(.bottom, 16)

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    if !recentItems.isEmpty {
                        RecentsSection(
                            items: recentItems,
                            onOpen: handleItemOpen
                        )
                    }

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
            CreateConnectionForm()
                .frame(width: 480)
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
                    if ConnectionService.shared.presentPaywallIfAtOpenLimit() {
                        pendingConnection = nil
                        return
                    }
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
        if let recent = notebooks.first, recent.title == "Untitled Notebook", recent.descriptionText.isEmpty {
            let id = recent.id
            let blockDescriptor = FetchDescriptor<NotebookBlock>(
                predicate: #Predicate { $0.notebookId == id }
            )
            let blockCount = (try? modelContext.fetchCount(blockDescriptor)) ?? 0
            if blockCount == 0 {
                handleNotebookOpen(recent)
                return
            }
        }
        if ConnectionService.shared.presentPaywallIfAtOpenLimit() { return }
        let notebook = Notebook()
        modelContext.insert(notebook)
        handleNotebookOpen(notebook)
        AnalyticsService.shared.trackNotebookCreated()
    }

    private func handleNotebookOpen(_ notebook: Notebook) {
        let alreadyOpen = SidebarItemRegistry.shared.items.contains { item in
            if case .notebook(let id, _) = item { return id == notebook.id }
            return false
        }
        if !alreadyOpen, ConnectionService.shared.presentPaywallIfAtOpenLimit() { return }
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
            if ConnectionService.shared.presentPaywallIfAtOpenLimit() { return }
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

private struct FreePlanBadge: View {
    var body: some View {
        Button {
            Paywall.present()
        } label: {
            HStack(spacing: 8) {
                Text("Free")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 2)
                    .overlay(
                        Capsule()
                            .strokeBorder(Color(.separatorColor), lineWidth: 1)
                    )

                Text("Upgrade")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Color.primaryButton)
            }
        }
        .buttonStyle(.plain)
        .customHelp("You're on the Free plan. Upgrade to Pluk Pro for unlimited connections and more.")
    }
}
