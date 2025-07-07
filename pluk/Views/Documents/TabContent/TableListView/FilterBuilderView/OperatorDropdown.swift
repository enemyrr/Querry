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
        FloatingDropdown(
            selection: $selectedOperator,
            width: 120,
            itemSymbol: operatorSign
        )
    }
    
    private func operatorSign(for operator: FilterOperator) -> String {
        switch `operator` {
        case .equals:
            return "="
        case .notEquals:
            return "!="
        case .contains:
            return "∋"
        case .startsWith:
            return "^"
        case .endsWith:
            return "$"
        case .greaterThan:
            return ">"
        case .lessThan:
            return "<"
        }
    }
}
