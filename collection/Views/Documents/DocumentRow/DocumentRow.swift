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
    var viewModel: DocumentRowViewModel
    @State private var isCardHovered = false
    
    var body: some View {
        Group {
            ZStack(alignment: .bottomTrailing) {
                VStack(alignment: .leading, spacing: 2) {
                    let isEditing = viewModel.getPendingAction() == .update
                    DocumentKeyValueList(
                        fields: viewModel.document.fields,
                        isEditing: isEditing,
                        onUpdateField: { key, value in
                            viewModel.updateField(key: key, value: value)
                        }
                    )
                    .id(viewModel.document.hashValue)
                }
                .padding()
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
                        .stroke(
                            viewModel.getPendingAction()
                            == .delete
                            ? Color.red.opacity(0.7)
                            : viewModel.getPendingAction()
                            == .update
                            ? Color.orange.opacity(0.7)
                            : Color(.separatorColor),
                            lineWidth: 1
                        )
                        .shadow(
                            color: viewModel.getPendingAction()
                            == .delete
                            ? Color.red
                            : viewModel.getPendingAction()
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
                    isVisible: isCardHovered || viewModel.getPendingAction() == .update,
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
    }
}

// MARK: - Document Key-Value List
struct DocumentKeyValueList: View {
    var fields: [FormattedDocument.FormattedField]
    var isEditing: Bool
    var onUpdateField: (String, String) -> Void
    var onCancelEdit: (() -> Void)?
    
    @State private var editedValues: [String: String] = [:]
    
    var body: some View {
        ForEach(fields, id: \.key) { field in
            RecursiveKeyValueRow(
                formattedPrimitive: field.formattedValue,
                key: field.key,
                value: field.rawValue,
                nestedFields: field.nestedFields,
                isEditing: isEditing,
                editingValue: bindingForKey(field.key, field.formattedValue)
            )
        }
        .onChange(of: isEditing) { oldValue, newValue in
                    // When switching from editing to non-editing mode, check if this was a cancel
                    if oldValue == true && newValue == false && onCancelEdit != nil {
                        // Reset all edited values
                        editedValues = [:]
                    }
                }
    }
    
    private func bindingForKey(_ key: String, _ value: FormattedPrimitive) -> Binding<String> {
        return Binding(
            get: {
                editedValues[key] ?? value.value
            },
            set: { newValue in
                editedValues[key] = newValue
                onUpdateField(key, newValue)
            }
        )
    }
    
    private func formattedValueFor(key: String) -> String {
        if let field = fields.first(where: { $0.key == key }) {
            return field.formattedValue.value
        }
        return ""
    }
    
        func resetEditedValues() {
            editedValues = [:]
        }
}

// MARK: - Key-Value Views
struct KeyValueRow: View {
    let key: String
    let formattedValue: FormattedPrimitive
    var isEditing: Bool
    @Binding var editingValue: String
    @State private var isHoveredKey = false
    @State private var isHoveredValue = false
    @FocusState private var focusedField: String?
    
    var body: some View {
        HStack(alignment: .top, spacing: 2) {
            HStack(spacing: 0) {
                Text("\(key)")
                    .monospacedStyle()
                    .textSelection(.enabled)
                
                Text(":")
                    .monospacedStyle()
            }
            .hoverable(isHovered: $isHoveredKey)
            
            if isEditing {
                HStack(alignment: .top) {
                    TextField("", text: $editingValue, axis: .vertical)
                        .monospacedStyle(color: formattedValue.color)
                        .padding(.horizontal, 4)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color.black.opacity(0.2))
                                .opacity(focusedField == key ? 1 : 0)
                        )
                        .focused($focusedField, equals: key)
                        .textFieldStyle(.plain)
                        .lineLimit(1...10)
                    
                    Text(formattedValue.type)
                        .monospacedStyle(color: Color(.gray).opacity(0.5))
                        .frame(width: 80, alignment: .leading)
                }
            } else {
                Text(formattedValue.value)
                    .monospacedStyle(color: formattedValue.color)
                    .hoverable(isHovered: $isHoveredValue)
                    .textSelection(.enabled)
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

struct RecursiveKeyValueRow: View {
    let formattedPrimitive: FormattedPrimitive
    let key: String
    let value: Primitive?
    let nestedFields: [FormattedDocument.FormattedField]?
    var isEditing: Bool
    @Binding var editingValue: String
    @State private var nestedEditingValues: [String: String] = [:]
    
    var body: some View {
        Group {
            if formattedPrimitive.isExpandable {
                ExpandableValueView(
                    formattedPrimitive: formattedPrimitive,
                    key: key,
                    nestedFields: nestedFields,
                    isEditing: isEditing,
                    editingValue: $editingValue
                )
            } else {
                KeyValueRow(
                    key: key,
                    formattedValue: formattedPrimitive,
                    isEditing: isEditing,
                    editingValue: $editingValue
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
    var isEditing: Bool
    @Binding var editingValue: String
    @State private var isExpanded = false
    @State private var isHoveredKey = false
    @State private var isHoveredValue = false
    @State private var nestedEditingValues: [String: String] = [:]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 2) {
                ExpandableHeader(
                    key: key,
                    isExpanded: isExpanded,
                    isHoveredKey: $isHoveredKey
                )
                
                if isEditing {
                    TextField("", text: $editingValue)
                        .monospacedStyle(color: formattedPrimitive.color)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .frame(maxWidth: 300)
                } else {
                    Text(formattedPrimitive.value)
                        .monospacedStyle(color: formattedPrimitive.color)
                        .hoverable(isHovered: $isHoveredValue)
                }
            }
            .contentShape(Rectangle())
            .onTapGesture {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isExpanded.toggle()
                }
            }
            
            if isExpanded, let fields = nestedFields {
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(fields, id: \.key) { field in
                        RecursiveKeyValueRow(
                            formattedPrimitive: field.formattedValue,
                            key: field.key,
                            value: field.rawValue,
                            nestedFields: field.nestedFields,
                            isEditing: isEditing,
                            editingValue: bindingForNestedKey(field.key)
                        )
                        .padding(.leading, 16)
                    }
                }
                .transition(.opacity)
            }
        }
    }
    
    private func bindingForNestedKey(_ key: String) -> Binding<String> {
        return Binding(
            get: {
                return nestedEditingValues[key]
                ?? (fields?.first(where: { $0.key == key })?.formattedValue
                    .value ?? "")
            },
            set: { newValue in
                nestedEditingValues[key] = newValue
            }
        )
    }
    
    private var fields: [FormattedDocument.FormattedField]? {
        return nestedFields
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
                withAnimation(.easeInOut(duration: 0.15)) {
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
