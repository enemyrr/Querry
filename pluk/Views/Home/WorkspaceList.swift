//
//  WorkspaceList.swift
//  Pluk
//

import AppKit
import SwiftData
import SwiftUI

struct WorkspaceList: View {
    let items: [WorkspaceItem]
    let onOpenConnection: (Connection) -> Void
    let onOpenNotebook: (Notebook) -> Void
    let onCreateConnection: () -> Void
    let onCreateNotebook: () -> Void

    @Environment(\.modelContext) private var modelContext
    @State private var notebookToDelete: Notebook?
    @State private var showDeleteNotebook = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            listHeader

            if items.isEmpty {
                emptyState
            } else {
                listContent
            }
        }
        .confirmationDialog(
            "Delete Notebook",
            isPresented: $showDeleteNotebook,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                if let notebook = notebookToDelete {
                    modelContext.delete(notebook)
                    notebookToDelete = nil
                }
            }
            Button("Cancel", role: .cancel) {
                notebookToDelete = nil
            }
        } message: {
            Text("Are you sure you want to delete this notebook? This action cannot be undone.")
        }
        .dialogSeverity(.critical)
    }

    private var listHeader: some View {
        HStack(alignment: .center) {
            Text("All Items")
                .font(.system(size: 14, weight: .semibold))

            Spacer()

            Menu {
                Button(action: onCreateNotebook) {
                    Label("New Notebook", systemImage: "doc.text")
                }

                Button(action: onCreateConnection) {
                    Label("New Connection", systemImage: "server.rack")
                }
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(ActionButtonStyle())
            .menuIndicator(.hidden)
        }
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label("No Items", systemImage: "tray")
                .font(.title2)
        } description: {
            Text("Create a notebook or connect a database to get started.")
        }
        .frame(maxWidth: 400)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }

    private var listContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Name")

                Spacer()

                Text("Kind")
                    .frame(width: 100, alignment: .leading)

                Text("Last Opened")
                    .frame(width: 120, alignment: .leading)

                Text("Created")
                    .frame(width: 120, alignment: .leading)
            }
            .foregroundStyle(.secondary)
            .font(.system(size: 12))
            .padding(.vertical, 8)

            Divider().padding(.bottom, 6)

            LazyVStack(spacing: 4) {
                ForEach(items) { item in
                    switch item {
                    case .connection(let connection):
                        WorkspaceConnectionRow(
                            connection: connection,
                            onOpen: onOpenConnection
                        )
                    case .notebook(let notebook):
                        WorkspaceNotebookRow(
                            notebook: notebook,
                            onOpen: onOpenNotebook,
                            onDelete: { nb in
                                notebookToDelete = nb
                                showDeleteNotebook = true
                            }
                        )
                    }
                }
            }
        }
    }
}

private func relativeTimeText(for date: Date) -> String {
    Date().timeIntervalSince(date) < 60
        ? "a moment ago"
        : date.formatted(.relative(presentation: .named))
}

struct WorkspaceNotebookRow: View {
    let notebook: Notebook
    let onOpen: (Notebook) -> Void
    let onDelete: (Notebook) -> Void
    @State private var isHovering = false

    var body: some View {
        HStack {
            HStack(spacing: 12) {
                NotebookIcon()

                VStack(alignment: .leading) {
                    HStack(spacing: 6) {
                        Text(notebook.title)
                            .foregroundStyle(.primary)

                        NotebookStatusTag(status: notebook.status)
                    }

                    if !notebook.descriptionText.isEmpty {
                        Text(notebook.descriptionText)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
            }

            Spacer()

            Text("Notebook")
                .foregroundStyle(.secondary)
                .frame(width: 100, alignment: .leading)

            Text(relativeTimeText(for: notebook.updatedAt))
                .foregroundStyle(.secondary)
                .frame(width: 120, alignment: .leading)

            Text(notebook.createdAt.formatted(date: .abbreviated, time: .omitted))
                .foregroundStyle(.secondary)
                .frame(width: 120, alignment: .leading)
        }
        .padding(.vertical, 8)
        .contentShape(.rect)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovering = hovering
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(isHovering ? Color(.separatorColor).opacity(0.5) : .clear)
        )
        .simultaneousGesture(
            TapGesture(count: 2)
                .onEnded {
                    onOpen(notebook)
                }
        )
        .contextMenu {
            Button {
                onOpen(notebook)
            } label: {
                Label("Open", systemImage: "arrow.up.forward.square")
            }

            Divider()

            Button(role: .destructive) {
                onDelete(notebook)
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }
}

struct WorkspaceConnectionRow: View {
    let connection: Connection
    let onOpen: (Connection) -> Void

    @Environment(\.modelContext) private var modelContext
    @State private var isHovering = false
    @State private var showEditSheet = false
    @State private var showDeleteConfirmation = false

    var body: some View {
        HStack {
            HStack(spacing: 12) {
                DatabaseTypeIcon(databaseType: connection.databaseType)

                VStack(alignment: .leading) {
                    HStack(spacing: 6) {
                        Text(connection.name)
                            .foregroundStyle(.primary)

                        if let env = connection.environment {
                            EnvironmentTag(environment: env)
                        }
                    }

                    if connection.databaseType == .convex, let hostname = connection.hostname {
                        Text("ID: \(hostname)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    } else if let displayUrl = connection.displayUrl {
                        Text(displayUrl)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
            }

            Spacer()

            Text("Connection")
                .foregroundStyle(.secondary)
                .frame(width: 100, alignment: .leading)

            Text(relativeTimeText(for: connection.lastOpenedAt))
                .foregroundStyle(.secondary)
                .frame(width: 120, alignment: .leading)

            Text(connection.createdAt.formatted(date: .abbreviated, time: .omitted))
                .foregroundStyle(.secondary)
                .frame(width: 120, alignment: .leading)
        }
        .padding(.vertical, 8)
        .contentShape(.rect)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovering = hovering
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(isHovering ? Color(.separatorColor).opacity(0.5) : .clear)
        )
        .simultaneousGesture(
            TapGesture(count: 2)
                .onEnded {
                    onOpen(connection)
                    connection.lastOpenedAt = Date()
                }
        )
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
                Label("Connect", systemImage: "arrow.up.forward.square")
            }

            Divider()

            Button {
                showEditSheet = true
            } label: {
                Label("Edit", systemImage: "square.and.pencil")
            }

            Divider()

            Button {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(connection.copyableConnectionUri, forType: .string)
            } label: {
                Label("Copy connection string", systemImage: "doc.on.doc")
            }

            Divider()

            Button(role: .destructive) {
                showDeleteConfirmation = true
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
        .confirmationDialog(
            "Delete Connection",
            isPresented: $showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                let databaseType = connection.databaseType

                QueryHistoryService.deleteHistoryForConnection(
                    modelContext: modelContext,
                    connectionKeychainId: connection.keychainId
                )
                connection.cleanupKeychain()
                modelContext.delete(connection)

                Task { @MainActor in
                    AnalyticsService.shared.trackConnectionDeleted(databaseType: databaseType)

                    let remainingConnections = (try? modelContext.fetch(FetchDescriptor<Connection>())) ?? []
                    let databaseTypes = Array(Set(remainingConnections.map { $0.databaseType.rawValue }))
                    AnalyticsService.shared.updateConnectionSuperProperties(
                        totalConnections: remainingConnections.count,
                        databaseTypes: databaseTypes
                    )
                }
            }

            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Are you sure you want to delete this connection? This action cannot be undone.")
        }
        .dialogSeverity(.critical)
    }
}
