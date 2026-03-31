//
//  WorkspaceList.swift
//  Pluk
//

import AppKit
import SwiftData
import SwiftUI

private enum WorkspaceSortField: CaseIterable {
    case name
    case lastViewed
    case dateCreated
    case dateUpdated

    var title: String {
        switch self {
        case .name: "Name"
        case .lastViewed: "Last Viewed"
        case .dateCreated: "Date Created"
        case .dateUpdated: "Date Updated"
        }
    }
}

private enum WorkspaceSortDirection {
    case ascending
    case descending

    var symbol: String {
        switch self {
        case .ascending: "↑"
        case .descending: "↓"
        }
    }

    mutating func toggle() {
        switch self {
        case .ascending:
            self = .descending
        case .descending:
            self = .ascending
        }
    }
}

struct WorkspaceList: View {
    let items: [WorkspaceItem]
    let onOpenConnection: (Connection) -> Void
    let onOpenNotebook: (Notebook) -> Void
    let onCreateConnection: () -> Void
    let onCreateNotebook: () -> Void

    @Environment(\.modelContext) private var modelContext
    @Environment(\.accessibilityReduceMotion) private var accessibilityReduceMotion
    @Environment(\.colorScheme) private var colorScheme
    @State private var notebookToDelete: Notebook?
    @State private var showDeleteNotebook = false
    @State private var searchText = ""
    @State private var isSearchVisible = false
    @State private var isSearchIconHovering = false
    @State private var selectedSortField: WorkspaceSortField = .dateCreated
    @State private var sortDirection: WorkspaceSortDirection = .descending
    @FocusState private var isSearchFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            listHeader

