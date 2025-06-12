//
//  CustomTooltip.swift
//  Collection
//
//  Created by Fauzaan on 3/8/25.
//
import SwiftUI

/// Defines the possible positions for the tooltip
enum TooltipPosition {
    case top
    case bottom
    case left
    case right
}

/// Represents a keyboard modifier
struct KeyboardModifier: Identifiable {
    let id = UUID()
    let symbol: String
    
    // Common modifiers
    static let command = KeyboardModifier(symbol: "⌘")
    static let shift = KeyboardModifier(symbol: "shift")
    static let option = KeyboardModifier(symbol: "⌥")
    static let control = KeyboardModifier(symbol: "⌃")
}

/// Represents a keyboard shortcut for display
struct KeyboardShortcut {
    let modifiers: [KeyboardModifier]
    let key: String
}

struct CustomTooltip<TooltipContent: View>: ViewModifier {
    let tooltipContent: TooltipContent
    let delay: Double
    let position: TooltipPosition
    let alignment: TooltipPosition?
    let shortcut: KeyboardShortcut?
    let spacing: CGFloat
    
    @State private var isHovering = false
    @State private var showTooltip = false
    @State private var tooltipSize: CGSize = .zero
    
    init(
        delay: Double = 1,
        position: TooltipPosition = .bottom,
        shortcut: KeyboardShortcut? = nil,
        alignment: TooltipPosition? = nil,
        spacing: CGFloat = 8,
        @ViewBuilder tooltipContent: () -> TooltipContent
    ) {
        self.tooltipContent = tooltipContent()
        self.delay = delay
        self.position = position
        self.shortcut = shortcut
        self.alignment = alignment
        self.spacing = spacing
    }
    
    func body(content: Content) -> some View {
        content
            .onHover { hovering in
                isHovering = hovering
                
                if hovering {
                    // Schedule tooltip after delay
                    DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                        if isHovering {
                            withAnimation(.easeInOut(duration: 0.15)) {
                                showTooltip = true
                            }
                        }
                    }
                } else {
                    // Hide immediately when mouse exits
                    withAnimation(.easeInOut(duration: 0.15)) {
                        showTooltip = false
                    }
                }
            }
            .anchorPreference(key: BoundsPreferenceKey.self, value: .bounds) { $0 }
            .overlayPreferenceValue(BoundsPreferenceKey.self) { bounds in
                GeometryReader { geometry in
                    if showTooltip, let bounds = bounds {
                        let rect = geometry[bounds]
                        
                        if rect.minX != 0 && rect.minY != 0 || rect.width > 0 && rect.height > 0 {
                            if let shortcut = shortcut {
                                // Use keyboard shortcut style tooltip
                                KeyboardShortcutTooltip(
                                    content: tooltipContent,
                                    shortcut: shortcut
                                )
                                .overlay(
                                    GeometryReader { tooltipGeometry -> Color in
                                        DispatchQueue.main.async {
                                            self.tooltipSize = tooltipGeometry.size
                                        }
                                        return Color.clear
                                    }
                                )
                                .position(x: positionX(hostFrame: rect, alignment: alignment), y: positionY(hostFrame: rect))
                                .zIndex(1)
                                .transition(.opacity)
                            } else {
                                // Use regular tooltip
                                BlackTooltip(content: tooltipContent)
                                .overlay(
                                    GeometryReader { tooltipGeometry -> Color in
                                        DispatchQueue.main.async {
                                            self.tooltipSize = tooltipGeometry.size
                                        }
                                        return Color.clear
                                    }
                                )
                                .position(x: positionX(hostFrame: rect, alignment: alignment), y: positionY(hostFrame: rect))
                                .zIndex(1)
                                .transition(.opacity)
                            }

                        }
                    }
                }
            }
            .accessibilityElement(children: .contain)
    }
    
    // Calculate the X position based on tooltip position and host frame
    private func positionX(hostFrame: CGRect, alignment: TooltipPosition?) -> CGFloat {
        let hostCenterX = hostFrame.midX
        
        // First determine base position based on tooltip position
        let baseX: CGFloat
        switch position {
        case .top, .bottom:
            // Base is centered horizontally by default
            baseX = hostCenterX
            
        case .left:
            // Position to the left of the host
            baseX = hostFrame.minX - (tooltipSize.width / 2) - spacing
            
        case .right:
            // Position to the right of the host
            baseX = hostFrame.maxX + (tooltipSize.width / 2) + spacing
        }
        
        // Then apply horizontal alignment if specified (only applies to top/bottom)
        if position == .top || position == .bottom, let alignment = alignment {
            switch alignment {
            case .left:
                // Align with left edge of host (with padding)
                return hostFrame.minX + (tooltipSize.width / 2) + spacing/2
            case .right:
                // Align with right edge of host (with padding)
                return hostFrame.maxX - (tooltipSize.width / 2) - spacing/2
            default:
                // For top/bottom alignments, keep centered
                return baseX
            }
        }
        
        return baseX
    }
    
    // Calculate the Y position based on tooltip position and host frame
    private func positionY(hostFrame: CGRect) -> CGFloat {
        let hostCenterY = hostFrame.midY
        
        // First determine base position based on tooltip position
        let baseY: CGFloat
        switch position {
        case .left, .right:
            // Base is centered vertically by default
            baseY = hostCenterY
            
        case .top:
            // Position above the host
            baseY = hostFrame.minY - (tooltipSize.height / 2) - spacing
            
        case .bottom:
            // Position below the host
            baseY = hostFrame.maxY + (tooltipSize.height / 2) + spacing
        }
        
        // Then apply vertical alignment if specified (only applies to left/right)
        if (position == .left || position == .right), let alignment = alignment {
            switch alignment {
            case .top:
                // Align with top edge of host (with padding)
                return hostFrame.minY + (tooltipSize.height / 2) + spacing/2
            case .bottom:
                // Align with bottom edge of host (with padding)
                return hostFrame.maxY - (tooltipSize.height / 2) - spacing/2
            default:
                // For left/right alignments, keep centered
                return baseY
            }
        }
        
        return baseY
    }
}

