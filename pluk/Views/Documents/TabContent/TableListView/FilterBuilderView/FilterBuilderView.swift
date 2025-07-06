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
        HStack(alignment: .center, spacing: 16) {
            /// Remove button
            Button(action: onDelete) {
                Image(systemName: "xmark")
                    .font(.system(size: 12))
            }
            .buttonStyle(TabCloseButtonStyle())
            .frame(width: 10, height: 10)
            
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
                Text(condition.field)
                Spacer()
                Image(systemName: "chevron.compact.down")
                    .scaleEffect(CGSize(width: 0.7, height: 1.5))
            }
            .menuStyle(.button)
            .buttonStyle(FilterDropdownStyle())
            .frame(width: 100)
            
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
            .frame(width: 100)
            
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
        FilterCondition(conjunction: .whereClause, field: "id", filterOperator: .equals, value: "")
    ]
    
    var body: some View {
        if showFilterBuilder {
            HStack(alignment: .top, spacing: 16) {
                // Filter rows
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(Array(conditions.enumerated()), id: \.element.id) { index, condition in
                        FilterRowView(
                            columns: columns,
                            condition: .constant(condition),
                            isFirstRow: index == 0,
                            onDelete: {
                                if conditions.count > 1 {
                                    conditions.remove(at: index)
                                }
                            }
                        )
                    }
                }
                
                // Action buttons
                HStack(spacing: 16) {
                    Button(action: {
                        let newCondition = FilterCondition(
                            conjunction: .and,
                            field: "id",
                            filterOperator: .equals,
                            value: ""
                        )
                        conditions.append(newCondition)
                    }) {
                        HStack {
                            Image(systemName: "plus")
                            Text("Add Filter")
                        }
                    }
                    .buttonStyle(FilterSubmitButtonStyle())
                    .frame(width: 100)
                    
                    Button("Clear filters") {
                        conditions = [FilterCondition(conjunction: .whereClause, field: "id", filterOperator: .equals, value: "")]
                    }
                    .padding(.vertical, 6)
                    .buttonStyle(PlainButtonStyle())
                }
                
                Spacer()
            }
            .padding(16)
            .padding(.bottom, -8)
            
            Spacer()
        }
    }
}
