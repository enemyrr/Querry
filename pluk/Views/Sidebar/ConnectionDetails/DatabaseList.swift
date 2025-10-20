//
//  SiderbarDatabaseList.swift
//  Collection
//
//  Created by Fauzaan on 1/18/25.
//

import MongoKitten
import SwiftUI

struct DatabaseList: View {
    @Environment(ConnectionInstance.self) private var instance
    var viewModel: SidebarViewModel
    @Binding var isLoadingCollections: Bool

    @State private var loadError: Error?
    @State private var showDatabaseSelector: Bool = false

    // Computed property for filtered collections
    private var filteredCollections: [any CollectionWrapper]? {
        guard
            let connectedDatabase = viewModel.activeConnection?
                .connectedDatabase
        else {
            return nil
        }

        var collections = instance.collections[connectedDatabase.name] ?? []

        // Apply search filter
        if !viewModel.searchText.isEmpty {
            collections = collections.filter { collection in
                collection.name.localizedCaseInsensitiveContains(
                    viewModel.searchText
                )
            }
        }

        // Apply sorting
        return collections.sorted { first, second in
            return first.name.localizedCaseInsensitiveCompare(second.name) == .orderedAscending
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            ZStack(alignment: .top) {
                connectionContent
            }
        }
    }

    private var connectionContent: some View {
        VStack(spacing: 0) {
            if instance.connectionStatus == .error {
                // Show error state
                ContentUnavailableView(
                    "Connection Failed",
                    systemImage: "wifi.exclamationmark",
                    description: Text("Unable to connect to the database.")
                )
            } else {
                if let filteredCollections = filteredCollections {
                    CollectionsSection(
                        collections: filteredCollections
                    )

                    if !viewModel.searchText.isEmpty
                        && filteredCollections.isEmpty
                    {
                        VStack(spacing: 12) {
                            Image(systemName: "folder.badge.questionmark")
                                .font(.system(size: 32))
                                .foregroundColor(.secondary.opacity(0.5))
                            
                            Text("No Tables")
                                .font(.system(size: 13))
                                .foregroundColor(.secondary.opacity(0.7))
                        }
                        .padding(.top, 20)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
            }

            Spacer()
        }
        .sheet(isPresented: $showDatabaseSelector) {
            DatabaseSelectorModal(
                databaseService: instance.databaseService,
                onSelection: { database in
                    Task {
                        await updateConnection(with: database)
                    }
                },
                onCreateNew: {
                    debugLog("Create new database")
                    showDatabaseSelector = false
                }
            )
        }
        .onChange(of: instance.connectionStatus) { oldStatus, newStatus in
            if newStatus == .connected && oldStatus != .connected {
                Task {
                    await loadCollectionsForCurrentDatabase()
                }
            }
        }
        .alert(
            "Connection Error",
            isPresented: Binding(
                get: { viewModel.activeConnection?.lastError != nil },
                set: { _ in viewModel.activeConnection?.lastError = nil }
            ),
            presenting: viewModel.activeConnection?.lastError
        ) { _ in
            Button("Retry") {
                Task {
                    await viewModel.loadActiveConnection()
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: { error in
            Text(error.localizedDescription)
        }
        .alert(
            "Load Error",
            isPresented: Binding(
                get: { loadError != nil },
                set: { _ in loadError = nil }
            ),
            presenting: loadError
        ) { _ in
            Button("Retry") {
                Task {
                    await loadCollectionsForCurrentDatabase()
                }
            }
            Button("OK", role: .cancel) {}
        } message: { error in
            Text(error.localizedDescription)
        }
        
    }

    // MARK: - Private Methods
    @MainActor
    private func loadCollectionsForCurrentDatabase() async {
        isLoadingCollections = true
        loadError = nil

        do {
            try await instance.loadCollectionsForCurrentDatabase(schema: nil)
        } catch let error as DatabaseError where error.code == .databaseNotSelected {
            showDatabaseSelector = true
        } catch {
            loadError = error
            debugLog("Failed to load collections: \(error)")
        }

        isLoadingCollections = false
    }
    
    func updateConnection(with database: any DatabaseWrapper) async {
        isLoadingCollections = true
        do {
            try await instance.databaseService.switchActiveDatabase(to: database)
            try await instance.loadCollectionsForCurrentDatabase(schema: nil)
        } catch {
            debugLog("Failed to update connection: \(error)")
        }
        isLoadingCollections = false
    }
}

// MARK: - Updated CollectionsSection with Inline Rename
struct CollectionsSection: View {
    @Environment(ConnectionInstance.self) private var instance
    let collections: [any CollectionWrapper]

    @State private var showDeleteConfirmation = false
    @State private var collectionToDelete: (any CollectionWrapper)?
    @State private var renameError: Error?
    @State private var showRenameError = false
    @State private var deleteError: Error?
    @State private var showDeleteError = false

    private var hasTextChanged: Bool {
        guard let renamingCollectionName = renamingCollection else {
            return false
        }
        return renameText.trimmingCharacters(in: .whitespacesAndNewlines)
            != renamingCollectionName
    }
    
    private var deleteConfirmationTitle: String {
        switch instance.connection.databaseType {
        case .mongodb:
            return "Delete Collection"
        default:
            return "Delete Table"
        }
    }
    
    private var deleteConfirmationMessage: String {
        switch instance.connection.databaseType {
        case .mongodb:
            return "Are you sure you want to delete this collection? This action cannot be undone."
        default:
            return "Are you sure you want to delete this table? This action cannot be undone."
        }
    }

    var body: some View {
        ForEach(collections, id: \.name) { collection in
            let isActive = instance.selectedTab?.name == collection.name
            let isCurrentlyRenaming = renamingCollection == collection.name

            if isCurrentlyRenaming {
                inlineRenameView(for: collection, databaseSchema: collection.schema)
            } else {
                normalCollectionButton(for: collection, databaseSchema: collection.schema, isActive: isActive)
            }
        }
    }

    // MARK: - Normal Collection Button
    @ViewBuilder
    private func normalCollectionButton(
        for collection: any CollectionWrapper,
        databaseSchema: String? = nil,
        isActive: Bool
    ) -> some View {
        Button(action: {
            instance.createNewTab(name: collection.name, databaseSchema: databaseSchema)
        }) {
            HStack {
                databaseIcon(for: collection)
                    .font(.footnote)
                    .opacity(0.7)
                    .animation(
                        .easeInOut(duration: 0.3),
                        value: renamingCollection
                    )
                Text(collection.name)
                Spacer()
            }
        }
        .contentShape(Rectangle())
        .buttonStyle(SidebarButtonStyle(isActive: isActive))
        .contextMenu {
            contextMenuContent(for: collection, isActive: isActive)
        }
        .confirmationDialog(
            deleteConfirmationTitle,
            isPresented: $showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                if let collection = collectionToDelete {
                    Task {
                        await performDelete(collection: collection, databaseSchema: databaseSchema)
                    }
                }
            }

            Button("Cancel", role: .cancel) {
                collectionToDelete = nil
            }
        } message: {
            Text(deleteConfirmationMessage)
        }
        .dialogSeverity(.critical)
        .alert(
            "Rename Error",
            isPresented: $showRenameError,
            presenting: renameError
        ) { _ in
            Button("OK", role: .cancel) {}
        } message: { error in
            Text(error.localizedDescription)
        }
        .alert(
            "Delete Error",
            isPresented: $showDeleteError,
            presenting: deleteError
        ) { _ in
            Button("OK", role: .cancel) {}
        } message: { error in
            Text(error.localizedDescription)
        }
    }

    private func databaseIcon(for collection: any CollectionWrapper) -> some View {
        let iconName: String
        switch instance.connection.databaseType {
        case .mongodb:
            iconName = "folder"
        default:
            if collection.type == "view" {
                iconName = "eye.fill"
            } else {
                iconName = "table"
            }
        }
        
        return Image(systemName: iconName)
            .font(collection.type == "view" ? .footnote : .body)
    }

    // MARK: - Inline Rename View
    @State private var renamingCollection: String? = nil
    @State private var renameText: String = ""
    @State private var isRenaming = false
    @FocusState private var isRenameFieldFocused: Bool

    @ViewBuilder
    private func inlineRenameView(for collection: any CollectionWrapper, databaseSchema: String?)
        -> some View
    {
        HStack(spacing: 8) {
            Image(systemName: "pencil.line")
                .opacity(0.7)
                .foregroundColor(.secondary)
                .padding(.leading, 4)
                .padding(.leading, 2)

            TextField("Collection name", text: $renameText)
                .textFieldStyle(.plain)
                .focused($isRenameFieldFocused)
                .onSubmit {
                    confirmRename(for: collection, databaseSchema: databaseSchema)
                }
                .onAppear {
                    // Focus the text field when it appears
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        isRenameFieldFocused = true
                    }
                }

            // Action buttons
            HStack(spacing: 4) {
                if hasTextChanged {
                    // Save button when text has changed
                    Button(action: {
                        confirmRename(for: collection, databaseSchema: databaseSchema)
                    }) {
                        Text("Save").font(.system(size: 12))
                    }
                    .buttonStyle(
                        RenameSaveButtonStyle(
                            backgroundColor: Color(
                                red: 248 / 255,
                                green: 148 / 255,
                                blue: 99 / 255
                            )
                        )
                    )
                    .disabled(isRenaming)
                } else {
                    // Cancel button when no changes
                    Button(action: {
                        cancelRename()
                    }) {
                        Text("Cancel").font(.system(size: 12))
                    }
                    .buttonStyle(RenameCancelButtonStyle())
                    .disabled(isRenaming)
                }
            }
        }
        .padding(.leading, 8)
        .padding(.trailing, 5)
        .padding(.vertical, 5)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(.controlColor).opacity(0.3))
        )
        .onKeyPress(.escape) {
            cancelRename()
            return .handled
        }
    }

    // MARK: - Rename Logic
    private func startRename(for collection: any CollectionWrapper) {
        renamingCollection = collection.name
        renameText = collection.name
        isRenaming = false
    }

    private func confirmRename(for collection: any CollectionWrapper, databaseSchema: String?) {
        let trimmedName = renameText.trimmingCharacters(
            in: .whitespacesAndNewlines
        )

        // Validate
        guard !trimmedName.isEmpty else { return }
        guard trimmedName != collection.name else {
            cancelRename()
            return
        }

        // Check for duplicates
        if collections.contains(where: { $0.name == trimmedName }) {
            // Could show an error state or shake animation
            NSSound.beep()
            return
        }

        // Validate collection name based on database type
        let validationError: String?
        switch instance.connection.databaseType {
        case .mongodb:
            validationError = validateMongoDBCollectionName(trimmedName)
        default:
            validationError = validateSQLTableName(trimmedName)
        }
        
        if let error = validationError {
            // Store error and show alert
            renameError = DatabaseError.configurationError(error)
            showRenameError = true
            return
        }

        // Perform rename
        isRenaming = true
        Task {
            await performRename(databaseSchema: databaseSchema, from: collection.name, to: trimmedName)
        }
    }

    private func cancelRename() {
        withAnimation(.easeInOut(duration: 0.2)) {
            renamingCollection = nil
            isRenaming = false
            isRenameFieldFocused = false
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            renameText = ""
        }
    }

    @MainActor
    private func performRename(databaseSchema: String?, from oldName: String, to newName: String) async {
        do {
            try await instance.databaseService.renameCollection(databaseSchema: databaseSchema,  from: oldName, to: newName)
            try await instance.loadCollectionsForCurrentDatabase(schema: databaseSchema)

            withAnimation(.easeInOut(duration: 0.2)) {
                renamingCollection = nil
                isRenaming = false
                isRenameFieldFocused = false
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                renameText = ""
            }

        } catch {
            // Handle error - show popup alert
            isRenaming = false
            renameError = error
            showRenameError = true
            
            debugLog("Rename failed: \(error.localizedDescription)")
        }
    }

    @MainActor
    private func performDelete(collection: any CollectionWrapper, databaseSchema: String?) async {
        do {
            try await instance.databaseService.deleteCollection(named: collection.name, databaseSchema: databaseSchema)
            try await instance.loadCollectionsForCurrentDatabase(schema: databaseSchema)
            
            // Clear the collection to delete
            collectionToDelete = nil
            
        } catch {
            // Handle error - show popup alert
            deleteError = error
            showDeleteError = true
            collectionToDelete = nil
            
            debugLog("Delete failed: \(error.localizedDescription)")
        }
    }

    private func validateMongoDBCollectionName(_ name: String) -> String? {
        if name.isEmpty {
            return "Collection name cannot be empty"
        }

        if name.count > 120 {
            return "Collection name must be less than 120 characters"
        }

        if name.hasPrefix("system.") {
            return "Collection names cannot start with 'system.'"
        }

        let invalidCharacters = CharacterSet(charactersIn: "/\\. \"*<>:|?$")
        if name.rangeOfCharacter(from: invalidCharacters) != nil {
            return "Collection name contains invalid characters"
        }

        return nil
    }
    
    private func validateSQLTableName(_ name: String) -> String? {
        if name.isEmpty {
            return "Table name cannot be empty"
        }

        if name.count > 63 {
            return "Table name must be less than 64 characters"
        }

        // Check if starts with a digit (not allowed in most SQL databases)
        if let firstChar = name.first, firstChar.isNumber {
            return "Table name cannot start with a number"
        }

        // SQL identifiers should only contain letters, digits, and underscores
        let validCharacters = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "_"))
        for char in name.unicodeScalars {
            if !validCharacters.contains(char) {
                return "Table name can only contain letters, numbers, and underscores"
            }
        }

