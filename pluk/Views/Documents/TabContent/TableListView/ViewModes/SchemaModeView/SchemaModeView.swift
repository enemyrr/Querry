//
//  SchemaModeView.swift
//  Pluk
//
//  Created by Fauzaan on 10/15/25.
//

import SwiftUI

struct SchemaModeView: View {
    let schema: DatabaseSchemaResult?
    let indexes: [DatabaseIndexInfo]?
    let tableName: String
    @Environment(\.colorScheme) var colorScheme
    
    @State private var splitRatio: CGFloat = 0.6
    @State private var searchText: String = ""
    
    var body: some View {
        SchemaModeViewHeader(tableName: tableName, searchText: $searchText)
        Divider()
        SplitView(.vertical, $splitRatio, dividerColor: Color(.separatorColor), minSize: 0) {
            ShemaTableView(schema: schema, searchText: searchText)
        } right: {
            IndexTableView(indexes: indexes, tableName: tableName, searchText: searchText)
        }
    }
}

extension ConstraintType {
    var abbreviation: String {
        switch self {
        case .primaryKey: return "PK"
        case .foreignKey: return "FK"
        case .unique: return "UQ"
        case .check: return "CK"
        case .exclusion: return "EX"
        case .trigger: return "TR"
        }
    }

    var color: Color {
        switch self {
        case .primaryKey: return .yellow
        case .foreignKey: return .blue
        case .unique: return .purple
        case .check: return .orange
        case .exclusion: return .red
        case .trigger: return .green
        }
    }
}

// MARK: - Schema Header
struct SchemaModeViewHeader: View {
    @State var tableName: String
    @Binding var searchText: String
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            // Table name with label
            HStack(spacing: 8) {
                Text("Table name")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.secondary)

                TextField("eg: first_table", text: $tableName)
                    .textFieldStyle(FilterTextFieldStyle())
                    .textSelection(.enabled)
                    .frame(width: 200)
            }
            
            Text("Read-only")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.trailing, 16)

            Spacer()

            // Search field
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)

                TextField("Search...", text: $searchText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12))

                if !searchText.isEmpty {
                    Button(action: { searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(colorScheme == .dark ? Color(.white).opacity(0.06) : Color(.gray).opacity(0.1))
            )
            .frame(width: 220)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }
}

// MARK: - Schema Table View
struct ShemaTableView: View {
    let schema: DatabaseSchemaResult?
    let searchText: String

    var body: some View {
        if let schema = schema {
            SchemaTableView(
                columns: schema.columns,
                searchText: searchText
            )
        } else {
            VStack(spacing: 12) {
                Image(systemName: "tablecells")
                    .font(.system(size: 32))
                    .foregroundColor(.secondary.opacity(0.5))

                Text("No schema data")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary.opacity(0.7))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}


