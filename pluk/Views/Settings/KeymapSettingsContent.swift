import Foundation

struct KeymapShortcutItem: Identifiable, Hashable {
    let action: String
    let shortcut: String

    var id: String { action }
}

struct KeymapShortcutSection: Identifiable, Hashable {
    let title: String
    let items: [KeymapShortcutItem]

    var id: String { title }
}

enum KeymapSettingsContent {
    static let sections: [KeymapShortcutSection] = [
        KeymapShortcutSection(
            title: "Query Execution",
            items: [
                KeymapShortcutItem(action: "Run Query", shortcut: "⌘ Return"),
                KeymapShortcutItem(action: "Refresh", shortcut: "⌘ R"),
            ]
        ),
        KeymapShortcutSection(
            title: "Data Table",
            items: [
                KeymapShortcutItem(action: "Insert Row", shortcut: "⌘ I"),
                KeymapShortcutItem(action: "Delete Row", shortcut: "⌫"),
                KeymapShortcutItem(action: "Edit / Quick Look", shortcut: "⌘ Return"),
                KeymapShortcutItem(action: "Save Changes", shortcut: "⌘ S"),
                KeymapShortcutItem(action: "Copy", shortcut: "⌘ C"),
            ]
        ),
        KeymapShortcutSection(
            title: "Navigation",
            items: [
                KeymapShortcutItem(action: "Find Tables", shortcut: "⌘ P"),
                KeymapShortcutItem(action: "New Connection", shortcut: "⌘ ⇧ N"),
                KeymapShortcutItem(action: "Previous Page", shortcut: "⌘ ←"),
                KeymapShortcutItem(action: "Next Page", shortcut: "⌘ →"),
            ]
        ),
        KeymapShortcutSection(
            title: "View",
            items: [
                KeymapShortcutItem(action: "Toggle Sidebar", shortcut: "⌘ ["),
                KeymapShortcutItem(action: "Toggle Row Details", shortcut: "⌘ ]"),
                KeymapShortcutItem(action: "Enter Full Screen", shortcut: "⌃ ⌘ F"),
            ]
        ),
        KeymapShortcutSection(
            title: "AI",
            items: [
                KeymapShortcutItem(action: "AI Command", shortcut: "⌘ K"),
            ]
        ),
    ]
}
