//
//  HoverActionButtons.swift
//  Collection
//
//  Created by Fauzaan on 3/8/25.
//
import SwiftUI

struct HoverActionButtons: View {
    let isVisible: Bool
    let onEdit: () -> Void
    let onCopy: () -> Void
    let onClone: () -> Void
    let onDelete: () -> Void
    let showCopyFeedback: Bool
    
    init(
        isVisible: Bool,
        onEdit: @escaping () -> Void,
        onCopy: @escaping () -> Void,
        onDelete: @escaping () -> Void,
        onClone: @escaping () -> Void,
        showCopyFeedback: Bool = false
    ) {
        self.isVisible = isVisible
        self.onEdit = onEdit
        self.onCopy = onCopy
        self.onDelete = onDelete
        self.onClone = onClone
        self.showCopyFeedback = showCopyFeedback
    }
    
    var body: some View {
        HStack(spacing: .zero) {
            ActionButton(
                systemName: "highlighter",
                action: onEdit,
                tooltipText: "Edit Document"
            )
            .customHelp("Edit Document", position: .top, spacing: 4)

            ActionButton(
                systemName: showCopyFeedback ? "checkmark" : "clipboard",
                action: onCopy,
                tooltipText: "Copy to clipboard"
            )
            .customHelp("Copy to clipboard", position: .top, spacing: 4)
            
//            TODO: Implement later
//            ActionButton(
//                systemName: "document.on.document",
//                action: onClone,
//                tooltipText: "Clone Document"
//            )
//            .customHelp("Clone Document", position: .top, spacing: 4)

            ActionButton(
                systemName: "trash",
                action: onDelete,
                tooltipText: "Remove Document"
            )
            .customHelp("Remove Document", position: .top, alignment: .right, spacing: 4)
        }
        .modifier(GlassBackgroundStyle())
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(.separator, lineWidth: 1)
        )
        .opacity(isVisible ? 1 : 0)
        .animation(.easeInOut(duration: 0.2), value: isVisible)
        .padding(.bottom, -4)
        .padding(.trailing, 16)
    }
}

// You'll need to update your DocumentRow to use this:
struct DocumentRowExample: View {
    @State private var viewModel: DocumentRowViewModel
    @State private var isCardHovered = false
    
    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            // Your document content here
            
            HoverActionButtons(
                isVisible: isCardHovered,
                onEdit: { viewModel.editDocument() },
                onCopy: { viewModel.copyDocumentJSON() },
                onDelete: {
                    Task {
                        await viewModel.deleteDocument()
                    }
                },
                onClone: {
                    // Implement cloning functionality
                    // For example: viewModel.cloneDocument()
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

struct ActionButton: View {
    let systemName: String
    let action: () -> Void
    let tooltipText: String
    
    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 10))
                .fontWeight(.bold)
                .foregroundColor(.gray)
                .frame(height: 16)
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 5)
        .padding(.vertical, 3)
    }
}

