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

    @State private var hoveredDatabaseType: DatabaseType? = nil
    @Environment(\.dismiss) var dismiss

    var groupedDatabaseTypes: [(DatabaseCategory, [DatabaseType])] {
        let visible = DatabaseType.allCases.filter { $0 != .supabase }
        let grouped = Dictionary(grouping: visible) { $0.category }
        return DatabaseCategory.allCases.compactMap { category in
            guard let databaseTypes = grouped[category], !databaseTypes.isEmpty else { return nil }
            return (category, databaseTypes)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 6) {
                    Text("Connect Your Database")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(.primary)

                    Text("Choose from cloud-hosted solutions or connect to your existing database")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 68)
                .padding(.horizontal, 32)
                .padding(.bottom, 28)

                VStack(spacing: 24) {
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
                .padding(.bottom, 32)
            }
        }
        .overlay(alignment: .topTrailing) {
            SheetChromeButton(systemImage: "xmark") {
                dismiss()
            }
            .padding(.top, 20)
            .padding(.trailing, 20)
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
                    .foregroundStyle(.secondary)
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
                    selectedDatabaseType = databaseType
                }
                .onHover { isHovered in
                    hoveredDatabaseType = isHovered ? databaseType : nil
                }
            }
        }
    }
}

// MARK: - Database Type Card
struct DatabaseTypeCard: View {
    @Environment(\.colorScheme) var colorScheme
    let databaseType: DatabaseType
    let isSelected: Bool
    let isHovered: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                Image(databaseType.icon)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 32, height: 32)
                    .foregroundStyle(databaseType.accentColor)

                Text(databaseType.displayName)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(databaseType.status == .comingSoon ? .secondary : .primary)
                    .lineLimit(1)
                    .fixedSize(horizontal: false, vertical: true)

                Spacer(minLength: 4)

                statusBadge
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(cardBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(borderColor, lineWidth: 0.5)
            )
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .disabled(databaseType.status == .comingSoon)
        .animation(.easeInOut(duration: 0.15), value: isHovered)
    }

    @ViewBuilder
    private var statusBadge: some View {
        switch databaseType.status {
        case .beta:
            Text("Beta")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.orange)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .overlay(
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .stroke(Color.orange.opacity(0.82), lineWidth: 1)
                )
        case .comingSoon:
            Text("Soon")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .overlay(
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .stroke(Color(.separatorColor), lineWidth: 1)
                )
        default:
            EmptyView()
        }
    }

    private var cardBackground: Color {
        if isHovered {
            return Color(.controlColor).opacity(0.35)
        }
        return Color(.controlColor).opacity(0.15)
    }

    private var borderColor: Color {
        Color(.separatorColor).opacity(0.5)
    }
}
