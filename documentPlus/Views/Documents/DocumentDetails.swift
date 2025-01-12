//
//  DocumentDetails.swift
//  documentPlus
//
//  Created by Fauzaan on 12/31/24.
//
import SwiftUI
import SwiftData
import MongoKitten

struct DocumentDetails: View {
    let document: Document
    @State private var isCardHovered = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            DocumentKeyValueList(document: document)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(NSColor.controlColor).opacity(0.1))
        .cardStyle(isHovered: isCardHovered)
        .overlay(HoverActionButtons(isVisible: isCardHovered), alignment: .topTrailing)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.2)) {
                isCardHovered = hovering
            }
        }
    }
}

struct DocumentKeyValueList: View {
    let document: Document
    
    var body: some View {
        ForEach(Array(document.keys.sorted()), id: \.self) { key in
            let value = document[key]
            
            KeyValueRow(
                formattedPrimitive: document.formatValue(value),
                key: key
            )
        }
    }
}

struct KeyValueRow: View {
    let formattedPrimitive: FormattedPrimitive
    let key: String
    
    var body: some View {
        HStack {
            Text("\(key):")
                .foregroundColor(.white)
                .font(.system(.body, design: .monospaced))
            Text(formattedPrimitive.value)
                .foregroundColor(formattedPrimitive.color)
                .font(.system(.body, design: .monospaced))
        }
    }
}

struct HoverActionButtons: View {
    let isVisible: Bool
    
    var body: some View {
        HStack(spacing: 2) {
            ActionButton(
                systemName: "applepencil",
                action: {},
                fontWeight: .black
            )
            ActionButton(systemName: "doc.on.doc", action: {})
            ActionButton(systemName: "trash", action: {})
        }
        .opacity(isVisible ? 0.5 : 0)
        .transition(.opacity)
        .padding(8)
    }
}

struct ActionButton: View {
    let systemName: String
    let action: () -> Void
    var fontWeight: Font.Weight = .regular  // Default weight
    
    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .fontWeight(fontWeight)
                .foregroundColor(.white)
        }
        .buttonStyle(.compactAccessory(horizontal: 6))
    }
}

extension View {
    func cardStyle(isHovered: Bool) -> some View {
        self.overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
        )
        .cornerRadius(8)
    }
}
