//
//  Filter.swift
//  Pluk
//
//  Created by Fauzaan on 7/6/25.
//

import SwiftUI

// MARK: - Models
struct FilterCondition: Identifiable {
    let id = UUID()
    var conjunction: FilterConjunction
    var field: String
    var filterOperator: FilterOperator
    var value: String
}

enum FilterConjunction: String, CaseIterable {
    case whereClause = "where"
    case and = "and"
    case or = "or"
}

enum FilterOperator: String, CaseIterable {
    case equals = "equals"
    case notEquals = "not equals"
    case contains = "contains"
    case startsWith = "starts with"
    case endsWith = "ends with"
    case greaterThan = "greater than"
    case lessThan = "less than"
}

// MARK: - Filter Row View
struct FilterRowView: View {
    var columns: [DatabaseSchemaInfo]
    @Binding var condition: FilterCondition
    let isFirstRow: Bool
    let onDelete: () -> Void
    
    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            /// Remove button
            Button(action: onDelete) {
                Image(systemName: "xmark")
                    .font(.system(size: 12))
            }
            .buttonStyle(TabCloseButtonStyle())
            .frame(width: 10, height: 10)
            .padding(.leading, 4)
            
            /// Conjunction dropdown (where/and/or)
            HStack {
                Text(isFirstRow ? "where" : condition.conjunction.rawValue)
                    .foregroundColor(.primary)
            }
            .frame(width: 50)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color(.controlColor).opacity(0.5))
            .cornerRadius(6)
            
            /// Field dropdown
            Menu {
                ForEach(columns, id: \.columnName) { column in
                    Button(column.columnName) {
                        condition.field = column.columnName
                    }
                }
            } label: {
                Text(condition.field.isEmpty ? "Select field" : condition.field).lineLimit(1).truncationMode(.tail)
                Spacer()
                Image(systemName: "chevron.compact.down")
                    .scaleEffect(CGSize(width: 0.7, height: 1.5))
            }
            .menuStyle(.button)
            .buttonStyle(FilterDropdownStyle())
            .frame(width: 120)
            
            // Operator dropdown
            Menu {
                ForEach(FilterOperator.allCases, id: \.self) { op in
                    Button(op.rawValue) {
                        condition.filterOperator = op
                    }
                }
            } label: {
                Text(condition.filterOperator.rawValue)
                
                Spacer()
                Image(systemName: "chevron.compact.down")
                    .scaleEffect(CGSize(width: 0.7, height: 1.5))
            }
            .menuStyle(.button)
            .buttonStyle(FilterDropdownStyle())
            .frame(width: 120)
            
            // Value input
            TextField("Enter a value", text: $condition.value)
                .textFieldStyle(FilterTextFieldStyle())
            //                .disabled(isSubmitting)
                .frame(width: 150)
        }
    }
}

// MARK: - Main Filter Builder View
struct FilterBuilderView: View {
    var columns: [DatabaseSchemaInfo]
    
    @State private var showFilterBuilder: Bool = true
    @State private var conditions: [FilterCondition] = [
        FilterCondition(conjunction: .whereClause, field: "", filterOperator: .equals, value: "")
    ]
    
    private var hasValidCondition: Bool {
        conditions.contains { condition in
            !condition.field.isEmpty && !condition.value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
    }
    
    var body: some View {
        if showFilterBuilder {
            HStack(alignment: .top, spacing: 28) {
                // Filter rows with overlay divider
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(conditions.indices, id: \.self) { index in
                        FilterRowView(
                            columns: columns,
                            condition: $conditions[index],
                            isFirstRow: index == 0,
                            onDelete: {
                                if conditions.count > 1 {
                                    conditions.remove(at: index)
                                }
                            }
                        )
                    }
                }
                .background(alignment: .trailing) {
                    Rectangle()
                        .fill(Color(.separatorColor))
                        .frame(width: 1)
                        .offset(x: 14)
                }
                
                // Action buttons
                HStack(spacing: 14) {
                    if hasValidCondition {
                        Button("Apply", action: {
                           /// TODO: Add action
                        })
                        .buttonStyle(FilterSubmitButtonStyle())
                    }
                    
                    
                    Button(action: {
                        if conditions.count < 8 {
                            let newCondition = FilterCondition(
                                conjunction: .and,
                                field: columns.isEmpty ? "" : columns[0].columnName,
                                filterOperator: .equals,
                                value: ""
                            )
                            conditions.append(newCondition)
                        }
                    }) {
                        HStack {
                            HStack {
                                Image(systemName: "plus")
                                Text("Add Filter").lineLimit(1)
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color(.controlColor).opacity(0.1))
                        .cornerRadius(8)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .disabled(conditions.count >= 8)
                    
                    Button("Clear filters") {
                        conditions = [FilterCondition(conjunction: .whereClause, field: columns.isEmpty ? "" : columns[0].columnName, filterOperator: .equals, value: "")]
                    }
                    .buttonStyle(FilterClearButtonStyle())
                }
                
                Spacer()
            }
            .padding(16)
            .padding(.bottom, -8)
            .onAppear {
                if !columns.isEmpty && conditions[0].field.isEmpty {
                    conditions[0].field = columns[0].columnName
                }
            }
            .onChange(of: columns) {
                if !columns.isEmpty && conditions[0].field.isEmpty {
                    conditions[0].field = columns[0].columnName
                }
            }
            
            Spacer()
        }
    }
}
