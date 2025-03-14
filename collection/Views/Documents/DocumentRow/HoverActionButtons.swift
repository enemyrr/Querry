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
    let pendingAction: DocumentViewModel.DocumentAction?
    
    init(
        isVisible: Bool,
        onEdit: @escaping () -> Void,
        onCopy: @escaping () -> Void,
        onDelete: @escaping () -> Void,
        onClone: @escaping () -> Void,
        showCopyFeedback: Bool = false,
        pendingAction: DocumentViewModel.DocumentAction? = nil
    ) {
        self.isVisible = isVisible
        self.onEdit = onEdit
        self.onCopy = onCopy
        self.onDelete = onDelete
        self.onClone = onClone
        self.showCopyFeedback = showCopyFeedback
        self.pendingAction = pendingAction
    }
    
    var body: some View {
        HStack(spacing: .zero) {
            ActionButton(
                systemName: getActionIcon(for: .update),
                action: onEdit,
                tooltipText: getActionTooltip(for: .update),
                tintColor: getActionColor(for: .update)
            )
            .customHelp(getActionTooltip(for: .update), position: .top, spacing: 4)

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
                systemName: getActionIcon(for: .delete),
                action: onDelete,
                tooltipText: getActionTooltip(for: .delete),
                tintColor: getActionColor(for: .delete)
            )
            .customHelp(getActionTooltip(for: .delete), position: .top, alignment: .right, spacing: 4)
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
// Helper extension for action-related UI
extension HoverActionButtons {
    func getActionIcon(for action: DocumentViewModel.DocumentAction) -> String {
        if pendingAction == action {
            switch action {
            case .delete:
                return "trash.slash"
            case .update:
                return "pencil.slash"
            }
        } else {
            switch action {
            case .delete:
                return "trash"
            case .update:
                return "pencil"
            }
        }
    }
    
    func getActionTooltip(for action: DocumentViewModel.DocumentAction) -> String {
        if pendingAction == action {
            switch action {
            case .delete:
                return "Unmark for Deletion"
            case .update:
                return "Unmark for Update"
            }
        } else {
            switch action {
            case .delete:
                return "Mark for Deletion"
            case .update:
                return "Mark for Update"
            }
        }
    }
    
    func getActionColor(for action: DocumentViewModel.DocumentAction) -> Color {
        if pendingAction == action {
            switch action {
            case .delete:
                return .red
            case .update:
                return .blue
            }
        } else {
            return .gray
        }
    }
}

struct ActionButton: View {
    let systemName: String
    let action: () -> Void
    let tooltipText: String
    let tintColor: Color
    
    init(systemName: String, action: @escaping () -> Void, tooltipText: String, tintColor: Color = .gray) {
        self.systemName = systemName
        self.action = action
        self.tooltipText = tooltipText
        self.tintColor = tintColor
    }
    
    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 10))
                .fontWeight(.bold)
                .foregroundColor(tintColor)
                .frame(height: 16)
                .contentTransition(.symbolEffect(.replace.magic(fallback: .downUp.byLayer), options: .nonRepeating))
 
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 5)
        .padding(.vertical, 3)
    }
}