// Simple black tooltip
struct BlackTooltip<Content: View>: View {
    let content: Content
    
    var body: some View {
        content
            .padding(8)
            .foregroundColor(.white)
            .background(Color.black)
            .cornerRadius(10)
            .fixedSize()
            .compositingGroup()
            .shadow(color: Color.black.opacity(0.2), radius: 1, x: 0, y: 1)
    }
}

// Keyboard shortcut style tooltip
struct KeyboardShortcutTooltip<Content: View>: View {
    let content: Content
    let shortcut: KeyboardShortcut
    
    var body: some View {
        HStack(spacing: 0) {
            // Label/text content
            content
                .padding(.leading, 4)
                .padding(.trailing, 12)
                .foregroundColor(.white)
            
            // Keyboard shortcut indicators
            ForEach(shortcut.modifiers) { modifier in
                KeyModifierView(symbol: modifier.symbol)
            }
            
            // Key
            KeyView(symbol: shortcut.key)
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.black)
        )
        .fixedSize()
        .compositingGroup()
        .shadow(color: Color.black.opacity(0.2), radius: 1, x: 0, y: 1)
    }
}

// View for command, option symbols
struct KeyModifierView: View {
    let symbol: String
    
    var body: some View {
        Text(symbol)
            .font(.system(size: 11))
            .padding(.vertical, 2)
            .padding(.horizontal, 6)
            .foregroundColor(.white)
            .background(
                RoundedRectangle(cornerRadius: 4)
                .fill(Color(white: 0.2))
            )
            .padding(.trailing, 6)
    }
}

// View for the keyboard key
struct KeyView: View {
    let symbol: String
    
    var body: some View {
        Text(symbol)
            .font(.system(size: 11))
            .padding(.vertical, 2)
            .padding(.horizontal, 6)
            .foregroundColor(.white)
            .background(
                RoundedRectangle(cornerRadius: 4)
                .fill(Color(white: 0.2))
            )
    }
}

// Preference key to get the bounds of the host view
struct BoundsPreferenceKey: PreferenceKey {
    static var defaultValue: Anchor<CGRect>? = nil
    
    static func reduce(value: inout Anchor<CGRect>?, nextValue: () -> Anchor<CGRect>?) {
        value = nextValue() ?? value
    }
}

extension View {
    /// Apply a custom tooltip with the specified position and spacing
    func customHelp<TooltipContent: View>(
        delay: Double = 1,
        position: TooltipPosition = .bottom,
        shortcut: KeyboardShortcut? = nil,
        alignment: TooltipPosition? = nil,
        spacing: CGFloat = 8,
        @ViewBuilder content: @escaping () -> TooltipContent
    ) -> some View {
        self.modifier(CustomTooltip(
            delay: delay,
            position: position,
            shortcut: shortcut,
            alignment: alignment,
            spacing: spacing,
            tooltipContent: content
        ))
    }
    
    /// Convenience version for simple text tooltips with position control
    func customHelp(
        _ text: String,
        delay: Double = 1.5,
        position: TooltipPosition = .bottom,
        shortcut: KeyboardShortcut? = nil,
        alignment: TooltipPosition? = nil,
        spacing: CGFloat = 8
    ) -> some View {
        self.customHelp(
            delay: delay,
            position: position,
            shortcut: shortcut,
            alignment: alignment,
            spacing: spacing
        ) {
            Text(text)
                .font(.system(size: 11))
        }
    }
}
