//
//  DocumentDetails.swift
//  documentPlus
//
//  Created by Fauzaan on 12/31/24.
//
import SwiftUI
import SwiftData
import MongoKitten

// MARK: - Common Styles and Modifiers
struct HoverableText: ViewModifier {
    @Binding var isHovered: Bool
    
    func body(content: Content) -> some View {
        content
            .padding(.horizontal, 4)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(isHovered ? Color.gray.opacity(0.2) : Color.clear)
            )
            .onHover { hovering in
                withAnimation(.easeInOut(duration: 0.15)) {
                    isHovered = hovering
                }
            }
    }
}

extension View {
    func hoverable(isHovered: Binding<Bool>) -> some View {
        modifier(HoverableText(isHovered: isHovered))
    }
    
    func monospacedStyle(color: Color = .primary) -> some View {
        self.font(.system(.body, design: .monospaced))
            .foregroundColor(color)
    }
    
    func cardStyle(isHovered: Bool) -> some View {
        self.overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
        )
        .cornerRadius(8)
    }
}

// MARK: - Document Details
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
//        .overlay(HoverActionButtons(isVisible: isCardHovered), alignment: .topTrailing)
//        .onHover { hovering in
//            withAnimation(.easeInOut(duration: 0.2)) {
//                isCardHovered = hovering
//            }
//        }
    }
}

// MARK: - Document Key-Value List
struct DocumentKeyValueList: View {
    let document: Document
    
    var body: some View {
        ForEach(document.keys, id: \.self) { key in
            if let value = document[key] {
                let formatted = document.formatValue(value)
                RecursiveKeyValueRow(
                    formattedPrimitive: formatted,
                    key: key,
                    value: value
                )
            }        }
    }
}

// MARK: - Key-Value Views
struct KeyValueRow: View {
    let key: String
    let formattedValue: FormattedPrimitive
    @State private var isHoveredKey = false
    @State private var isHoveredValue = false
    
    var body: some View {
        HStack(spacing: 2) {
            Text("\(key):")
                .monospacedStyle()
                .hoverable(isHovered: $isHoveredKey)
            
            Text(formattedValue.value)
                .monospacedStyle(color: formattedValue.color)
                .hoverable(isHovered: $isHoveredValue)
        }
    }
}

struct ExpandableValueView: View {
    let formattedPrimitive: FormattedPrimitive
    let key: String
    let value: Primitive
    @State private var isExpanded = false
    @State private var isHoveredKey = false
    @State private var isHoveredValue = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 2) {
                ExpandableHeader(
                    key: key,
                    isExpanded: isExpanded,
                    isHoveredKey: $isHoveredKey
                )
                
                Text(formattedPrimitive.value)
                    .monospacedStyle(color: formattedPrimitive.color)
                    .hoverable(isHovered: $isHoveredValue)
            }
            .contentShape(Rectangle())
            .onTapGesture {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isExpanded.toggle()
                }
            }
            
            if isExpanded {
                RecursiveDocumentView(value: value)
                    .padding(.leading, 16)
            }
        }
    }
}

struct ExpandableHeader: View {
    let key: String
    let isExpanded: Bool
    @Binding var isHoveredKey: Bool
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                .font(.system(size: 10))
                .foregroundColor(.gray)
                .padding(.leading, 4)
            
            Text("\(key):")
                .monospacedStyle()
                .hoverable(isHovered: $isHoveredKey)
        }
    }
}

// MARK: - Recursive Views
struct RecursiveDocumentView: View {
    let value: Primitive
    
    var body: some View {
        Group {
            switch value {
            case let array as [Primitive]:
                ForEach(Array(array.enumerated()), id: \.offset) { index, item in
                    let formatted = Document().formatValue(item)
                    RecursiveKeyValueRow(
                        formattedPrimitive: formatted,
                        key: String(index),
                        value: item
                    )
                }
                
            case let doc as Document:
                ForEach(Array(doc.keys), id: \.self) { key in
                    if let value = doc[key] {
                        let formatted = doc.formatValue(value)
                        RecursiveKeyValueRow(
                            formattedPrimitive: formatted,
                            key: key,
                            value: value
                        )
                    }
                }
                
            default:
                EmptyView()
            }
        }
    }
}

struct RecursiveKeyValueRow: View {
    let formattedPrimitive: FormattedPrimitive
    let key: String
    let value: Primitive
    
    var body: some View {
        Group {
            if formattedPrimitive.isExpandable {
                ExpandableValueView(
                    formattedPrimitive: formattedPrimitive,
                    key: key,
                    value: value
                )
            } else {
                KeyValueRow(
                    key: key,
                    formattedValue: formattedPrimitive
                )
            }
        }
    }
}

// MARK: - Action Buttons
struct HoverActionButtons: View {
    let isVisible: Bool
    private let buttons: [(systemName: String, weight: Font.Weight, action: () -> Void)] = [
        ("applepencil", .black, {}),
        ("doc.on.doc", .regular, {}),
        ("trash", .regular, {})
    ]
    
    var body: some View {
        HStack(spacing: 2) {
            ForEach(buttons, id: \.systemName) { button in
                ActionButton(
                    systemName: button.systemName,
                    action: button.action,
                    fontWeight: button.weight
                )
            }
        }
        .opacity(isVisible ? 0.5 : 0)
        .transition(.opacity)
        .padding(8)
    }
}

struct ActionButton: View {
    let systemName: String
    let action: () -> Void
    var fontWeight: Font.Weight = .regular
    
    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .fontWeight(fontWeight)
                .foregroundColor(.white)
        }
        .buttonStyle(.compactAccessory(horizontal: 6))
    }
}
