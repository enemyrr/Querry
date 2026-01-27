//
//  DatabaseSelectorModal.swift
//  Pluk
//
//  Created by Fauzaan on 6/27/25.
//
import SwiftUI

struct DatabaseSelectorModal: View {
    let databaseService: DatabaseService
    let databaseType: DatabaseType?
    let onSelection: (DatabaseWrapper) -> Void
    let onCreateNew: () -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var databases: [DatabaseWrapper] = []
    @State private var searchText = ""
    @State private var hoveredDatabase: DatabaseWrapper? = nil
    @State private var isHoveringCreateButton = false
    @State private var isLoading = true
    @State private var loadError: Error? = nil
    @State private var showCreateDatabaseSheet = false

    private var supportsCreateDatabase: Bool {
        guard let databaseType else { return false }
        switch databaseType {
        case .postgres, .mysql, .mongodb, .supabase:
            return true
        case .sqlite, .convex:
            return false
        }
    }
    
    var filteredDatabases: [DatabaseWrapper] {
        if searchText.isEmpty {
            return databases
        }
        return databases.filter {
            $0.name.localizedCaseInsensitiveContains(searchText)
        }
    }
    
    var body: some View {
        ZStack(alignment: .topTrailing) {
            VStack(spacing: 0) {
                // Header Section
                VStack(spacing: 24) {
                    VStack(spacing: 8) {
                        Text("Select Database")
                            .font(.title)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                        
                        Text("Choose a database to continue or create a new one")
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, 16)
                    
                    // Modern Search Bar
                    HStack(spacing: 12) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.secondary)
                        
                        TextField("Search databases", text: $searchText)
                            .textFieldStyle(PlainTextFieldStyle())
                            .font(.system(size: 15))
                        
                        if !searchText.isEmpty {
                            Button(action: { searchText = "" }) {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 16))
                                    .foregroundColor(.secondary)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(.controlColor).opacity(0.1))
                    }
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(.separator, lineWidth: 1)
                    )
                    .clipShape(.rect(cornerRadius: 12))
                }
                .padding(.horizontal, 32)
                .padding(.top, 32)
                
                // Databases List
                if filteredDatabases.isEmpty {
                    // Empty State
                    VStack(spacing: 16) {
                        Spacer()
                        
                        Image(systemName: searchText.isEmpty ? "cylinder.split.1x2" : "magnifyingglass")
                            .font(.system(size: 48))
                            .foregroundColor(.secondary.opacity(0.6))
                        
                        VStack(spacing: 4) {
                            Text(searchText.isEmpty ? "No Databases Available" : "No Results Found")
                                .font(.system(size: 18, weight: .medium))
                                .foregroundColor(.primary)
                            
                            Text(searchText.isEmpty ?
                                 "Create your first database to get started" :
                                 "Try adjusting your search terms")
                                .font(.system(size: 14))
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 32)
                } else {
                    ScrollView {
                        LazyVStack(spacing: 8) {
                            ForEach(filteredDatabases, id: \.name) { database in
                                DatabaseCard(
                                    database: database,
                                    isHovered: hoveredDatabase?.name == database.name,
                                    onSelect: {
                                        onSelection(database)
                                        dismiss()
                                    }
                                )
                                .onHover { isHovered in
                                    withAnimation(.easeInOut(duration: 0.15)) {
                                        hoveredDatabase = isHovered ? database : nil
                                    }
                                }
                            }

                            if supportsCreateDatabase && searchText.isEmpty {
                                CreateDatabaseCard(
                                    isHovered: isHoveringCreateButton,
                                    onSelect: { showCreateDatabaseSheet = true }
                                )
                                .onHover { isHovered in
                                    withAnimation(.easeInOut(duration: 0.15)) {
                                        isHoveringCreateButton = isHovered
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, 32)
                        .padding(.vertical, 20)
                    }
                }
            }
        }
        .frame(width: 500, height: 650)
        .background(
            VisualEffectView(material: .hudWindow, blendingMode: .behindWindow)
                .ignoresSafeArea()
        )
        .task {
            await loadDatabases()
        }
        .interactiveDismissDisabled()
        .sheet(isPresented: $showCreateDatabaseSheet) {
            ZStack {
                VisualEffectView(material: .hudWindow, blendingMode: .behindWindow)
                    .ignoresSafeArea()
                CreateDatabaseForm(onCreated: { _ in
                    Task {
                        await loadDatabases()
                    }
                })
            }
        }
    }
    
    @MainActor
    private func loadDatabases() async {
        isLoading = true
        loadError = nil
        
        do {
            databases = try await databaseService.getDatabaseMetadata()
        } catch {
            loadError = error
            debugLog("Failed to load databases: \(error)")
        }
        
        isLoading = false
    }
}

