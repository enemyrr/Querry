//
//  ToolTip.swift
//  Collection
//
//  Created by Fauzaan on 3/7/25.
//

import SwiftUI

// MARK: - Custom macOS-style Tooltip
struct MacOSTooltipModifier: ViewModifier {
    let content: String
    let delay: Double
    
    @State private var isShowingTooltip = false
    @State private var hoverTask: Task<Void, Never>? = nil
    
    func body(content: Content) -> some View {
        content
            .onHover { isHovering in
                // Cancel existing hover task
                hoverTask?.cancel()
                
                if isHovering {
                    // Create new task with delay
                    hoverTask = Task {
                        try? await Task.sleep(for: .seconds(delay))
                        if !Task.isCancelled {
                            isShowingTooltip = true
                        }
                    }
                } else {
                    isShowingTooltip = false
                }
            }
            .overlay(alignment: .bottom) {
                if isShowingTooltip {
                    MacOSTooltipView(text: self.content)
                        .offset(y: 30)
                        .transition(.opacity.combined(with: .offset(y: 10)))
                        .zIndex(100)
                        .animation(.easeOut(duration: 0.2), value: isShowingTooltip)
                }
            }
    }
}

// MARK: - macOS Style Tooltip View
struct MacOSTooltipView: View {
    let text: String
    
    var body: some View {
        Text(text)
            .font(.system(size: 11))
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .foregroundColor(.white)
            .background {
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.black.opacity(0.8))
            }
            .shadow(color: .black.opacity(0.15), radius: 3, x: 0, y: 1)
    }
}

// MARK: - View Extension
extension View {
    /// Adds a macOS-style tooltip that appears after hovering
    /// - Parameters:
    ///   - text: The tooltip text to display
    ///   - delay: Time in seconds before tooltip appears (default: 0.7)
    func macOSTooltip(_ text: String, delay: Double = 0.7) -> some View {
        self.modifier(MacOSTooltipModifier(content: text, delay: delay))
    }
}


// MARK: - Example Usage
struct ContentView: View {
    var body: some View {
        VStack(spacing: 40) {
            // Example 1: Apply to a system button
            Button("Normal Button") {
                // Button action
            }
            .macOSTooltip("This is a standard button")
            
            // Example 2: Apply to the exact shortcut style button from the image
            HStack(spacing: 0) {
                Text("Share")
                    .font(.system(size: 15))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                
                Divider()
                    .frame(height: 16)
                    .background(Color.white.opacity(0.2))
                
                Image(systemName: "command")
                    .font(.system(size: 14))
                    .frame(width: 40)
                
                Text("shift")
                    .font(.system(size: 14))
                    .frame(width: 60, height: 28)
                    .background(Color(nsColor: NSColor(white: 0.2, alpha: 1.0)))
                    .cornerRadius(4)
                
                Text("C")
                    .font(.system(size: 14))
                    .frame(width: 28, height: 28)
                    .background(Color(nsColor: NSColor(white: 0.2, alpha: 1.0)))
                    .cornerRadius(4)
                    .padding(.trailing, 8)
            }
            .foregroundColor(.white)
            .background(Color.black.opacity(0.8))
            .cornerRadius(28)
            .macOSTooltip("Share the current content")
            
            // Example 3: Apply to an image or icon
            Image(systemName: "questionmark.circle")
                .font(.system(size: 24))
                .macOSTooltip("Get help with this feature", delay: 0.5)
        }
        .padding(40)
        .frame(width: 400, height: 300)
    }
}

// MARK: - Preview
#Preview {
    ContentView()
}
