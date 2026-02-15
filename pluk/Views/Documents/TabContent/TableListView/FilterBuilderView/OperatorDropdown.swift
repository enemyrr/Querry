//
//  OperatorDropdown.swift
//  Pluk
//
//  Created by Assistant on 7/7/25.
//

import SwiftUI

struct OperatorDropdown: View {
    @Binding var selectedOperator: FilterOperator
    
    var body: some View {
        Menu {
            ForEach(FilterOperator.allCases, id: \.self) { filterOperator in
                Button(filterOperator.rawValue) {
                    selectedOperator = filterOperator
                }
            }
        } label: {
            Text(selectedOperator.rawValue).lineLimit(1)
            Spacer()
            Image(systemName: "chevron.compact.down")
                .scaleEffect(CGSize(width: 0.7, height: 1.5))
        }
        .menuStyle(.button)
        .buttonStyle(FilterDropdownStyle())
        .frame(width: 120)
    }
}
