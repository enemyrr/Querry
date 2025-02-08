//
//  TextField.swift
//  DocumentPlus
//
//  Created by Fauzaan on 2/8/25.
//

import SwiftUI

struct CustomTextFieldStyle: TextFieldStyle {
    @FocusState private var isFocused: Bool
    
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .textFieldStyle(.plain)
            .padding(.horizontal, 12)
            .padding(.vertical, 12)
            .background(Color.black.opacity(isFocused ? 0.2 : 0))
            .cornerRadius(8)
            .foregroundColor(.white)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(.separator, lineWidth: 1)
            )
            .focused($isFocused)
        
    }
}
