//
//  DocumentDetails.swift
//  Collection
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
                .stroke(Color.gray.opacity(0.3), lineWidth: 0)
        )
        .cornerRadius(10)
    }
}

// MARK: - Document Details
struct DocumentDetails: View {
    let document: FormattedDocument
    @State private var isCardHovered = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            DocumentKeyValueList(document: document)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.controlColor).opacity(0.1))
        .cornerRadius(8)
        //        .cardStyle(isHovered: isCardHovered)
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
    let document: FormattedDocument
    
    var body: some View {
        ForEach(document.fields, id: \.key) { field in  // Changed to use fields array
            RecursiveKeyValueRow(
                formattedPrimitive: field.formattedValue,
                key: field.key,
                value: field.rawValue,
                nestedFields: field.nestedFields
            )
        }
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

struct RecursiveKeyValueRow: View {
    let formattedPrimitive: FormattedPrimitive
    let key: String
    let value: Primitive?
    let nestedFields: [FormattedDocument.FormattedField]?
    
    var body: some View {
        Group {
            if formattedPrimitive.isExpandable {
                ExpandableValueView(
                    formattedPrimitive: formattedPrimitive,
                    key: key,
                    nestedFields: nestedFields
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

// MARK: - Optimized ExpandableValueView
struct ExpandableValueView: View {
    let formattedPrimitive: FormattedPrimitive
    let key: String
    let nestedFields: [FormattedDocument.FormattedField]?
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
            
            if isExpanded, let fields = nestedFields {
                LazyVStack(alignment: .leading, spacing: 2) {
                    ForEach(fields, id: \.key) { field in
                        RecursiveKeyValueRow(
                            formattedPrimitive: field.formattedValue,
                            key: field.key,
                            value: field.rawValue,
                            nestedFields: field.nestedFields
                        )
                        .padding(.leading, 16)
                    }
                }
                .transition(.opacity)
            }
        }
    }
}
