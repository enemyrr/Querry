//
//  ConnectionColorPicker.swift
//  DocumentPlus
//
//  Created by Fauzaan on 2/1/25.
//
import SwiftUI

struct ConnectionColorPicker: View {
    @Binding var selectedColor: String
    @Environment(\.colorScheme) var colorScheme
    @State private var isPickerPresented = false
    @State private var isHovering = false
    @FocusState private var isFocused: Bool
    
    // Predefined colors with their identifiers
    let colors: [(id: String, color: Color)] = [
        ("white", .white),
        ("turquoise", Color(hex: "#40E0D0")),
        ("darkGray", Color(hex: "#505050")),
        ("blue", Color(hex: "#007AFF")),
        ("mint", Color(hex: "#00FFD1")),
        ("lightBlue", Color(hex: "#87CEEB")),
        ("lime", Color(hex: "#32CD32")),
        ("emerald", Color(hex: "#50C878")),
        ("indigo", Color(hex: "#4B0082")),
        ("mauve", Color(hex: "#E0B0FF")),
        ("purple", Color(hex: "#9932CC")),
        ("pink", Color(hex: "#FF69B4")),
        ("red", Color(hex: "#FF3B30")),
        ("coral", Color(hex: "#FF4500")),
        ("salmon", Color(hex: "#FFA07A")),
        ("orange", Color(hex: "#FF9500")),
        ("yellow", Color(hex: "#FFCC00")),
        ("teal", Color(hex: "#008080"))
    ]
    var selectedColorOption: (id: String, color: Color)? {
        colors.first(where: { $0.id == selectedColor })
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Color")
                .foregroundColor(.white.opacity(0.7))
                .font(.system(size: 13))
            
            Button(action: {
                isPickerPresented.toggle()
            }) {
                HStack {
                    if let colorOption = selectedColorOption {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(colorOption.color)
                            .frame(width: 16, height: 16)
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .strokeBorder(Color.white.opacity(0.1), lineWidth: 1)
                            )
                        
                        Text(colorOption.id.capitalized)
                            .foregroundColor(.white)
                    } else {
                        Text("Select a color")
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.compact.down")
                        .scaleEffect(CGSize(width: 0.7, height: 1.5))
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
                            isFocused || isHovering || isPickerPresented
                            ? (colorScheme == .dark ? Color.black : Color.white)
                                .opacity(0.2)
                            : Color.clear
                        )
                )
                .onHover { hovering in
                    isHovering = hovering
                }
            }
            .onHover { isHovered in
                if isHovered {
                    NSCursor.pointingHand.push()
                } else {
                    NSCursor.pop()
                }
            }
            .focused($isFocused)
            .buttonStyle(.plain)
            .onKeyPress(.space, phases: .down) { _ in
                isPickerPresented.toggle()
                return .handled
            }
            .popover(isPresented: $isPickerPresented, arrowEdge: .bottom) {
                ColorPickerPopover(selectedColor: $selectedColor, colors: colors) {
                    isPickerPresented = false
                }
            }
        }
    }
}

struct ColorButton: View {
    let color: Color
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            ZStack {
                // Outer selection border
                RoundedRectangle(cornerRadius: 12)
                    .stroke(color, lineWidth: isSelected ? 1 : 0)
                    .frame(width: 36, height: 36)  // Fixed outer frame
                
                // Main color button
                RoundedRectangle(cornerRadius: 10)
                    .fill(color)
                    .frame(width: 30, height: 30)  // Fixed inner frame
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .strokeBorder(Color.white.opacity(0.1), lineWidth: 1)
                    )
            }
        }
        .buttonStyle(PlainButtonStyle())
        .frame(width: 36, height: 36)  // Fixed container frame
        .contentShape(RoundedRectangle(cornerRadius: 12))
        .onHover { isHovered in
            if isHovered {
                NSCursor.pointingHand.push()
            } else {
                NSCursor.pop()
            }
        }
        .help("Select color")
    }
}

struct ColorPickerPopover: View {
    @Binding var selectedColor: String
    let colors: [(id: String, color: Color)]
    let onSelect: () -> Void
    
    private let columns = Array(repeating: GridItem(.fixed(40), spacing: 8), count: 6)
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Choose a Color")
                .font(.headline)
                .foregroundColor(.white)
                .padding(.horizontal, 16)
                .padding(.top, 16)
            
            ScrollView {
                LazyVGrid(columns: columns, spacing: 8) {
                    ForEach(colors, id: \.id) { colorOption in
                        ColorButton(
                            color: colorOption.color,
                            isSelected: selectedColor == colorOption.id
                        ) {
                            selectedColor = colorOption.id
                            onSelect()
                        }
                    }
                }
                .padding(16)
            }
        }
    }
}


// Helper extension for hex color support
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }
        
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// Preview
struct ConnectionColorPicker_Previews: PreviewProvider {
    static var previews: some View {
        ConnectionColorPicker(selectedColor: .constant("blue"))
            .frame(width: 300)
            .padding()
            .background(Color.black)
    }
}
