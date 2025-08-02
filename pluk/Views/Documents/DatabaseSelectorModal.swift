//
//  DatabaseSelectorModal.swift
//  Pluk
//
//  Created by Fauzaan on 6/27/25.
//
import SwiftUI

struct DatabaseSelectorModal: View {
    let databaseService: DatabaseService
    let onSelection: (DatabaseWrapper) -> Void
    let onCreateNew: () -> Void
    @Environment(\.dismiss) private var dismiss
    
    @State private var databases: [DatabaseWrapper] = []
    @State private var searchText = ""
    @State private var hoveredDatabase: DatabaseWrapper? = nil
    @State private var isLoading = true
    @State private var loadError: Error? = nil
    
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
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color(.controlColor).opacity(0.2))
                    }
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color(.separatorColor).opacity(0.5), lineWidth: 1)
                    )
                    .cornerRadius(12)
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
            HStack(spacing: 16) {
                // Database Icon
                ZStack {
                    RoundedRectangle(cornerRadius: 14)
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
                
                Spacer()
                
                // Hover indicator
                Image(systemName: "arrow.right")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.secondary)
                    .opacity(isHovered ? 1.0 : 0.0)
                    .scaleEffect(isHovered ? 1.0 : 0.8)
                    .animation(.easeInOut(duration: 0.15), value: isHovered)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(cardBackground)
            .cornerRadius(16)
            .shadow(
                color: shadowColor,
                radius: shadowRadius,
                x: 0,
                y: shadowOffset
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(borderColor, lineWidth: borderWidth)
            )
            .scaleEffect(isHovered ? 1.01 : 1.0)
        }
        .buttonStyle(PlainButtonStyle())
        .animation(.easeInOut(duration: 0.2), value: isHovered)
    }
    
    // MARK: - Computed Properties
    private var databaseIconBackground: Color {
        if isHovered {
            return Color(.controlColor).opacity(0.8)
        } else {
            return Color(.controlColor).opacity(0.3)
        }
    }
    
    private var databaseIconColor: Color {
        .secondary
    }
    
    private var cardBackground: Color {
        if isHovered {
            return Color(.controlColor).opacity(0.5)
        } else {
            return Color(.controlColor).opacity(0.1)
        }
    }
    
    private var borderColor: Color {
        if isHovered {
            return Color(.separatorColor)
        } else {
            return Color(.separatorColor).opacity(0.3)
        }
    }
    
    private var borderWidth: CGFloat {
        1
    }
    
    private var shadowColor: Color {
        if isHovered {
            return Color.black.opacity(0.1)
        } else {
            return Color.clear
        }
    }
    
    private var shadowRadius: CGFloat {
        isHovered ? 4 : 0
    }
    
    private var shadowOffset: CGFloat {
        isHovered ? 2 : 0
    }
}
