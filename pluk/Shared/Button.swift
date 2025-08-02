//
//  Button.swift
//  Collection
//
//  Created by Fauzaan on 1/18/25.
//

import SwiftUI

struct SidebarButtonStyle: ButtonStyle {
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
            RoundedRectangle(cornerRadius: 8)
                .fill(
                    (isActive || isHovering)
                    ? Color(.controlColor)
                        .opacity(
                            (isActive && isHovering) ? 0.3 : 0.4
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
    var padding: EdgeInsets = EdgeInsets(top: 6, leading: 6, bottom: 6, trailing: 6)
    var disableScaleEffect: Bool = false
    var isActive: Bool = false
    
    func makeBody(configuration: Configuration) -> some View {
        HStack {
            configuration.label
        }
        .padding(padding)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(
                    (isHovering || isActive)
                    ? (colorScheme == .dark
                       ? Color.black.opacity(0.3)
                       : Color(.secondarySystemFill))
                    : Color.clear
                )
        )
        .if(!disableScaleEffect) { view in
            view.scaleEffect(configuration.isPressed ? 0.9 : 1.0)
        }
        .onHover { hovering in
            isHovering = hovering
        }
    }
}

struct AIBackButtonStyle: ButtonStyle {
    @State private var isHovering = false
    var isActive: Bool = true
    
    func makeBody(configuration: Configuration) -> some View {
        HStack {
            configuration.label
        }
        .padding(6)
        .background(
            RoundedCorners(tl: 8, tr: 8, bl: 8, br: 8)
                .fill(
                    isHovering
                    ? (Color(.controlColor))
                        .opacity(0.3)
                    : Color.clear
                )
        )
        .scaleEffect(configuration.isPressed ? 0.9 : 1.0)
        .onHover { hovering in
            isHovering = hovering
        }
    }
}

struct XMarkButtonStyle: ButtonStyle {
    @Environment(\.colorScheme) var colorScheme
    @State private var isHovering = false
    var padding: EdgeInsets = EdgeInsets(top: 6, leading: 6, bottom: 6, trailing: 6)
    var disableScaleEffect: Bool = false
    
    func makeBody(configuration: Configuration) -> some View {
        HStack {
            configuration.label
        }
        .padding(padding)
        .background(
            Circle()
                .fill(
                    isHovering
                    ? (colorScheme == .dark ? Color.black : Color.white)
                        .opacity(0.3)
                    : Color.clear
                )
        )
        .if(!disableScaleEffect) { view in
            view.scaleEffect(configuration.isPressed ? 0.9 : 1.0)
        }
        .onHover { hovering in
            isHovering = hovering
        }
    }
}


struct TabBarButtonStyle: ButtonStyle {
    @Environment(\.colorScheme) var colorScheme
    
    func makeBody(configuration: Configuration) -> some View {
        HStack {
            configuration.label
        }
        .padding(5)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(
                    (colorScheme == .dark
                     ? Color(.controlColor)
                     : Color(.secondarySystemFill))
                )
        )
    }
}

struct TabCloseButtonStyle: ButtonStyle {
    @Environment(\.colorScheme) var colorScheme
    @State private var isHovering = false
    var padding: EdgeInsets = EdgeInsets(top: 4, leading: 4, bottom: 4, trailing: 4)
    var disableScaleEffect: Bool = false
    var isActive: Bool = false
    
    func makeBody(configuration: Configuration) -> some View {
        HStack {
            configuration.label
        }
        .padding(padding)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(
                    (isHovering || isActive)
                    ? (colorScheme == .dark
                       ? Color.white.opacity(0.3)
                       : Color(.secondarySystemFill))
                    : Color.clear
                )
        )
        .if(!disableScaleEffect) { view in
            view.scaleEffect(configuration.isPressed ? 0.9 : 1.0)
        }
        .onHover { hovering in
            isHovering = hovering
        }
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
            ZStack {
                Color.clear
                    .frame(width: 50, height: 40)
                    .contentShape(Rectangle())
                
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color(.white).opacity(0.2), lineWidth: isSelected ? 1.5 : 0)
                    .frame(width: 32, height: 32)
                
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? Color(.white).opacity(0.2) : .clear)
                    .frame(width: 26, height: 26)
                    .overlay(
                        Image(systemName: systemName)
                            .font(.system(size: 12, weight: .semibold))
                    )
            }
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
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(
                        isHovering
                        ? (colorScheme == .dark ? Color.black : Color.white)
                            .opacity(0.3)
                        : Color.clear
                    )
                
                Image(systemName: systemName)
                    .font(.system(size: 12))
                    .opacity(0.7)
            }
            .frame(width: 30, height: 30)
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
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        Button(action: action) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .stroke(color, lineWidth: isSelected ? 1.5 : 0)
                    .frame(width: 32, height: 32)
                
                RoundedRectangle(cornerRadius: 8)
                    .fill(color)
                    .frame(width: 26, height: 26)
                    .overlay(
                        Text(letter)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.white)
                    )
            }
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
    static let buttonColor = Color(red: 248/255, green: 148/255, blue: 99/255)
    @Environment(\.isEnabled) private var isEnabled
    @State private var isHovering = false
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)      // Vertical padding for height
            .font(.system(size: 14, weight: .semibold))
            .foregroundColor(isEnabled ? .black.opacity(0.8) : .secondary)     // White text color
            .background(
                // Use system accent color for native feel, or specify custom blue
                RoundedRectangle(cornerRadius: 10)
                    .fill(isEnabled ? Self.buttonColor : Color.white.opacity(0.1))
                    .opacity(isHovering ? 0.8 : 1.0)
            )
            .opacity(configuration.isPressed ? 0.8 : 1.0)
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
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

