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
    @State private var showCreateSchemaPopover = false
    @State private var showCreateDatabaseSheet = false
    @Binding var isLoadingCollections: Bool

    var body: some View {
        VStack {
            HStack {
                HStack(spacing: 0) {
                    if instance.databaseType == .convex {
                        ConvexHeaderView(
                            availableSchemas: availableSchemas,
                            selectedSchema: $selectedSchema,
                            onSchemaChange: handleSchemaSelection
                        )
                    } else {
                        TraditionalDatabaseHeaderView(
                            instance: instance,
                            availableSchemas: availableSchemas,
                            selectedDatabase: $selectedDatabase,
                            selectedSchema: $selectedSchema,
                            isSchemaHovering: $isSchemaHovering,
                            showCreateDatabasePopover: $showCreateDatabaseSheet,
                            showCreateSchemaPopover: $showCreateSchemaPopover,
                            onSchemaChange: handleSchemaSelection,
                            onDatabaseChange: handleDatabaseSelection,
                            onSchemaCreated: handleSchemaCreated,
                            truncatedText: truncatedText
                        )
                    }
                }
                
                Spacer()
                
                HStack(spacing: 8) {
                    if isLoadingCollections {
                        ProgressView()
                            .controlSize(.mini)
                            .padding(.trailing, 14)
                    }
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
        .onChange(of: instance.databaseService.currentSchema) { oldSchema, newSchema in
            Task {
                isLoadingCollections = true

                // Immediately clear collections when schema changes
                await MainActor.run {
                    if let databaseName = instance.connectedDatabase?.name {
                        instance.collections[databaseName] = []
                    }
                }

                try await instance.loadCollectionsForCurrentDatabase(schema: newSchema)
                isLoadingCollections = false
            }
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
                        // For Convex, default to "app", for others default to "public"
                        if instance.databaseType == .convex {
                            selectedSchema = schemas.contains("app") ? "app" : (schemas.first ?? "")
                        } else {
                            selectedSchema = schemas.contains("public") ? "public" : (schemas.first ?? "")
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
        case .postgres, .supabase, .convex, .mysql:
            let schemas = try await instance.databaseService.getInformationSchema()
            return schemas.map { $0.name }
        default:
            return []
        }
    }
    
    private func truncatedText(_ text: String, maxWidth: CGFloat) -> some View {
        let approximateCharWidth: CGFloat = 7.0 // Approximate character width for system font
        let maxChars = Int(maxWidth / approximateCharWidth)
        let truncatedString = text.count > maxChars ? String(text.prefix(maxChars - 3)) + "..." : text
        
        return Text("\(truncatedString)    ").tag(text)
    }
    
    private func handleSchemaSelection(_ schema: String) {
        instance.databaseService.setCurrentSchema(schema)
    }

    private func handleDatabaseSelection(_ databaseName: String) {
        // Don't do anything if selecting the already-connected database
        guard databaseName != instance.connectedDatabase?.name else { return }

        Task {
            if let instanceId = await ConnectionService.shared.openEnvironmentInNewTab(
                from: instance,
                databaseName: databaseName
            ) {
                await MainActor.run {
                    WindowController.switchToTab(.connection(instanceId))
                }
            }
        }
    }

    private func handleSchemaCreated(_ schemaName: String) {
        loadAvailableSchemas()
        selectedSchema = schemaName
        instance.databaseService.setCurrentSchema(schemaName)
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
            .foregroundColor(Color(.textColor))
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
                .fill(Color(colorScheme == .dark ? .black : .white).opacity(0.3))
                .stroke(.separator)
        }
        .shadow(color: Color(.sRGBLinear, white: 0, opacity: 0.05), radius: 2)
        .onTapGesture {
            isSearchFocused = true
        }
        .animation(.easeInOut(duration: 0.2), value: viewModel.searchText)
        .onAppear {
            Task {
                try? await Task.sleep(for: .milliseconds(100))
                isSearchFocused = true
            }
        }
        .onChange(of: viewModel.isSearchVisible) { _, isVisible in
            if isVisible {
                Task {
                    try? await Task.sleep(for: .milliseconds(100))
                    isSearchFocused = true
                }
            }
        }
    }
}

// MARK: - ConvexHeaderView
struct ConvexHeaderView: View {
    let availableSchemas: [String]
    @Binding var selectedSchema: String
    let onSchemaChange: (String) -> Void

    var body: some View {
        CustomComponentPicker(
            items: availableSchemas,
            selectedItem: $selectedSchema,
            onSelectionChange: onSchemaChange
        )
    }
}

// MARK: - Custom AppKit Component Picker
struct CustomComponentPicker: NSViewRepresentable {
    let items: [String]
    @Binding var selectedItem: String
    let onSelectionChange: (String) -> Void

    func makeNSView(context: Context) -> NSView {
        let popUpButton = NSPopUpButton()
        popUpButton.translatesAutoresizingMaskIntoConstraints = false
        popUpButton.pullsDown = false
        popUpButton.bezelStyle = .accessoryBar
        popUpButton.isBordered = true
        popUpButton.showsBorderOnlyWhileMouseInside = true

        // Set target and action
        popUpButton.target = context.coordinator
        popUpButton.action = #selector(Coordinator.selectionChanged(_:))

        Task { @MainActor in
            self.replaceDropdownArrow(in: popUpButton)
        }

        // Store reference for coordinator
        context.coordinator.popUpButton = popUpButton

        return popUpButton
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        guard let popUpButton = context.coordinator.popUpButton else { return }

        // Update items
        popUpButton.removeAllItems()
        popUpButton.addItems(withTitles: items)
        
        // Resize button based on selected text
        resizeButtonForSelectedText(popUpButton, selectedText: selectedItem)

        // Update selection
        if let index = items.firstIndex(of: selectedItem) {
            popUpButton.selectItem(at: index)
        } else {
            // Add default value and item
            popUpButton.addItems(withTitles: ["app"])
            popUpButton.selectItem(at: 0)
        }

        // Store references in coordinator
        context.coordinator.onSelectionChange = onSelectionChange
        context.coordinator.selectedItemBinding = $selectedItem
    }

    private func resizeButtonForSelectedText(_ button: NSPopUpButton, selectedText: String) {
        // Measure the text directly
        let font = button.font ?? NSFont.systemFont(ofSize: 13)
        let textSize = (selectedText as NSString).size(withAttributes: [.font: font])

        // Add padding for button chrome and dropdown arrow
        let padding: CGFloat = 36 // Space for borders and dropdown arrow
        let minWidth: CGFloat = 60
        let calculatedWidth = max(minWidth, textSize.width + padding)

        // Update width constraint
        if let existingConstraint = button.constraints.first(where: { $0.firstAttribute == .width }) {
            existingConstraint.constant = calculatedWidth
        } else {
            button.widthAnchor.constraint(equalToConstant: calculatedWidth).isActive = true
        }
    }

    private func replaceDropdownArrow(in popUpButton: NSPopUpButton) {
        // Recursively search for NSImageView containing the dropdown arrow
        findAndReplaceArrowImage(in: popUpButton)
    }

    private func findAndReplaceArrowImage(in view: NSView) {
        for subview in view.subviews {
            let className = NSStringFromClass(type(of: subview))

            if className == "NSPopUpIndicatorView" {
                // Hide the original indicator
                subview.isHidden = true

                // Add our custom arrow
                addCustomArrow(to: view)
                return
            }

            // Continue searching in subviews
            findAndReplaceArrowImage(in: subview)
        }
    }

    private func addCustomArrow(to popUpButton: NSView) {
        // Create custom arrow image at 10pt
        guard let customArrow = NSImage(systemSymbolName: "chevron.up.chevron.down", accessibilityDescription: nil) else { return }

        let config = NSImage.SymbolConfiguration(pointSize: 10, weight: .regular)
        guard let scaledArrow = customArrow.withSymbolConfiguration(config) else { return }
        scaledArrow.isTemplate = true

        // Create image view for our custom arrow
        let customImageView = NSImageView(image: scaledArrow)
        customImageView.translatesAutoresizingMaskIntoConstraints = false
        customImageView.wantsLayer = true

        // Add to the popup button
        popUpButton.addSubview(customImageView)

        // Position it on the right side like the original indicator
        NSLayoutConstraint.activate([
            customImageView.trailingAnchor.constraint(equalTo: popUpButton.trailingAnchor, constant: -2),
            customImageView.centerYAnchor.constraint(equalTo: popUpButton.centerYAnchor, constant: 1),
            customImageView.widthAnchor.constraint(equalToConstant: 12),
            customImageView.heightAnchor.constraint(equalToConstant: 12)
        ])
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    class Coordinator: NSObject {
        var onSelectionChange: ((String) -> Void)?
        var selectedItemBinding: Binding<String>?
        weak var popUpButton: NSPopUpButton?

        @objc func selectionChanged(_ sender: NSPopUpButton) {
            guard let selectedTitle = sender.selectedItem?.title else { return }

            // Update the SwiftUI binding
            selectedItemBinding?.wrappedValue = selectedTitle

            // Also call the callback
            onSelectionChange?(selectedTitle)
        }
    }
}

// MARK: - TraditionalDatabaseHeaderView
struct TraditionalDatabaseHeaderView<TruncatedTextView: View>: View {
    let instance: ConnectionInstance
    let availableSchemas: [String]
    @Binding var selectedDatabase: String
    @Binding var selectedSchema: String
    @Binding var isSchemaHovering: Bool
    @Binding var showCreateDatabasePopover: Bool
    @Binding var showCreateSchemaPopover: Bool
    let onSchemaChange: (String) -> Void
    let onDatabaseChange: (String) -> Void
    let onSchemaCreated: (String) -> Void
    let truncatedText: (String, CGFloat) -> TruncatedTextView

    private var supportsCreateDatabase: Bool {
        guard let databaseType = instance.databaseType else { return false }
        switch databaseType {
        case .postgres, .mysql, .mongodb, .supabase:
            return true
        case .sqlite, .convex:
            return false
        }
    }

    var body: some View {
        if !availableSchemas.isEmpty {
            if let database = instance.connectedDatabase?.name {
                MinimalDropdown(selectedValue: database, chevron: "chevron.right") {
                    Picker("", selection: Binding(
                        get: { database },
                        set: { newValue in
                            if newValue != database {
                                onDatabaseChange(newValue)
                            }
                        }
                    )) {
                        ForEach(instance.databases, id: \.name) { db in
                            Text(db.name).tag(db.name)
                        }
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()

                    if supportsCreateDatabase {
                        Divider()

                        Button("New Database...") {
                            showCreateDatabasePopover = true
                        }
                    }
                }
                .popover(isPresented: $showCreateDatabasePopover) {
                    CreateDatabaseForm()
                        .environment(instance)
                }
            } else {
                HStack {}
                    .padding(12)
            }

            MinimalDropdown(selectedValue: selectedSchema, chevron: nil) {
                Picker("", selection: Binding(
                    get: { selectedSchema },
                    set: { newValue in
                        selectedSchema = newValue
                        onSchemaChange(newValue)
                    }
                )) {
                    ForEach(availableSchemas, id: \.self) { schema in
                        Text(schema).tag(schema)
                    }
                }
                .pickerStyle(.inline)
                .labelsHidden()

                Divider()

                Button("New Schema...") {
                    showCreateSchemaPopover = true
                }
            }
            .popover(isPresented: $showCreateSchemaPopover) {
                CreateSchemaForm(onCreated: onSchemaCreated)
                    .environment(instance)
            }
            .onHover { hovering in
                withAnimation(.easeOut(duration: 0.05)) {
                    isSchemaHovering = hovering
                }
            }
        } else {
            if let database = instance.connectedDatabase?.name {
                MinimalDropdown(selectedValue: database) {
                    Picker("", selection: Binding(
                        get: { database },
                        set: { newValue in
                            if newValue != database {
                                onDatabaseChange(newValue)
                            }
                        }
                    )) {
                        ForEach(instance.databases, id: \.name) { db in
                            Text(db.name).tag(db.name)
                        }
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()

                    if supportsCreateDatabase {
                        Divider()

                        Button("New Database...") {
                            showCreateDatabasePopover = true
                        }
                    }
                }
                .popover(isPresented: $showCreateDatabasePopover) {
                    CreateDatabaseForm()
                        .environment(instance)
                }
            } else {
                HStack {}
                    .padding(12)
            }
        }
    }
}

// MARK: - MinimalDropdown
struct MinimalDropdown<MenuContent: View>: View {
    let selectedValue: String
    var chevron: String? = "chevron.down"
    @ViewBuilder let menuContent: () -> MenuContent
    @State private var isHovered = false

    var body: some View {
        Menu {
            menuContent()
        } label: {
            HStack(spacing: 3) {
                Text(selectedValue)
                    .font(.system(size: 12))
                    .foregroundStyle(.primary)

                if let chevron {
                    Image(systemName: chevron)
                        .padding(.top, 1)
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(.primary)
                }
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(isHovered ? Color(.separatorColor).opacity(0.5) : Color.clear)
            )
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovered = hovering
        }
    }
}
