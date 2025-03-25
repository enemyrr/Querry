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



// MARK: - Document Details
struct DocumentRow: View {
    @State private var viewModel: DocumentRowViewModel
    @State private var isCardHovered = false
    
    init(document: FormattedDocument, parentViewModel: DocumentViewModel) {
        self._viewModel = State(initialValue:
                                    DocumentRowViewModel(
                                        document: document,
                                        connectionInstance: parentViewModel.instance,
                                        collectionName: parentViewModel.selectedTab.name
                                    )
        )
        
        // Set up callback to refresh parent view and update action tracking
        self.viewModel.onDocumentChanged = { [document] action in
            // Update the parent view model's tracking of document actions
            if let action = action {
                parentViewModel.addPendingAction(documentId: document.id, action: action)
            } else {
                parentViewModel.removePendingActions(for: document.id)
            }
        }
        
        // Initialize action state from parent view model
        for action in DocumentViewModel.DocumentAction.allCases {
//            if parentViewModel.hasPendingAction(documentId: document.id, action: action) {
//                self.viewModel.setPendingAction(action)
//                break
//            }
        }
    }
    
    var body: some View {
        Group {
            if !viewModel.isDeleted {
                ZStack(alignment: .bottomTrailing) {
                    VStack(alignment: .leading, spacing: 2) {
                        DocumentKeyValueList(document: viewModel.document)
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
                                            .clear
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
                                viewModel.pendingAction == .delete ?
                                    Color.red.opacity(0.7) :
                                    viewModel.pendingAction == .update ?
                                        Color.orange.opacity(0.7) :
                                        Color(.separatorColor),
                                lineWidth: 1
                            )
                            .shadow(
                                color: viewModel.pendingAction == .delete ?
                                    Color.red :
                                    viewModel.pendingAction == .update ?
                                        Color.orange.opacity(0.8) :
                                        Color.clear,
                                radius: 4,
                                x: 0,
                                y: 0
                            )
                    )
                    .cornerRadius(8)
                    .cardStyle(isHovered: isCardHovered)
                    
                    HoverActionButtons(
                        isVisible: isCardHovered,
                        onEdit: { 
                            viewModel.setPendingAction(.update)
                        },
                        onCopy: { viewModel.copyDocumentJSON() },
                        onDelete: {
                            viewModel.setPendingAction(.delete)
                        },
                        onClone: { viewModel.copyDocumentJSON() },
                        showCopyFeedback: viewModel.showCopyFeedback,
                        pendingAction: viewModel.pendingAction
                    )
                }
                .onHover { hovering in
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isCardHovered = hovering
                    }
                }
                // Removed action confirmation overlay for immediate actions
                .alert(
                    "Error",
                    isPresented: .constant(viewModel.errorMessage != nil),
                    actions: {
                        Button("OK") {
                            // Clear error on dismiss
                            // Ideally this would be handled via the ViewModel
                        }
                    },
                    message: {
                        if let errorMessage = viewModel.errorMessage {
                            Text(errorMessage)
                        }
                    }
                )
            }
        }
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
                VStack(alignment: .leading, spacing: 2) {
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

// MARK: - Action confirmation
struct ActionConfirmationOverlay: View {
    var onCancel: () -> Void
    var onConfirm: () -> Void
    var isLoading: Bool
    var action: DocumentViewModel.DocumentAction?
    var hasExistingAction: Bool
    
    var body: some View {
        ZStack {
            VisualEffectView(material: .popover, blendingMode: .withinWindow)
            
            VStack(spacing: 4) {
                Image(systemName: actionIcon)
                    .font(.system(size: 20))
                    .foregroundStyle(actionColor)
                    .padding(.bottom, 8)
                
                Text(titleText)
                    .font(.headline)
                    .fontWeight(.medium)
                
                Text(descriptionText)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.bottom, 8)
                
                
                // Action buttons
                HStack(spacing: 12) {
                    Button {
                        onCancel()
                    } label: {
                        Text("Cancel")
                            .font(.subheadline)
                            .frame(minWidth: 70)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(Color(.separatorColor).opacity(0.4))
                            .cornerRadius(6)
                    }
                    .buttonStyle(.plain)
                    .contentShape(Rectangle())
                    .keyboardShortcut(.escape)
                    
                    Button {
                        onConfirm()
                    } label: {
                        HStack {
                            if isLoading {
                                ProgressView()
                                    .controlSize(.mini)
                                    .tint(.white)
                            }
                            Text(hasExistingAction ? "Unmark" : "Mark")
                                .font(.subheadline)
                                .fontWeight(.medium)
                        }
                        .animation(.easeInOut(duration: 0.2), value: isLoading)
                        .frame(minWidth: 70)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .foregroundStyle(.white)
                        .background(isLoading ? actionColor.opacity(0.7) : actionColor)
                        .cornerRadius(6)
                    }
                    .buttonStyle(.plain)
                    .contentShape(Rectangle())
                    .keyboardShortcut(.return)
                    .disabled(isLoading)
                }
            }
            .padding(20)
        }
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(.separator, lineWidth: 1)
        )
        .cornerRadius(10)
        .transition(.opacity)
    }
    
    private var actionIcon: String {
        switch action {
        case .delete:
            return "trash"
        case .update:
            return "pencil"
        case .none:
            return "questionmark.circle"
        }
    }
    
    private var actionColor: Color {
        switch action {
        case .delete:
            return .red
        case .update:
            return .blue
        case .none:
            return .gray
        }
    }
    
    private var titleText: String {
        guard let action = action else { return "Action?" }
        
        switch action {
        case .delete:
            return hasExistingAction ? "Unmark from Deletion?" : "Mark for Deletion?"
        case .update:
            return hasExistingAction ? "Unmark from Update?" : "Mark for Update?"
        }
    }
    
    private var descriptionText: String {
        guard let action = action else { return "Choose an action for this document" }
        
        switch action {
        case .delete:
            return hasExistingAction ? 
                "This will remove the document from the deletion queue" : 
                "This will mark the document for deletion"
        case .update:
            return hasExistingAction ? 
                "This will remove the document from the update queue" : 
                "This will mark the document for update"
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
