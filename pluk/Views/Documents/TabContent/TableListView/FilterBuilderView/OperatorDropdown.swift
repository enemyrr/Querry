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
        EnumFloatingDropdown(
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
                return "<>"
            case .greaterThan:
                return ">"
            case .greaterThanOrEquals:
                return ">="
            case .lessThan:
                return "<"
            case .lessThanOrEquals:
                return "<="
            case .like:
                return "~"
            case .ilike:
                return "~*"
            case .notLike:
                return "!~"
            case .startsWith:
                return "^"
            case .endsWith:
                return "$"
            case .isIn:
                return ""
            case .isNull:
                return ""
            case .isNotNull:
                return ""
            }
        
    }
}
