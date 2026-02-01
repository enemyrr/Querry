//
//  QuickLookContentView.swift
//  Pluk
//
//  Created by Claude on 1/29/26.
//

import SwiftUI

struct QuickLookContentView: View {
    let fieldName: String
    let dataType: String
    let initialContent: String
    let onSave: (String) -> Void
    let onDismiss: () -> Void

    @State private var editedContent: String
    @State private var hasChanges = false
    @FocusState private var isTextEditorFocused: Bool

    init(
        fieldName: String,
        dataType: String,
        content: String,
        onSave: @escaping (String) -> Void,
        onDismiss: @escaping () -> Void
    ) {
        self.fieldName = fieldName
        self.dataType = dataType
        self.initialContent = content
        self.onSave = onSave
        self.onDismiss = onDismiss
        _editedContent = State(initialValue: Self.prettyPrintJSON(content))
    }

    private static func looksLikeJSON(_ content: String) -> Bool {
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        return (trimmed.hasPrefix("{") && trimmed.hasSuffix("}")) ||
               (trimmed.hasPrefix("[") && trimmed.hasSuffix("]"))
    }

    private var isJSON: Bool {
        Self.looksLikeJSON(editedContent)
    }

    private static func prettyPrintJSON(_ string: String) -> String {
        guard looksLikeJSON(string),
              let data = string.data(using: .utf8),
              let jsonObject = try? JSONSerialization.jsonObject(with: data),
              let prettyData = try? JSONSerialization.data(withJSONObject: jsonObject, options: [.prettyPrinted, .sortedKeys]),
              let result = String(data: prettyData, encoding: .utf8) else {
            return string
        }
        return result
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            editorView
                .frame(minHeight: 100, maxHeight: 350)

            footerView
        }
        .padding([.horizontal, .top], 20)
        .padding(.bottom, 16)
        .frame(width: 450)
        .onAppear {
            isTextEditorFocused = true
        }
    }

    private var editorView: some View {
        TextEditor(text: $editedContent)
            .font(.system(.body, design: .monospaced))
            .scrollContentBackground(.hidden)
            .padding(12)
            .focused($isTextEditorFocused)
            .onChange(of: editedContent) { _, newValue in
                hasChanges = (newValue != initialContent) &&
                             (newValue != Self.prettyPrintJSON(initialContent))
            }
            .onKeyPress(.escape) {
                onDismiss()
                return .handled
            }
            .onKeyPress(.return, phases: .down) { keyPress in
                if keyPress.modifiers.contains(.command) && hasChanges {
                    saveChanges()
                    return .handled
                }
                return .ignored
            }
            .background(Color(.controlColor).opacity(0.3))
            .clipShape(.rect(cornerRadius: 12))
    }

    private var footerView: some View {
        HStack(spacing: 8) {
            if isJSON {
                Label("JSON", systemImage: "curlybraces")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button("Cancel") {
                onDismiss()
            }
            .compactMenuButtonStyle()

            Button {
                saveChanges()
            } label: {
                HStack(alignment: .center, spacing: 6) {
                    Text("Save")
                    Text("↩")
                        .baselineOffset(-2)
                        .foregroundStyle(.secondary)
                }
            }
            .compactPrimaryStyle()
            .disabled(!hasChanges)
        }
    }

    private func saveChanges() {
        let contentToSave = Self.compactJSON(editedContent)
        onSave(contentToSave)
        onDismiss()
    }

    private static func compactJSON(_ string: String) -> String {
        guard looksLikeJSON(string),
              let data = string.data(using: .utf8),
              let jsonObject = try? JSONSerialization.jsonObject(with: data),
              let compactData = try? JSONSerialization.data(withJSONObject: jsonObject),
              let result = String(data: compactData, encoding: .utf8) else {
            return string
        }
        return result
    }
}
