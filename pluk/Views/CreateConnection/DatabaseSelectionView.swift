//
//  DatabaseSelectionView.swift
//  Pluk
//
//  Created by Fauzaan on 5/30/25.
//

import Foundation
import SwiftUI

struct DatabaseSelectionView: View {
    @Binding var selectedDatabaseType: DatabaseType?
    @State private var searchText = ""
    @State private var hoveredDatabaseType: DatabaseType? = nil
    @Environment(\.dismiss) var dismiss
    
    var filteredDatabaseTypes: [DatabaseType] {
        if searchText.isEmpty {
            return DatabaseType.allCases
        }
        return DatabaseType.allCases.filter {
            $0.displayName.localizedCaseInsensitiveContains(searchText)
        }
    }
    
    var groupedDatabaseTypes: [(DatabaseCategory, [DatabaseType])] {
        let grouped = Dictionary(grouping: filteredDatabaseTypes) { $0.category }
        return DatabaseCategory.allCases.compactMap { category in
            guard let databaseTypes = grouped[category], !databaseTypes.isEmpty else { return nil }
            return (category, databaseTypes)
        }
    }
    
    var body: some View {
        ZStack(alignment: .topTrailing) {
            VStack(spacing: 0) {
                // Header Section
                VStack(spacing: 24) {
                    VStack(spacing: 8) {
                        Text("Connect Your Database")
                            .font(.title)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                        
                        Text("Choose from cloud-hosted solutions or connect to your existing database")
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
                        
                        TextField("Search database types", text: $searchText)
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
                            .fill(Color.black.opacity(0.2))
                    }
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color(.separatorColor).opacity(0.5), lineWidth: 1)
                    )
                    .cornerRadius(12)
                }
                .padding(.horizontal, 32)
                .padding(.top, 32)
                
                // Database Types Grid
                ScrollView {
                    VStack(spacing: 32) {
                        ForEach(groupedDatabaseTypes, id: \.0) { category, databaseTypes in
                            DatabaseCategorySection(
                                category: category,
                                databaseTypes: databaseTypes,
                                selectedDatabaseType: $selectedDatabaseType,
                                hoveredDatabaseType: $hoveredDatabaseType
                            )
                        }
                    }
                    .padding(.horizontal, 32)
                    .padding(.vertical, 24)
                }
            }
            .padding(.bottom, 32)
            
            Button(action: {
                dismiss()
            }) {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.secondary)
            }
            .buttonStyle(XMarkButtonStyle())
            .padding(.top, 16)
            .padding(.trailing, 16)
        }
    }
}

// MARK: - Database Category Section
struct DatabaseCategorySection: View {
    let category: DatabaseCategory
    let databaseTypes: [DatabaseType]
    @Binding var selectedDatabaseType: DatabaseType?
    @Binding var hoveredDatabaseType: DatabaseType?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text(category.rawValue)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.secondary)
                    .textCase(.uppercase)
                    .tracking(1)
                
                Spacer()
            }
            
            DatabaseTypesGrid(
                databaseTypes: databaseTypes,
                selectedDatabaseType: $selectedDatabaseType,
                hoveredDatabaseType: $hoveredDatabaseType
            )
        }
    }
}

// MARK: - Database Types Grid
struct DatabaseTypesGrid: View {
    let databaseTypes: [DatabaseType]
    @Binding var selectedDatabaseType: DatabaseType?
    @Binding var hoveredDatabaseType: DatabaseType?
    
    var body: some View {
        LazyVGrid(columns: [
            GridItem(.flexible(), spacing: 16),
            GridItem(.flexible(), spacing: 16)
        ], spacing: 16) {
            ForEach(databaseTypes, id: \.self) { databaseType in
                DatabaseTypeCard(
                    databaseType: databaseType,
                    isSelected: selectedDatabaseType == databaseType,
                    isHovered: hoveredDatabaseType == databaseType
                ) {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedDatabaseType = databaseType
                    }
                }
                .onHover { isHovered in
                    withAnimation(.easeInOut(duration: 0.15)) {
                        hoveredDatabaseType = isHovered ? databaseType : nil
                    }
                }
            }
        }
    }
}

// MARK: - Database Type Card
struct DatabaseTypeCard: View {
    let databaseType: DatabaseType
    let isSelected: Bool
    let isHovered: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 0) {
                VStack(spacing: 16) {
                    HStack {
                        // Database type icon and name
                        HStack(spacing: 12) {
                            Image(databaseType.icon)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 32, height: 32)
                                .scaleEffect(isHovered ? 1.05 : 1.0)
                                .animation(.easeInOut(duration: 0.15), value: isHovered)
                                .foregroundStyle(databaseType.accentColor)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                HStack(spacing: 8) {
                                    Text(databaseType.displayName)
                                        .font(.system(size: 16, weight: .medium))
                                        .foregroundColor(.primary)
                                    
                                    // Inline status text
                                    if databaseType.status == .beta {
                                        Text("• \(statusText)")
                                            .font(.system(size: 12, weight: .medium))
                                            .foregroundColor(statusColor)
                                    }
                                }
                                
                                if databaseType.status == .comingSoon {
                                    Text("Comming Soon")
                                        .font(.system(size: 12))
                                        .foregroundColor(.secondary)
                                    
                                }
                            }
                        }
                        
                        Spacer()
                    }
                }
                .padding(20)
            }
            .background(cardBackground)
            .cornerRadius(16)
            .scaleEffect(isHovered ? 1.01 : 1.0)
            .shadow(
                color: shadowColor,
                radius: shadowRadius,
                x: 0,
                y: shadowOffset
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(borderColor)
                    .blendMode(.plusLighter)
                    .scaleEffect(isHovered ? 1.01 : 1.0)
            )
        }
        .buttonStyle(PlainButtonStyle())
        .disabled(databaseType.status == .comingSoon)
        .animation(.easeInOut(duration: 0.2), value: isHovered)
        .animation(.easeInOut(duration: 0.2), value: isSelected)
    }
    
    private var statusColor: Color {
        switch databaseType.status {
        case .beta: return .orange
        default: return .clear
        }
    }
    
    private var statusText: String {
        switch databaseType.status {
        case .beta: return "Beta"
        case .comingSoon: return "Comming Soon"
        default: return ""
        }
    }
    
    private var cardBackground: Color {
        if isSelected {
            return Color(.controlColor)
        } else if isHovered {
            return Color(.controlColor).opacity(0.5)
        } else {
            return Color(.controlColor).opacity(0.1)
        }
    }
    
    private var borderColor: Color {
        if isSelected {
            return databaseType.accentColor
        } else if isHovered {
            return databaseType.accentColor
        } else {
            return Color(.separatorColor).opacity(0.5)
        }
    }
    
    private var borderWidth: CGFloat {
        isSelected ? 2 : 1
    }
    
    private var shadowColor: Color {
        if isSelected {
            return databaseType.accentColor.opacity(0.2)
        } else if isHovered {
            return Color.black.opacity(0.1)
        } else {
            return Color.clear
        }
    }
    
    private var shadowRadius: CGFloat {
        if isSelected {
            return 8
        } else if isHovered {
            return 4
        } else {
            return 0
        }
    }
    
    private var shadowOffset: CGFloat {
        isHovered || isSelected ? 2 : 0
    }
}
