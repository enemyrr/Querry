//
//  Button.swift
//  DocumentPlus
//
//  Created by Fauzaan on 1/18/25.
//

import SwiftUI

struct SidebarButtonStyle: ButtonStyle {
    @Environment(\.colorScheme) var colorScheme
    @State private var isHovering = false
    let isActive: Bool

    func makeBody(configuration: Configuration) -> some View {
        HStack {
            configuration.label
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 8)
        .padding(.horizontal, 10)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(
                    (isActive || isHovering)
                        ? (colorScheme == .dark ? Color.black : Color.white)
                            .opacity(
                                (isActive && isHovering) ? 0.2 : 0.3
                            )
                        : Color.clear
                )
        )
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.05)) {
                isHovering = hovering
            }
        }
    }
}

struct ActionButtonStyle: ButtonStyle {
    @Environment(\.colorScheme) var colorScheme
    @State private var isHovering = false

    func makeBody(configuration: Configuration) -> some View {
        HStack {
            configuration.label
        }
        .padding(5)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(
                    isHovering
                        ? (colorScheme == .dark ? Color.black : Color.white)
                            .opacity(0.3)
                        : Color.clear
                )
        )
        .onHover { hovering in
            isHovering = hovering
        }
    }
}


struct TabBarButtonStyle: ButtonStyle {
    @Environment(\.colorScheme) var colorScheme
    let isActive: Bool
    let isHovering: Bool
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(
                        (isActive || isHovering)
                            ? (colorScheme == .dark ? Color.black : Color.white)
                                .opacity(
                                    (isActive && isHovering) ? 0.2 : 0.3
                                )
                            : Color.clear
                    )
            )
            .contentShape(Rectangle())
    }
}

struct CloseButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .frame(width: 16, height: 16)
            .background(
                RoundedRectangle(cornerRadius: 4) // Using RoundedRectangle with small corner radius
                    .fill(Color.gray.opacity(configuration.isPressed ? 0.3 : 0.2))
            )
            .scaleEffect(configuration.isPressed ? 0.9 : 1.0)
            .animation(.easeOut(duration: 0.1), value: configuration.isPressed)
    }
}
