import AppKit
import SwiftUI

@MainActor
final class QuickLookViewController: NSViewController {
    private let initialContent: String
    private let onSave: (String) -> Void
    private let onDismiss: () -> Void

    private var textView: NSTextView!
    private let buttonState = QuickLookButtonState()

    init(
        content: String,
        onSave: @escaping (String) -> Void,
        onDismiss: @escaping () -> Void
    ) {
        self.initialContent = content
        self.onSave = onSave
        self.onDismiss = onDismiss
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError()
    }

    override func loadView() {
        let container = NSView()

        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.borderType = .noBorder
        scrollView.drawsBackground = false
        scrollView.translatesAutoresizingMaskIntoConstraints = false

        let textView = NSTextView()
        textView.isEditable = true
        textView.isSelectable = true
        textView.isRichText = false
        textView.allowsUndo = true
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.textContainerInset = NSSize(width: 4, height: 4)
        textView.drawsBackground = false
        textView.font = .systemFont(ofSize: NSFont.systemFontSize)
        textView.string = initialContent
        textView.delegate = self
        textView.autoresizingMask = [.width]
        textView.textContainer?.widthTracksTextView = true

        scrollView.documentView = textView
        self.textView = textView

        let buttonBar = QuickLookButtonBar(
            state: buttonState,
            onSave: { [weak self] in self?.saveAction() },
            onCancel: { [weak self] in self?.cancelAction() }
        )
        let buttonHostingView = NSHostingView(rootView: buttonBar)
        buttonHostingView.translatesAutoresizingMaskIntoConstraints = false

        container.addSubview(scrollView)
        container.addSubview(buttonHostingView)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: container.topAnchor, constant: 10),
            scrollView.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 8),
            scrollView.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -8),
            scrollView.heightAnchor.constraint(equalToConstant: 80),

            buttonHostingView.topAnchor.constraint(equalTo: scrollView.bottomAnchor, constant: 6),
            buttonHostingView.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 10),
            buttonHostingView.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -14),

            container.widthAnchor.constraint(equalToConstant: 450),
        ])

        self.view = container
    }

    override func viewDidAppear() {
        super.viewDidAppear()
        view.window?.makeFirstResponder(textView)
        textView.setSelectedRange(NSRange(location: textView.string.count, length: 0))
    }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 { // Escape
            cancelAction()
            return
        }

        if event.modifierFlags.contains(.command), event.keyCode == 36 { // Cmd+Return
            if buttonState.isSaveEnabled {
                saveAction()
            }
            return
        }

        super.keyDown(with: event)
    }

    private func saveAction() {
        onSave(Self.compactJSON(textView.string))
        onDismiss()
    }

    private func cancelAction() {
        onDismiss()
    }

    // MARK: - JSON Helpers

    private static func looksLikeJSON(_ content: String) -> Bool {
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        return (trimmed.hasPrefix("{") && trimmed.hasSuffix("}")) ||
               (trimmed.hasPrefix("[") && trimmed.hasSuffix("]"))
    }

    static func compactJSON(_ string: String) -> String {
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

extension QuickLookViewController: NSTextViewDelegate {
    nonisolated func textDidChange(_ notification: Notification) {
        MainActor.assumeIsolated {
            buttonState.isSaveEnabled = textView.string != initialContent
        }
    }
}

// MARK: - Button Bar

@Observable
@MainActor
private class QuickLookButtonState {
    var isSaveEnabled = false
}

private struct QuickLookButtonBar: View {
    let state: QuickLookButtonState
    let onSave: () -> Void
    let onCancel: () -> Void

    var body: some View {
        HStack(spacing: 4) {
            Button(action: onSave) {
                Text("Save ⏎")
            }
            .buttonStyle(AICommandPromptPrimaryButtonStyle())
            .disabled(!state.isSaveEnabled)

            Button(action: onCancel) {
                HStack(spacing: 4) {
                    Text("Cancel")
                    Text("ESC")
                        .opacity(0.6)
                }
            }
            .font(.callout)
            .buttonStyle(AICommandPromptSecondaryButtonStyle())
        }
    }
}
