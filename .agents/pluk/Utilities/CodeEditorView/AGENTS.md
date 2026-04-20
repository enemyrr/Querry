# Utilities/CodeEditorView/

## Purpose

TextKit 2-based code editor subsystem. Provides syntax-highlighted code editing with line numbers, gutter, minimap, and inline messages. **Treat as a blackbox** — use the public API, don't modify internals unless fixing bugs.

## Public API

```swift
CodeEditor(
    text: Binding<String>,
    position: Binding<Position>,
    messages: Binding<Set<TextLocated<Message>>>,
    language: LanguageConfiguration
)
```

### Position

Tracks selections and scroll state:
```swift
struct Position: Equatable {
    var selections: [NSRange]
    var verticalScrollPosition: CGFloat
}
```

### Messages

Inline messages displayed in the gutter and as popovers:
```swift
struct Message {
    let category: Category  // .error, .warning, .info, .hole, .live
    let text: String
}
// Wrapped in TextLocated<Message> for line/column positioning
```

### Theme

Configurable appearance with 20+ token-type colors:
```swift
struct Theme: Identifiable {
    static let defaultDark: Theme
    static let defaultLight: Theme
    // Colors: text, background, currentLine, selection, cursor,
    //         keyword, string, number, comment, type, function, etc.
}
```

## Internal Architecture (For Reference Only)

| File | Purpose |
|------|---------|
| `CodeEditor.swift` | SwiftUI wrapper, coordinator pattern |
| `CodeView.swift` | NSTextView subclass — core editor |
| `CodeStorage.swift` | NSTextStorage subclass — syntax highlighting, bracket matching |
| `CodeStorageDelegate.swift` | Text storage delegate — syntax coloring |
| `CodeEditing.swift` | Editing commands (duplicate, re-indent, shift, comment) |
| `CodeActions.swift` | Info popovers, query results display |
| `Theme.swift` | Theme definition with font extraction |
| `GutterView.swift` | Line number gutter with message indicators |
| `MessageViews.swift` | Inline message rendering |
| `LineMap.swift` | Line info tracking |
| `LanguageSupport/Mongodb.swift` | MongoDB syntax support |

## Invariants

- Built on TextKit 2 (NSTextView, NSTextStorage, NSTextLayoutManager) — NOT WebKit
- Theme is `Identifiable` — changing any property invalidates the UUID, triggering re-render
- `CodeView` supports minimap via a secondary `CodeView` instance
- Font defaults to SF Mono with configurable weights from theme
- The editor already has a completion popup and async completion flow wired through `LanguageService` (`CodeActions.swift`, `CodeEditorViewController.swift`, `CodeView.swift`). If SQL autocomplete appears missing in a feature, the likely gap is the language-service/provider hookup, not the picker UI.
- `LanguageService.completionTriggerCharacters` exists for auto-trigger characters such as `.` and space, but this path was not previously honored in `CodeActions.swift`. If trigger-character completions stop working, inspect `CodeView.considerCompletionFor(...)` before changing popup UI code.
- `LanguageSupport` is not concurrency-audited enough to safely make a custom `LanguageService` implementation `@MainActor`. For editor integrations that depend on `@MainActor` app state such as `ConnectionInstance`, keep the service itself nonisolated, use `@preconcurrency import LanguageSupport`, and hop to `@MainActor` only for the data fetches.
- `CompletionPanel` is an `NSPanel`, so its root `contentView` should behave like a window root, not an Auto Layout child. Setting the root container’s `translatesAutoresizingMaskIntoConstraints = false` can collapse the popup until only overlay scrollers are visible.

## Anti-Patterns

- Do NOT modify `CodeStorage` or `CodeStorageDelegate` without understanding TextKit 2 layout
- Do NOT create `CodeView` directly — use the `CodeEditor` SwiftUI wrapper
- Do NOT add new language support files without following the `LanguageConfiguration` pattern
- Do NOT set theme properties after initialization without expecting a full re-render (UUID change)
