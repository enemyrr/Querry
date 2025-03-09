//
//  HoverActionButtons.swift
//  Collection
//
//  Created by Fauzaan on 3/8/25.
//
import SwiftUI

struct HoverActionButtons: View {
    let isVisible: Bool
    
    var body: some View {
        HStack(spacing: .zero) {
            ActionButton(
                systemName: "highlighter",
                action: {},
                tooltipText: "Edit Document"
            )
            .customHelp("Edit Document", position: .top, spacing: 4)

            ActionButton(
                systemName: "clipboard",
                action: {},
                tooltipText: "Copy to clipboard"
            )
            .customHelp("Copy to clipboard", position: .top, spacing: 4)

            ActionButton(
                systemName: "document.on.document",
                action: {},
                tooltipText: "Clone Document"
            )
            .customHelp("Clone Document", position: .top, spacing: 4)

            ActionButton(
                systemName: "trash",
                action: {},
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
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 5)
        .padding(.vertical, 3)
    }
}