struct FilterSubmitButtonStyle: ButtonStyle {
    static let buttonColor = Color(red: 248/255, green: 148/255, blue: 99/255)
    @Environment(\.isEnabled) private var isEnabled
    @State private var isHovering = false
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .lineLimit(1)
            .padding(.vertical, 6)
            .padding(.horizontal, 12)
            .foregroundColor(isEnabled ? Color(.controlBackgroundColor).opacity(0.8) : .secondary)     // White text color
            .background(
                // Use system accent color for native feel, or specify custom blue
                RoundedRectangle(cornerRadius: 6)
                    .fill(isEnabled ? Self.buttonColor : Color.white.opacity(0.1))
                    .opacity(isHovering ? 0.8 : 1.0)
            )
            .opacity(configuration.isPressed ? 0.8 : 1.0)
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
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

struct ChatSendButtonStyle: ButtonStyle {
    static let buttonColor = Color(red: 248/255, green: 148/255, blue: 99/255)
    @Environment(\.isEnabled) private var isEnabled
    @State private var isHovering = false
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(8)      // Vertical padding for height
            .foregroundColor(isEnabled ? Color(.textBackgroundColor) : .secondary)     // White text color
            .background(
                Circle()
                    .fill(isEnabled ? Self.buttonColor : Color.white.opacity(0.1))
                    .opacity(isHovering ? 0.8 : 1.0)
            )
            .opacity(configuration.isPressed ? 0.8 : 1.0)
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
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
        .padding(14)
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(.separator, lineWidth: 1)
        )
        .background(
            RoundedRectangle(cornerRadius: 10)
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

struct FilterDropdownStyle: ButtonStyle {
    @Environment(\.colorScheme) var colorScheme
    @State private var isHovering = false
    
    func makeBody(configuration: Configuration) -> some View {
        HStack {
            configuration.label
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 8)
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(.separator)
        )
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(
                    isHovering
                    ? (colorScheme == .dark ? Color(.controlBackgroundColor) : Color.white)
                        .opacity(0.2)
                    : Color(.controlBackgroundColor).opacity(0.2)
                )
        )
        .cornerRadius(6)
        .onHover { hovering in
            isHovering = hovering
        }
    }
}


struct OutlineButtonStyle: ButtonStyle {
    @Environment(\.colorScheme) var colorScheme
    @State private var isHovering = false
    
    func makeBody(configuration: Configuration) -> some View {
        HStack {
            configuration.label
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 10)
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
        .cornerRadius(8)
        .onHover { hovering in
            isHovering = hovering
        }
    }
}

struct OutlineSecondaryButtonStyle: ButtonStyle {
    @Environment(\.colorScheme) var colorScheme
    @State private var isHovering = false
    
    func makeBody(configuration: Configuration) -> some View {
        HStack {
            configuration.label
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 10)
        .cornerRadius(8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(
                    (colorScheme == .dark ? Color.black : Color.white).opacity(isHovering ? 0.4 : 0.2)
                )
        )
        .onHover { hovering in
            isHovering = hovering
        }
    }
}


struct DistructiveButtonStyleText: ButtonStyle {
    @Environment(\.colorScheme) var colorScheme
    @State private var isHovering = false
    
    func makeBody(configuration: Configuration) -> some View {
        HStack {
            configuration.label
        }
        .padding(.vertical, 7)
        .padding(.horizontal, 11)
        .cornerRadius(8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(
                    isHovering
                    ? (colorScheme == .dark ? Color.black : Color.white)
                        .opacity(0.3)
                    : Color.clear
                )
        )
        .scaleEffect(configuration.isPressed ? 0.9 : 1.0)
        .onHover { hovering in
            isHovering = hovering
        }
    }
}