            if items.isEmpty {
                emptyState
            } else if displayedItems.isEmpty {
                noResultsState
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

    private var normalizedSearchText: String {
        searchText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var filteredItems: [WorkspaceItem] {
        guard !normalizedSearchText.isEmpty else { return items }

        return items.filter { item in
            item.searchTokens.localizedStandardContains(normalizedSearchText)
        }
    }

    private var displayedItems: [WorkspaceItem] {
        filteredItems.sorted(by: shouldPlaceBefore(_:_:))
    }

    private var listHeader: some View {
        HStack(alignment: .center, spacing: 4) {
            Spacer()

            createButtons
            sortMenu
            searchControl
        }
        .overlay {
            keyboardSearchShortcut
        }
    }

    private var keyboardSearchShortcut: some View {
        Button(action: showSearch) {
            Color.clear
                .frame(width: 0, height: 0)
        }
        .buttonStyle(.plain)
        .keyboardShortcut("f", modifiers: [.command])
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private var searchToggleAnimation: Animation {
        if accessibilityReduceMotion {
            return .linear(duration: 0.01)
        }

        return .easeOut(duration: 0.16)
    }

    private var searchControl: some View {
        HStack(spacing: isSearchVisible ? 6 : 0) {
            if isSearchVisible {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .frame(width: 20, height: 28)
                    .padding(.leading, -4)
                
                TextField("Search workspace", text: $searchText)
                    .textFieldStyle(.plain)
                    .focused($isSearchFocused)
                    .onExitCommand(perform: handleSearchExitCommand)

                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                        focusSearchField()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .padding(.trailing, 8)
                }
            } else {
                searchToggleButton
            }
        }
        .padding(.leading, isSearchVisible ? 8 : 0)
        .background(isSearchVisible ? searchControlFillColor : .clear)
        .clipShape(.rect(cornerRadius: 8))
        .frame(width: isSearchVisible ? 220 : 28, alignment: .trailing)
        .frame(height: 28)
        .animation(searchToggleAnimation, value: isSearchVisible)
        .onChange(of: isSearchVisible) { _, visible in
            if visible {
                focusSearchField()
            } else {
                isSearchFocused = false
            }
        }
    }

    private var searchToggleButton: some View {
        Button(action: showSearch) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
        }
        .buttonStyle(ActionButtonStyle())
    }

    private var searchControlFillColor: Color {
        colorScheme == .dark ? Color.white.opacity(0.04) : Color.black.opacity(0.02)
    }

    private var createButtons: some View {
        HStack(spacing: 6) {
            Button(action: onCreateNotebook) {
                Label("Notebook", systemImage: "plus")
            }

            Button(action: onCreateConnection) {
                Label("Connection", systemImage: "plus")
            }
        }
        .buttonStyle(WorkspaceCreateButtonStyle())
    }

    private var sortMenu: some View {
        Menu {
            Section("Sort By") {
                ForEach(WorkspaceSortField.allCases, id: \.title) { field in
                    Button {
                        handleSortSelection(field)
                    } label: {
                        HStack {
                            if selectedSortField == field {
                                Image(systemName: "checkmark")
                            }

                            Text(field.title)
                        }
                    }
                }
            }
        } label: {
            Image(systemName: "arrow.up.arrow.down")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
        }
        .buttonStyle(ActionButtonStyle())
        .menuIndicator(.hidden)
    }

    private var noResultsState: some View {
        ContentUnavailableView {
            Label("No Results", systemImage: "magnifyingglass")
                .font(.title2)
        } description: {
            Text("No workspace items match \"\(normalizedSearchText)\".")
        }
        .frame(maxWidth: 400)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
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
            .padding(.top, 2)
            .padding(.bottom, 10)

            Divider().padding(.bottom, 8)

            LazyVStack(spacing: 6) {
                ForEach(displayedItems) { item in
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
        .padding(.vertical, 4)
    }

    private func showSearch() {
        if !isSearchVisible {
            withAnimation(searchToggleAnimation) {
                isSearchVisible = true
            }
        }

        focusSearchField()
    }

    private func handleSearchExitCommand() {
        if searchText.isEmpty {
            collapseSearchField(clearSearchText: false)
            return
        }

        searchText = ""
    }

    private func collapseSearchField(clearSearchText: Bool = true) {
        if clearSearchText {
            searchText = ""
        }

        withAnimation(searchToggleAnimation) {
            isSearchVisible = false
        }
        isSearchFocused = false
    }

    private func focusSearchField() {
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(100))
            isSearchFocused = true
        }
    }

    private func handleSortSelection(_ field: WorkspaceSortField) {
        if selectedSortField == field {
            sortDirection.toggle()
            return
        }

        selectedSortField = field
        sortDirection = .descending
    }

    private func shouldPlaceBefore(_ lhs: WorkspaceItem, _ rhs: WorkspaceItem) -> Bool {
        switch selectedSortField {
        case .name:
            let nameComparison = lhs.name.localizedStandardCompare(rhs.name)
            if nameComparison == .orderedSame {
                return lhs.id < rhs.id
            }
            return sortDirection == .ascending
                ? nameComparison == .orderedAscending
                : nameComparison == .orderedDescending
        case .lastViewed:
            return shouldPlaceDateBefore(
                lhs.lastViewedAt,
                rhs.lastViewedAt,
                lhs: lhs,
                rhs: rhs
            )
        case .dateCreated:
            return shouldPlaceDateBefore(
                lhs.createdAt,
                rhs.createdAt,
                lhs: lhs,
                rhs: rhs
            )
        case .dateUpdated:
            return shouldPlaceDateBefore(
                lhs.updatedAt,
                rhs.updatedAt,
                lhs: lhs,
                rhs: rhs
            )
        }
    }

    private func shouldPlaceDateBefore(
        _ lhsDate: Date,
        _ rhsDate: Date,
        lhs: WorkspaceItem,
        rhs: WorkspaceItem
    ) -> Bool {
        if lhsDate == rhsDate {
            let nameComparison = lhs.name.localizedStandardCompare(rhs.name)
            if nameComparison == .orderedSame {
                return lhs.id < rhs.id
            }
            return nameComparison == .orderedAscending
        }

        return sortDirection == .ascending
            ? lhsDate < rhsDate
            : lhsDate > rhsDate
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
        .padding(.horizontal, 10)
        .padding(.vertical, 9)
        .contentShape(.rect)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovering = hovering
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(isHovering ? Color(.separatorColor).opacity(0.35) : .clear)
        )
        .padding(.horizontal, -10)
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
        .padding(.horizontal, 10)
        .padding(.vertical, 9)
        .contentShape(.rect)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovering = hovering
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(isHovering ? Color(.separatorColor).opacity(0.35) : .clear)
        )
        .padding(.horizontal, -10)
        .simultaneousGesture(
            TapGesture(count: 2)
                .onEnded {
                    onOpen(connection)
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
