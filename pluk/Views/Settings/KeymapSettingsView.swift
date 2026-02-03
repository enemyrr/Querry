//
//  KeymapSettingsView.swift
//  Pluk
//

import SwiftUI

struct KeymapSettingsView: View {
    var body: some View {
        Form {
            queryExecutionSection
            dataTableSection
            navigationSection
            viewSection
            aiFeaturesSection
        }
        .formStyle(.grouped)
    }

    private var queryExecutionSection: some View {
        Section("Query Execution") {
            KeyboardShortcutRow(action: "Run Query", shortcut: "⌘ Return")
            KeyboardShortcutRow(action: "Refresh", shortcut: "⌘ R")
        }
    }

    private var dataTableSection: some View {
        Section("Data Table") {
            KeyboardShortcutRow(action: "Insert Row", shortcut: "⌘ I")
            KeyboardShortcutRow(action: "Delete Row", shortcut: "⌫")
            KeyboardShortcutRow(action: "Edit / Quick Look", shortcut: "⌘ Return")
            KeyboardShortcutRow(action: "Save Changes", shortcut: "⌘ S")
            KeyboardShortcutRow(action: "Copy", shortcut: "⌘ C")
        }
    }

    private var navigationSection: some View {
        Section("Navigation") {
            KeyboardShortcutRow(action: "Find Tables", shortcut: "⌘ P")
            KeyboardShortcutRow(action: "New Connection", shortcut: "⌘ ⇧ N")
            KeyboardShortcutRow(action: "Previous Page", shortcut: "⌘ ←")
            KeyboardShortcutRow(action: "Next Page", shortcut: "⌘ →")
        }
    }

    private var viewSection: some View {
        Section("View") {
            KeyboardShortcutRow(action: "Toggle Sidebar", shortcut: "⌘ [")
            KeyboardShortcutRow(action: "Toggle Row Details", shortcut: "⌘ ]")
            KeyboardShortcutRow(action: "Enter Full Screen", shortcut: "⌃ ⌘ F")
        }
    }

    private var aiFeaturesSection: some View {
        Section("AI") {
            KeyboardShortcutRow(action: "AI Command", shortcut: "⌘ K")
        }
    }
}

struct KeyboardShortcutRow: View {
    let action: String
    let shortcut: String

    var body: some View {
        HStack {
            Text(action)
            Spacer()
            Text(shortcut)
                .font(.system(.body, design: .monospaced))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(.quaternary)
                .clipShape(.rect(cornerRadius: 4))
        }
    }
}

#Preview {
    KeymapSettingsView()
        .frame(width: 500, height: 500)
}
