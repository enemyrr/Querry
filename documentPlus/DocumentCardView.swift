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
    let document: Document
    @State private var isCardHovered = false
    
    // Helper function to determine the color based on value type
    private func formatValue(_ key: String) -> String {
        guard let value = document[key] else { return "null" }
        
        print(value)
        switch value {
        case let objectId as ObjectId:
            return "ObjectId('\(objectId.hexString)')"
        case let array as [Primitive]:
            return "Array (\(array.count))"
        case let date as Date:
            return date.ISO8601Format()
        case let bool as Bool:
            return bool.description
        case let doc as Document:
            return "Document {\(doc.count) fields}"
        case let double as Double:
            return String(double)
        case let int as Int32:
            return String(int)
        case let int as Int:
            return String(int)
        case let string as String:
            return string
        default:
            return String(describing: value)
        }
    }

    // Also update the getValueColor function
    private func getValueColor(_ value: Primitive?) -> Color {
        guard let value = value else { return .gray }
        
        switch value {
        case is Int, is Int32, is Int64, is Double:
            return .blue
        case is String:
            return .orange
        case is Bool:
            return .green
        case is [Primitive]:
            return .gray
        case is Document:
            return .purple
        case is Date:
            return .blue
        case is ObjectId:
            return .orange
        default:
            return .white
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            ForEach(Array(document.keys.sorted().enumerated()), id: \.element) { index, key in
                HStack {
                    Text("\(key):")
                        .foregroundColor(.white)
                        .font(.system(.body, design: .monospaced))
                    
                    Text(formatValue(key))
                        .foregroundColor(getValueColor(document[key]))
                        .font(.system(.body, design: .monospaced))
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(NSColor.windowBackgroundColor).opacity(0.1))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
        )
        .cornerRadius(8)
        .overlay(
            HStack(spacing: 8) {
                Button(action: { /* Edit action */ }) {
                    Image(systemName: "pencil")
                        .foregroundColor(.white)
                }
                .buttonStyle(.borderless)
                
                Button(action: { /* Clone action */ }) {
                    Image(systemName: "doc.on.doc")
                        .foregroundColor(.white)
                }
                .buttonStyle(.borderless)
                
                Button(action: { /* Delete action */ }) {
                    Image(systemName: "trash")
                        .foregroundColor(.white)
                }
                .buttonStyle(.borderless)
            }
            .opacity(isCardHovered ? 1 : 0)
            .transition(.opacity)
            .padding(8)
            , alignment: .topTrailing
        )
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.2)) {
                isCardHovered = hovering
            }
        }
    }
}
