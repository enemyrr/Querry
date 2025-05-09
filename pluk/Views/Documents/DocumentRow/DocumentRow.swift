//
//  DocumentDetails.swift
//  Collection
//
//  Created by Fauzaan on 12/31/24.
//
import SwiftUI
import MongoKitten
import SwiftData

// MARK: - Document Details
struct DocumentRow: View {
    @State var viewModel: DocumentRowViewModel
    @State private var isCardHovered = false
    
    var body: some View {
        let pendingAction = viewModel.getPendingAction()
        let showActionButton = isCardHovered || pendingAction == .update
        
        Group {
            ZStack(alignment: .bottomTrailing) {
                VStack(alignment: .leading, spacing: 2) {
                    if pendingAction == .update {
                        DocumentEditView(viewModel: viewModel)
                    } else {
                        DocumentKeyValueList(
                            fields: viewModel.document.fields
                        )
                        .padding()
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    ZStack {
                        Color(.controlColor).opacity(0.15)
                        RoundedRectangle(cornerRadius: 8)
                            .fill(
                                .linearGradient(
                                    colors: [
                                        Color(.controlColor).opacity(0.1),
                                        Color(.controlColor).opacity(0.05),
                                        .clear,
                                    ],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .blendMode(.plusLighter)
                    }
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.clear, lineWidth: 1)
                )
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(pendingAction == .delete
                                ? Color.red.opacity(0.7)
                                : pendingAction
                                == .update
                                ? Color.orange.opacity(0.7)
                                : Color(.separatorColor),
                                lineWidth: 1
                               )
                        .shadow(color: pendingAction == .delete
                                ? Color.red
                                : pendingAction
                                == .update
                                ? Color.orange.opacity(0.8)
                                : Color.clear,
                                radius: 4,
                                x: 0,
                                y: 0
                               )
                )
                .cornerRadius(8)
                .cardStyle(isHovered: isCardHovered)
                
                HoverActionButtons(
                    isVisible: showActionButton,
                    onEdit: {
                        viewModel.togglePendingAction(.update)
                    },
                    onCopy: {
                        viewModel.copyDocumentJSON()
                    },
                    onDelete: {
                        viewModel.togglePendingAction(.delete)
                    },
                    onClone: {
                        viewModel.copyDocumentJSON()
                    },
                    showCopyFeedback: viewModel.showCopyFeedback,
                    pendingAction: viewModel.getPendingAction(),
                    onSave: {
                        Task {
                            await viewModel.documentListViewModel.commitPendingActions()
                        }
                    },
                    onCancel: {
                        viewModel.togglePendingAction(.update)
                    }
                )
            }
            .onHover { hovering in
                withAnimation(.easeInOut(duration: 0.2)) {
                    isCardHovered = hovering
                }
            }
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: pendingAction)
//        .simultaneousGesture(
//            TapGesture(count: 2)
//                .onEnded {
//                    viewModel.togglePendingAction(.update)
//                }
//        )
    }
}

// MARK: - Document Key-Value List
struct DocumentKeyValueList: View {
    var fields: [FormattedDocument.FormattedField]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(fields, id: \.key) { field in
                RecursiveKeyValueRow(
                    formattedPrimitive: field.formattedValue,
                    key: field.key,
                    value: field.rawValue,
                    nestedFields: field.nestedFields
                )
                .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

// MARK: - Key-Value Views
struct KeyValueRow: View {
    let key: String
    let formattedValue: FormattedPrimitive
    
    private static let monoFont = Font.system(.body, design: .monospaced)
    
    @State private var isHoveredKey = false
    @State private var isHoveredValue = false
    
    var body: some View {
        HStack(alignment: .top, spacing: 2) {
            // Key section
            HStack(spacing: 0) {
                Text(key)
                    .font(Self.monoFont)
                    .foregroundColor(.primary)
                    .textSelection(.enabled)
                
                Text(":")
                    .font(Self.monoFont)
                    .foregroundColor(.primary)
            }
            .padding(.horizontal, 4)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(isHoveredKey ? Color.gray.opacity(0.2) : Color.clear)
            )
            .onHover { hovering in
                if isHoveredKey != hovering {
                    isHoveredKey = hovering
                }
            }
            
            Text(formattedValue.value)
                .font(Self.monoFont)
                .foregroundColor(formattedValue.color)
                .padding(.horizontal, 4)
                .background(
                    RoundedRectangle(cornerRadius: 4)
                        .fill(isHoveredValue ? Color.gray.opacity(0.2) : Color.clear)
                )
                .onHover { hovering in
                    if isHoveredValue != hovering {
                        isHoveredValue = hovering
                    }
                }
                .textSelection(.enabled)
        }
        .fixedSize(horizontal: false, vertical: true)
    }
}

struct ExpandableHeader: View {
    let key: String
    let isExpanded: Bool
    @Binding var isHoveredKey: Bool
    
    // Static font for better performance
    private static let monoFont = Font.system(.body, design: .monospaced)
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                .font(.system(size: 10))
                .foregroundColor(.gray)
                .padding(.leading, 4)
            
            Text("\(key):")
                .font(Self.monoFont)
                .foregroundColor(.primary)
                .padding(.horizontal, 4)
                .background(
                    RoundedRectangle(cornerRadius: 4)
                        .fill(isHoveredKey ? Color.gray.opacity(0.2) : Color.clear)
                )
                .onHover { hovering in
                    isHoveredKey = hovering
                }
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

// MARK: - Optimized ExpandableValueView
struct ExpandableValueView: View {
    let formattedPrimitive: FormattedPrimitive
    let key: String
    let nestedFields: [FormattedDocument.FormattedField]?
    
    private static let monoFont = Font.system(.body, design: .monospaced)
    
    @State private var isExpanded = false
    @State private var isHoveredKey = false
    @State private var isHoveredValue = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            // Header row with toggle
            HStack(spacing: 2) {
                // Expandable header
                ExpandableHeader(
                    key: key,
                    isExpanded: isExpanded,
                    isHoveredKey: $isHoveredKey
                )
                
                // Value display
                Text(formattedPrimitive.value)
                    .font(Self.monoFont)
                    .foregroundColor(formattedPrimitive.color)
                    .padding(.horizontal, 4)
                    .background(
                        RoundedRectangle(cornerRadius: 4)
                            .fill(isHoveredValue ? Color.gray.opacity(0.2) : Color.clear)
                    )
                    .onHover { hovering in
                        if isHoveredValue != hovering {
                            isHoveredValue = hovering
                        }
                    }
            }
            .contentShape(Rectangle())
            .onTapGesture {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isExpanded.toggle()
                }
            }
            
            // Nested fields - only create when expanded
            if isExpanded, let fields = nestedFields {
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(fields, id: \.key) { field in
                        RecursiveKeyValueRow(
                            formattedPrimitive: field.formattedValue,
                            key: field.key,
                            value: field.rawValue,
                            nestedFields: field.nestedFields
                        )
                        .padding(.leading, 16)
                        .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
        .fixedSize(horizontal: false, vertical: true)
    }
}

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
                if isHovered != hovering {
                    isHovered = hovering
                }
            }
    }
}

// MARK: - Action confirmation
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
