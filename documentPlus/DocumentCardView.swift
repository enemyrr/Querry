//
//  DocumentView.swift
//  documentPlus
//
//  Created by Fauzaan on 12/31/24.
//
import SwiftUI
import SwiftData
import MongoKitten

struct DocumentCardView: View {
    let processedDoc: ProcessedDocument
    @State private var isCardHovered = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            DocumentKeyValueList(processedDoc: processedDoc)
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
    let processedDoc: ProcessedDocument
    
    var body: some View {
        ForEach(Array(processedDoc.originalDocument.keys), id: \.self) { key in
            KeyValueRow(key: key, value: processedDoc.formattedValues[key] ?? "", color: processedDoc.valueColors[key] ?? .white)
        }
    }
}

struct KeyValueRow: View {
    let key: String
    let value: String
    let color: Color
    
    var body: some View {
        HStack {
            Text("\(key):")
                .foregroundColor(.white)
                .font(.system(.body, design: .monospaced))
            Text(value)
                .foregroundColor(color)
                .font(.system(.body, design: .monospaced))
        }
    }
}

struct HoverActionButtons: View {
    let isVisible: Bool
    
    var body: some View {
        HStack(spacing: 8) {
            ActionButton(systemName: "pencil", action: {})
            ActionButton(systemName: "doc.on.doc", action: {})
            ActionButton(systemName: "trash", action: {})
        }
        .opacity(isVisible ? 1 : 0)
        .transition(.opacity)
        .padding(8)
    }
}

struct ActionButton: View {
    let systemName: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .foregroundColor(.white)
        }
        .buttonStyle(.borderless)
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