struct HoverActionButtonStyle: ButtonStyle {
    @Environment(\.colorScheme) var colorScheme
    @State private var isHovering = false
    
    func makeBody(configuration: Configuration) -> some View {
        HStack {
            configuration.label
        }
        .frame(width: 12, height: 12)
        .padding(.vertical, 4)
        .padding(.horizontal, 6)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(
                    isHovering
                    ? (colorScheme == .dark ? Color.black : Color.white)
                        .opacity(0.3)
                    : Color.clear
                )
        )
        .scaleEffect(configuration.isPressed ? 0.9 : 1.0)
        .onHover { hovering in
            isHovering = hovering
        }
    }
}

struct HoverActionButtonStyleText: ButtonStyle {
    @Environment(\.colorScheme) var colorScheme
    @State private var isHovering = false
    
    func makeBody(configuration: Configuration) -> some View {
        HStack {
            configuration.label
        }
        .frame(height: 12)
        .padding(.vertical, 4)
        .padding(.horizontal, 6)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(
                    isHovering
                    ? (colorScheme == .dark ? Color.black : Color.white)
                        .opacity(0.3)
                    : Color.clear
                )
        )
        .scaleEffect(configuration.isPressed ? 0.9 : 1.0)
        .onHover { hovering in
            isHovering = hovering
        }
    }
}

struct RenameCancelButtonStyle: ButtonStyle {
    @Environment(\.colorScheme) var colorScheme
    @State private var isHovering = false
    
    func makeBody(configuration: Configuration) -> some View {
        HStack {
            configuration.label
        }
        .frame(height: 14)
        .padding(.vertical, 4)
        .padding(.horizontal, 8)
        .background(
            RoundedRectangle(cornerRadius: 4)
                .fill(
                    (colorScheme == .dark ? Color.white : Color.black)
                        .opacity(isHovering ? 0.2 : 0.1)
                )
        )
        .onHover { hovering in
            isHovering = hovering
        }
    }
}

struct RenameSaveButtonStyle: ButtonStyle {
    let backgroundColor: Color
    @Environment(\.colorScheme) var colorScheme
    @State private var isHovering = false
    
    init(backgroundColor: Color = .primary) {
        self.backgroundColor = backgroundColor
    }
    
    func makeBody(configuration: Configuration) -> some View {
        HStack {
            configuration.label
        }
        .frame(height: 14)
        .padding(.vertical, 4)
        .padding(.horizontal, 8)
        .background(
            RoundedRectangle(cornerRadius: 4)
                .fill(
                    backgroundColor
                        .opacity(isHovering ? 0.9 : 0.8)
                )
        )
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovering = hovering
            }
        }
    }
}

struct FilterClearButtonStyle: ButtonStyle {
    @State private var isHovering = false
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.vertical, 6)
            .overlay(
                Rectangle()
                    .frame(height: 1)
                    .offset(y: 8)
                    .opacity(isHovering ? 1 : 0)
                    .animation(.easeInOut(duration: 0.2), value: isHovering)
            )
            .onHover { hovering in
                withAnimation(.easeInOut(duration: 0.2)) {
                    isHovering = hovering
                }
            }
    }
}

// MARK: - Compact Button Styles
private struct CompactMenuButtonStyle: ButtonStyle {
    @Environment(\.colorScheme) var colorScheme
    @State private var isHovering = false
    
    func makeBody(configuration: Configuration) -> some View {
        HStack {
            configuration.label
        }
        .font(.system(size: 12, weight: .medium))
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
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

private struct CompactPrimaryButtonStyle: ButtonStyle {
    static let buttonColor = Color(red: 248/255, green: 148/255, blue: 99/255)
    @Environment(\.isEnabled) private var isEnabled
    @State private var isHovering = false
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: .semibold))
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .foregroundColor(isEnabled ? .black.opacity(0.8) : .secondary)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isEnabled ? Self.buttonColor : Color.white.opacity(0.1))
                    .opacity(isHovering ? 0.8 : 1.0)
            )
            .opacity(configuration.isPressed ? 0.8 : 1.0)
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
            .onHover { isHovered in
                isHovering = isHovered
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
    
    func compactMenuButtonStyle() -> some View {
        self.buttonStyle(CompactMenuButtonStyle())
    }
    
    func compactPrimaryStyle() -> some View {
        self.buttonStyle(CompactPrimaryButtonStyle())
    }
}

