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
    @State private var editingJSON: String
    
    init(viewModel: DocumentRowViewModel) {
        self.viewModel = viewModel
        self.editingJSON = viewModel.getEditingJSON()
    }
    
    var body: some View {
        CodeEditor(
            text: Binding<String>(
                get: { editingJSON },
                set: { editingJSON = $0 }
            ),
            position: .constant(CodeEditor.Position()),
            messages: .constant(Set()),
            language: .sqlite()
        )
        .environment(\.codeEditorTheme, Theme.defaultDark)
        .environment(\.codeEditorLayoutConfiguration, .init(showMinimap: false, wrapText: false))
//        .overlay(
//            RoundedRectangle(cornerRadius: 10)
//                .stroke(.separator, lineWidth: 1)
//        )
//        .padding(.bottom, 2)
        .cornerRadius(10)
    }
}
