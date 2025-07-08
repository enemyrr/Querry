//
//  FieldDropdown.swift
//  Pluk
//
//  Created by Assistant on 7/7/25.
//

import SwiftUI

struct FieldDropdown: View {
    var columns: [DatabaseSchemaInfo]
    @Binding var selectedColumnName: String
    
    var body: some View {
        ArrayFloatingDropdown(
            items: columns.map(\.columnName),
            selection: $selectedColumnName,
            width: 160,
            itemDisplay: { $0 }
        )
    }
}