// MARK: - Database Card
struct DatabaseCard: View {
    let database: DatabaseWrapper
    let isHovered: Bool
    let onSelect: () -> Void
    
    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 12) {
                // Database Icon
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(databaseIconBackground)
                        .frame(width: 40, height: 40)

                    Image(systemName: "cylinder.fill")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(databaseIconColor)
                        .scaleEffect(isHovered ? 1.05 : 1.0)
                        .animation(.easeInOut(duration: 0.15), value: isHovered)
                }

                // Database Info
                VStack(alignment: .leading, spacing: 3) {
                    Text(database.name)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.primary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    // Database details
                    HStack(spacing: 12) {
                        if let size = database.size {
                            Label(size, systemImage: "internaldrive")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                        }
                        
                        if let tableCount = database.tableCount {
                            Label("\(tableCount) tables", systemImage: "tablecells")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(cardBackground)
            .clipShape(.rect(cornerRadius: 16))
            .shadow(
                color: shadowColor,
                radius: shadowRadius,
                x: 0,
                y: shadowOffset
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(borderColor, lineWidth: 1)
            )
            .scaleEffect(isHovered ? 1.01 : 1.0)
        }
        .buttonStyle(PlainButtonStyle())
        .animation(.easeInOut(duration: 0.2), value: isHovered)
    }
    
    private var databaseIconBackground: Color {
        Color(.controlBackgroundColor).opacity(0.5)
    }

    private var databaseIconColor: Color {
        Color(.gray)
    }

    private var cardBackground: Color {
        Color(.controlColor).opacity(isHovered ? 0.2 : 0.1)
    }

    private var borderColor: Color {
        Color(.separatorColor)
    }

    private var shadowColor: Color {
        isHovered ? Color.black.opacity(0.1) : Color.clear
    }

    private var shadowRadius: CGFloat {
        isHovered ? 4 : 0
    }

    private var shadowOffset: CGFloat {
        isHovered ? 2 : 0
    }
}

// MARK: - Create Database Card
struct CreateDatabaseCard: View {
    let isHovered: Bool
    let onSelect: () -> Void

    private var cardBackground: Color {
        Color(.controlColor).opacity(isHovered ? 0.2 : 0.1)
    }

    private var shadowColor: Color {
        isHovered ? Color.black.opacity(0.1) : Color.clear
    }

    private var shadowRadius: CGFloat {
        isHovered ? 4 : 0
    }

    private var shadowOffset: CGFloat {
        isHovered ? 2 : 0
    }

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color(.controlBackgroundColor).opacity(0.5))
                        .frame(width: 40, height: 40)

                    Image(systemName: "plus")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(.secondary)
                        .scaleEffect(isHovered ? 1.05 : 1.0)
                        .animation(.easeInOut(duration: 0.15), value: isHovered)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text("Create Database")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.primary)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    Text("Create a new database")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(cardBackground)
            .clipShape(.rect(cornerRadius: 16))
            .shadow(color: shadowColor, radius: shadowRadius, x: 0, y: shadowOffset)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color(.separatorColor), lineWidth: 1)
            )
            .scaleEffect(isHovered ? 1.01 : 1.0)
        }
        .buttonStyle(PlainButtonStyle())
        .animation(.easeInOut(duration: 0.2), value: isHovered)
    }
}