        // Check for SQL reserved keywords (common ones)
        let reservedKeywords = [
            "select", "insert", "update", "delete", "create", "drop", "alter",
            "table", "index", "view", "database", "schema", "user", "group",
            "order", "by", "where", "from", "join", "inner", "outer", "left",
            "right", "on", "as", "and", "or", "not", "null", "true", "false"
        ]
        
        if reservedKeywords.contains(name.lowercased()) {
            return "Table name cannot be a SQL reserved keyword"
        }

        return nil
    }

    // MARK: - Context Menu Content
    @ViewBuilder
    private func contextMenuContent(
        for collection: any CollectionWrapper,
        isActive: Bool
    ) -> some View {
        Button {
            Task {
                instance.createNewTab(name: collection.name)
            }
        } label: {
            Label("Open in New Tab", systemImage: "arrow.up.forward.square")
                .frame(minWidth: 150, alignment: .leading)
        }
        .disabled(isActive)

        Divider()

        Button {
            // Copy to pasteboard
            let pasteboard = NSPasteboard.general
            pasteboard.clearContents()
            pasteboard.setString(collection.name, forType: .string)
        } label: {
            Label("Copy name", systemImage: "doc.on.clipboard")
                .frame(minWidth: 150, alignment: .leading)
        }

        Divider()

        Button {
            startRename(for: collection)
        } label: {
            Label("Rename", systemImage: "square.and.pencil")
                .frame(minWidth: 150, alignment: .leading)
        }

        Button(role: .destructive) {
            collectionToDelete = collection
            showDeleteConfirmation = true
        } label: {
            Label("Delete", systemImage: "trash")
                .frame(minWidth: 150, alignment: .leading)
        }
    }
}
