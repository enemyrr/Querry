//
//  DocumentEditView.swift
//  Pluk
//
//  Created by Fauzaan on 3/30/25.
//
import SwiftUI
import LanguageSupport
import OnTapOutsideGesture

struct DocumentEditView: View {
    var viewModel: DocumentRowViewModel
    @State var editingDocumentJSON: String // Need a local copy to avoid overriding
    
    @State private var isHovered: Bool = false
    @State private var position: CodeEditor.Position = CodeEditor.Position()
    
    private var documentBinding: Binding<String> {
        Binding<String>(
            get: { editingDocumentJSON },
            set: {
                editingDocumentJSON = $0
                viewModel.updateEditingDocumentJSON(editingDocumentJSON)
            }
        )
    }
    
    init(viewModel: DocumentRowViewModel) {
        self.viewModel = viewModel
        editingDocumentJSON = viewModel.getEditingJSON()
    }
    
    var body: some View {
        CodeEditor(
            text: documentBinding,
            position: $position,
            messages: .constant(Set()),
            language: .mongodb()
        )
        .environment(\.codeEditorTheme, Theme.defaultDark)
        .environment(\.codeEditorLayoutConfiguration, .init(wrapText: true, dynamicHeight: true))
        .cornerRadius(10)
        .onHover { hovering in
            self.isHovered = hovering
        }
    }
}
