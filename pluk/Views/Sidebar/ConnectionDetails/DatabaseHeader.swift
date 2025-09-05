//
//  DatabaseHeader.swift
//  Collection
//
//  Created by Fauzaan on 3/23/25.
//

import SwiftUI
import MongoKitten

// MARK: - Database List
struct DatabaseHeader: View {
    @Environment(ConnectionInstance.self) private var instance
    var viewModel: SidebarViewModel
    @Environment(\.colorScheme) var colorScheme
    @State private var isDatabaseHovering = false
    @State private var isSchemaHovering = false
    @State private var availableSchemas: [String] = []
    @State private var selectedSchema: String = ""
    @State private var selectedDatabase: String = ""
    @State private var isLoadingSchemas: Bool = false
    @State private var showNotImplementedAlert = false
    
    var body: some View {
        VStack {
            
            HStack {
                HStack(spacing: 0) {
                    if !availableSchemas.isEmpty {
                        if let database = instance.connectedDatabase?.name {
                            Picker("Database", selection: $selectedDatabase) {
                                ForEach([database], id: \.self) { schema in
                                    Text("\(schema)    ").tag(schema)
                                }
                            }
                            .buttonStyle(.accessoryBar)
                            .pickerStyle(.menu)
                            .labelsHidden()
                            .hoverMenuIndicator(showNormalIcon: true)
                        } else {
                            HStack {}
                            .padding(12)
                        }
                        
                        Picker("Schema", selection: $selectedSchema) {
                            ForEach(availableSchemas, id: \.self) { schema in
                                Text("\(schema)    ").tag(schema)
                            }
                            
                            Divider()
                            // Second group (nested menu)
                            Text("New Schema...").tag("__NEW_SCHEMA__")
                        }
                        .buttonStyle(.accessoryBar)
                        .pickerStyle(.menu)
                        .labelsHidden()
                        .hoverMenuIndicator(showNormalIcon: false)
                        .onChange(of: selectedSchema) { _, newValue in
                            handleSchemaSelection(newValue)
                        }
                        .onHover { hovering in
                            withAnimation(.easeOut(duration: 0.05)) {
                                isSchemaHovering = hovering
                            }
                        }
                    } else {
                        if let database = instance.connectedDatabase?.name {
                            Picker("Database", selection: $selectedDatabase) {
                                ForEach([database], id: \.self) { schema in
                                    Text("\(schema)    ").tag(schema)
                                }
                            }
                            .buttonStyle(.accessoryBar)
                            .pickerStyle(.menu)
                            .labelsHidden()
                            .hoverMenuIndicator(normalIcon: "chevron.up.chevron.down", showNormalIcon: true)
                        } else {
                            HStack {}
                            .padding(12)
                        }
                    }
                }
                
                Spacer()
                
                HStack(spacing: 4) {
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
                    .customHelp("Find Tables", position: .left, shortcut: KeyboardShortcut(
                        modifiers: [KeyboardModifier.command, KeyboardModifier.shift],
                        key: "F"
                    ))
                    
                    CreateCollection(
                        viewModel: viewModel
                    )
                }
            }
            
        }
        .onAppear {
            selectedDatabase = instance.connectedDatabase?.name ?? ""
            loadAvailableSchemas()
        }
        .onChange(of: instance.connectionStatus) { _, _ in
            selectedDatabase = instance.connectedDatabase?.name ?? ""
            loadAvailableSchemas()
        }
        .onChange(of: instance.connectedDatabase?.name) { oldName, newName in
            selectedDatabase = newName ?? ""
            loadAvailableSchemas()
        }
        .onChange(of: instance.databaseService.currentSchema) { _, newSchema in
            Task {
                try await instance.loadCollectionsForCurrentDatabase(schema: newSchema)
            }
        }
        .alert("Coming Soon", isPresented: $showNotImplementedAlert) {
            Button("OK") { }
        } message: {
            Text("Creating new schema is coming soon")
        }
    }
    
