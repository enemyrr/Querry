//
//  CompactAccessoryButtonStyle.swift
//  DocumentPlus
//
//  Created by Fauzaan on 1/5/25.
//

import SwiftUI

struct CompactAccessoryButtonStyle: ButtonStyle {
    @State private var isHovered = false
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(2)
            .background(configuration.isPressed ? Color.gray.opacity(0.3) :
                        isHovered ? Color.gray.opacity(0.2) :
                        Color.clear)
            .cornerRadius(4)
            .onHover { hovering in
                isHovered = hovering
            }
    }
}

extension ButtonStyle where Self == CompactAccessoryButtonStyle {
    /// A compact button style for accessory views like close buttons
    /// Usage: .buttonStyle(.compactAccessory)
    static var compactAccessory: CompactAccessoryButtonStyle {
        CompactAccessoryButtonStyle()
    }
}


#Preview {
    Button("Hello, World!") {}
        .buttonStyle(CompactAccessoryButtonStyle())
}
