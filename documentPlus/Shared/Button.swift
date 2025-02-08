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

struct IconButton: View {
    let systemName: String
    let isSelected: Bool
    let action: () -> Void
    let withBorder: Bool = false
    @Environment(\.colorScheme) var colorScheme
    @State private var isHovering = false
    
    var body: some View {
        Button(action: action) {
            RoundedRectangle(cornerRadius: 10).fill(
                isHovering || isSelected
                ? Color.black.opacity(0.3) : Color.clear
            )
            .frame(width: 28, height: 28)
            .overlay(
                Image(systemName: systemName)
                    .font(.system(size: 14))
            )
            
        }
        .buttonStyle(PlainButtonStyle())
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.2)) {
                isHovering = hovering
                if hovering {
                    NSCursor.pointingHand.push()
                } else {
                    NSCursor.pop()
                }
            }
        }
    }
}

struct IconButtonWithoutBorder: View {
    let systemName: String
    let isSelected: Bool
    let action: () -> Void
    let withBorder: Bool = false
    @Environment(\.colorScheme) var colorScheme
    @State private var isHovering = false
    
    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 12))
                .frame(width: 30, height: 30)
                .opacity(0.7)
        }
        .buttonStyle(PlainButtonStyle())
        .background(
            RoundedRectangle(cornerRadius: 10).fill(
                isHovering
                ? (colorScheme == .dark ? Color.black : Color.white)
                    .opacity(0.3)
                : Color.clear
            )
        )
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.2)) {
                isHovering = hovering
                if hovering {
                    NSCursor.pointingHand.push()
                } else {
                    NSCursor.pop()
                }
            }
        }
    }
}

struct DatabaseIcon: View {
    let color: Color
    let letter: String
    let isSelected: Bool
    @State private var isHovering = false
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            RoundedRectangle(cornerRadius: 10)
                .fill(color.opacity(
                    (isHovering || isSelected) ? 1.0 : 0.3)
                )
                .frame(width: 28, height: 28)
                .overlay(
                    Text(letter)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                )
        }
        .buttonStyle(PlainButtonStyle())
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.2)) {
                isHovering = hovering
                if hovering {
                    NSCursor.pointingHand.push()
                } else {
                    NSCursor.pop()
                }
            }
        }
    }
}

struct PrimaryButtonStyle: ButtonStyle {
    static let buttonColor = Color(red: 99/255, green: 197/255, blue: 248/255)
    @Environment(\.isEnabled) private var isEnabled
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)      // Vertical padding for height
            .font(.system(size: 12, weight: .semibold))
            .foregroundColor(isEnabled ? .black : .secondary)     // White text color
            .background(
                // Use system accent color for native feel, or specify custom blue
                RoundedRectangle(cornerRadius: 8)
                    .fill(isEnabled ? Self.buttonColor : Color.white.opacity(0.1))
            )
            // Add subtle pressed state effect
            .opacity(configuration.isPressed ? 0.8 : 1.0)
            // Add subtle scale effect when pressed
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            // Smooth animation for press states
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
            // Add hand cursor on hover
            .onHover { isHovered in
                if isHovered {
                    NSCursor.pointingHand.push()
                } else {
                    NSCursor.pop()
                }
            }
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    static let buttonColor = Color(.black).opacity(0.3)
    @Environment(\.isEnabled) private var isEnabled
    @State private var isHovering = false
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)      // Vertical padding for height
            .font(.system(size: 12, weight: .semibold))
            .foregroundColor(isEnabled ? .secondary : .secondary)     // White text color
            .background(
                // Use system accent color for native feel, or specify custom blue
                RoundedRectangle(cornerRadius: 8)
                    .fill(isHovering ? Self.buttonColor : .clear)
            )
            // Add subtle pressed state effect
            .opacity(configuration.isPressed ? 0.8 : 1.0)
            // Add subtle scale effect when pressed
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            // Smooth animation for press states
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
            // Add hand cursor on hover
            .onHover { isHovered in
                isHovering = isHovered
                if isHovered {
                    NSCursor.pointingHand.push()
                } else {
                    NSCursor.pop()
                }
            }
    }
}

struct CustomMenuButtonStyle: ButtonStyle {
    @Environment(\.colorScheme) var colorScheme
    @State private var isHovering = false
    
    func makeBody(configuration: Configuration) -> some View {
        HStack {
            configuration.label
        }
        .padding(12)
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(.separator, lineWidth: 1)
        )
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(
                    isHovering
                    ? (colorScheme == .dark ? Color.black : Color.white)
                        .opacity(0.2)
                    : Color.clear
                )
        )
        .onHover { hovering in
            isHovering = hovering
        }
    }
}

extension Button {
    func primaryStyle() -> some View {
        self.buttonStyle(PrimaryButtonStyle())
    }
    
    func secondaryStyle() -> some View {
        self.buttonStyle(SecondaryButtonStyle())
    }
    
    func customMenuButtonStyle() -> some View {
        self.buttonStyle(CustomMenuButtonStyle())
    }
}