    private func loadAvailableSchemas() {
        Task {
            await MainActor.run {
                isLoadingSchemas = true
            }
            
            do {
                let schemas = try await fetchSchemas()
                await MainActor.run {
                    availableSchemas = schemas
                    if selectedSchema.isEmpty || !schemas.contains(selectedSchema) {
                        selectedSchema = schemas.contains("public") ? "public" : (schemas.first ?? "")
                        if !selectedSchema.isEmpty {
                            handleSchemaSelection(selectedSchema)
                        }
                    }
                    isLoadingSchemas = false
                }
            } catch {
                debugLog("Failed to load schemas: \(error)")
            }
        }
    }
    
    private func fetchSchemas() async throws -> [String] {
        guard let databaseType = instance.databaseType else {
            return []
        }
        
        switch databaseType {
        case .postgres:
            let schemas = try await instance.databaseService.getInformationSchema()
            return schemas.map { $0.name }
        case .mysql:
            let schemas = try await instance.databaseService.getInformationSchema()
            return schemas.map { $0.name }
        default:
            return []
        }
    }
    
    private func handleSchemaSelection(_ schema: String) {
        if schema == "__NEW_SCHEMA__" {
            showNotImplementedAlert = true
            // Reset selection to previous valid schema
            if let currentSchema = instance.databaseService.currentSchema, 
               availableSchemas.contains(currentSchema) {
                selectedSchema = currentSchema
            } else {
                selectedSchema = availableSchemas.contains("public") ? "public" : (availableSchemas.first ?? "")
            }
        } else {
            instance.databaseService.setCurrentSchema(schema)
        }
    }
}

// MARK: - DatabaseSchemaItem
struct DatabaseSchemaItem: View {
    let text: String
    let showChevronRight: Bool
    let isHovering: Bool
    let onTap: () -> Void
    @Environment(\.colorScheme) var colorScheme
    
    init(text: String, showChevronRight: Bool, isHovering: Bool = false, onTap: @escaping () -> Void) {
        self.text = text
        self.showChevronRight = showChevronRight
        self.isHovering = isHovering
        self.onTap = onTap
    }
    
    var body: some View {
        HStack(spacing: 4) {
            Text(text)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.secondary)
                .lineLimit(1)
            
            if showChevronRight {
                Image(systemName: "chevron.right")
                    .font(.footnote)
                    .foregroundColor(.secondary)
            } else if isHovering {
                Image(systemName: "chevron.compact.up.chevron.compact.down")
                    .font(.footnote)
                    .foregroundColor(.secondary)
                    .opacity(0.7)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(
                    isHovering && !showChevronRight
                    ? (colorScheme == .dark ? Color.black : Color.white).opacity(0.2)
                    : Color.clear
                )
        )
    }
}


// MARK: - SearchInput
struct SearchInput: View {
    @Environment(\.colorScheme) var colorScheme
    var viewModel: SidebarViewModel
    @State private var localSearchText: String = ""
    @FocusState private var isSearchFocused: Bool
    
    var body: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.gray)
                .font(.system(size: 14))
            
            TextField("Search", text: Binding(
                get: { viewModel.searchText },
                set: { viewModel.searchText = $0 }
            ))
            .focused($isSearchFocused)
            .textFieldStyle(.plain)
            .font(.system(size: 14))
            .foregroundColor(Color(.controlColor))
            .onExitCommand {
                if viewModel.searchText.isEmpty {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        viewModel.isSearchVisible = false
                    }
                } else {
                    viewModel.searchText = ""
                }
            }
            
            if !viewModel.searchText.isEmpty {
                Button(action: { viewModel.searchText = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.gray)
                        .font(.system(size: 12))
                }
                .buttonStyle(.plain)
                .onHover { hovering in
                    if hovering {
                        NSCursor.pointingHand.push()
                    } else {
                        NSCursor.pop()
                    }
                }
                .transition(.opacity)
                .padding(.horizontal, 2)
            }
            
        }
        .padding(.leading, 8)
        .padding(.trailing, 6)
        .padding(.vertical, 6)
        .background {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(colorScheme == .dark ? .black : .controlColor).opacity(0.2))
        }
        .onTapGesture {
            isSearchFocused = true
        }
        .animation(.easeInOut(duration: 0.2), value: viewModel.searchText)
    }
}
