//
//  FilterRowView.swift
//  Pluk
//
//  Created by Fauzaan on 7/6/25.
//

import SwiftUI

struct FilterRowView: View {
    var columns: [DatabaseSchemaInfo]
    @Binding var condition: FilterCondition
    let isFirstRow: Bool
    let onDelete: () -> Void
    var focusedField: FocusState<Int?>.Binding?
    var fieldIndex: Int?
    
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
            
           
            /// Field
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
            .frame(width: 160)
            
            /// Operator
//            OperatorDropdown(selectedOperator: $condition.filterOperator)
            
            // Value input
            TextField("Enter a value", text: $condition.value)
                .textFieldStyle(FilterTextFieldStyle())
                .focused(focusedField ?? FocusState<Int?>().projectedValue, equals: fieldIndex)
                .frame(width: 160)
        }
    }
}
