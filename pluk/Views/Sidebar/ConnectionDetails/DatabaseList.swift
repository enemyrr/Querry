//
//  SiderbarDatabaseList.swift
//  Collection
//
//  Created by Fauzaan on 1/18/25.
//

import SwiftUI
import MongoKitten

struct DatabaseList: View {
    var viewModel: SidebarViewModel
    
    var body: some View {
        VStack(spacing: 0) {
            ZStack(alignment: .top) {
                connectionContent
            }
        }
    }
    
    private var connectionContent: some View {
        VStack(spacing: 0) {
            if let activeConnection = viewModel.activeConnection {
                if let selectedDb = activeConnection.database {
                    let filteredCollections = (activeConnection.collections[selectedDb.name] ?? [])
                        .filter {
                            viewModel.searchText.isEmpty ||
                            $0.name.localizedCaseInsensitiveContains(viewModel.searchText)
                        }
                    
                    CollectionsSection(
                            instance: activeConnection,
                            collections: filteredCollections
                        ).padding(.horizontal, 16)
                } else {
                    if activeConnection.connectionStatus != .error {
                        ProgressView()
                            .controlSize(.small)
                            .padding()
                    }
                }
            }
            
            Spacer()
        }
        .alert("Connection Error",
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
    }
}

struct DatabasesSection: View {
    var instance: ConnectionInstance
    
    var body: some View {
        DisclosureGroup("Databases") {
            ForEach(instance.databases, id: \.name) { database in
                Button(action: {
                    instance.database = database
                }) {
                    HStack {
                        Image(systemName: "folder.fill")
                            .foregroundStyle(.secondary)
                        Text(database.name)
                        Spacer()
                    }
                }
                .buttonStyle(SidebarButtonStyle(
                    isActive: instance.database?.name == database.name
                ))
            }
        }
    }
}

// MARK: - Updated CollectionsSection with Inline Rename
struct CollectionsSection: View {
    var instance: ConnectionInstance
    let collections: [MongoCollection]
    
    // State for inline rename functionality
    @State private var renamingCollection: String? = nil
    @State private var renameText: String = ""
    @State private var isRenaming = false
    @FocusState private var isRenameFieldFocused: Bool
    @Environment(\.colorScheme) var colorScheme
    
    private var hasTextChanged: Bool {
        guard let renamingCollectionName = renamingCollection else { return false }
        return renameText.trimmingCharacters(in: .whitespacesAndNewlines) != renamingCollectionName
    }
    
    var body: some View {
        ForEach(collections, id: \.name) { collection in
            let isActive = instance.selectedTab?.name == collection.name
            let isCurrentlyRenaming = renamingCollection == collection.name
            
            if isCurrentlyRenaming {
                inlineRenameView(for: collection)
            } else {
                normalCollectionButton(for: collection, isActive: isActive)
            }
        }
    }
    
    // MARK: - Normal Collection Button
    @ViewBuilder
    private func normalCollectionButton(for collection: MongoCollection, isActive: Bool) -> some View {
        Button(action: {
            instance.createNewTab(name: collection.name)
        }) {
            HStack {
                Image(systemName: "folder")
                    .opacity(0.7)
                    .animation(.easeInOut(duration: 0.3), value: renamingCollection)
                Text(collection.name)
                Spacer()
            }
        }
        .buttonStyle(SidebarButtonStyle(isActive: isActive))
        .contextMenu {
            contextMenuContent(for: collection, isActive: isActive)
        }
    }
    
    // MARK: - Inline Rename View
    @ViewBuilder
    private func inlineRenameView(for collection: MongoCollection) -> some View {
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
                    confirmRename(for: collection)
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
                        confirmRename(for: collection)
                    }) {
                        Text("Save").font(.system(size: 12))
                    }
                    .buttonStyle(RenameSaveButtonStyle(backgroundColor:  Color(red: 248/255, green: 148/255, blue: 99/255)))
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
                .fill((colorScheme == .dark ? Color.white : Color.black).opacity(0.1))
        )
        .onKeyPress(.escape) {
            cancelRename()
            return .handled
        }
    }
    
    // MARK: - Context Menu Content
    @ViewBuilder
    private func contextMenuContent(for collection: MongoCollection, isActive: Bool) -> some View {
        Button {
            Task {
                instance.createNewTab(name: collection.name)
            }
        } label: {
            Label("Open in New Tab", systemImage: "plus.square")
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
            Label("Rename", systemImage: "pencil")
                .frame(minWidth: 150, alignment: .leading)
        }

        Button(role: .destructive) {
            // Delete collection action
        } label: {
            Label("Delete", systemImage: "trash")
                .frame(minWidth: 150, alignment: .leading)
        }
    }
    
    // MARK: - Rename Logic
    private func startRename(for collection: MongoCollection) {
        renamingCollection = collection.name
        renameText = collection.name
        isRenaming = false
    }
    
    private func confirmRename(for collection: MongoCollection) {
        let trimmedName = renameText.trimmingCharacters(in: .whitespacesAndNewlines)
        
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
        
        // Validate MongoDB collection name
        if let _ = validateCollectionName(trimmedName) {
            NSSound.beep()
            return
        }
        
        // Perform rename
        isRenaming = true
        Task {
            await performRename(from: collection.name, to: trimmedName)
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
    private func performRename(from oldName: String, to newName: String) async {
        do {
            try await instance.renameCollection(from: oldName, to: newName)
            await instance.loadCollectionsForCurrentDatabase()
            
            withAnimation(.easeInOut(duration: 0.2)) {
                renamingCollection = nil
                isRenaming = false
                isRenameFieldFocused = false
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
               renameText = ""
            }
            
        } catch {
            // Handle error - could show error state
            NSSound.beep()
            isRenaming = false
            
            // Optionally show error in UI
            print("Rename failed: \(error.localizedDescription)")
        }
    }
    
    private func validateCollectionName(_ name: String) -> String? {
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
}
