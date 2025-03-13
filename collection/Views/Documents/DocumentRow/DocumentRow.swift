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
        
        // Set up callback to refresh parent view
        self.viewModel.onDocumentChanged = {
            Task {
                await parentViewModel.loadDocuments()
            }
        }
    }
    
    var body: some View {
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
                    .stroke(.separator, lineWidth: 1)
            )
            .cornerRadius(8)
            .cardStyle(isHovered: isCardHovered)
            
            HoverActionButtons(
                isVisible: isCardHovered,
                onEdit: { viewModel.editDocument() },
                onCopy: { viewModel.copyDocumentJSON() },
                onDelete: {
                    Task {
                        await viewModel.deleteDocument()
                    }
                },
                onClone: { viewModel.copyDocumentJSON() },
                showCopyFeedback: viewModel.showCopyFeedback
            )
        }
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.2)) {
                isCardHovered = hovering
            }
        }
        .overlay(
            Group {
                if viewModel.isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color.black.opacity(0.1))
                }
            }
        )
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

private extension View {
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
