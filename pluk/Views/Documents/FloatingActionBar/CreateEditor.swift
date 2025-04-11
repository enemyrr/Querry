//
//  QueryEditor.swift
//  Collection
//
//  Created by Fauzaan on 3/16/25.
//

import SwiftUI
import LanguageSupport
import OnTapOutsideGesture
import MongoKitten

struct CreateEditor: View {
    // MARK: - Dependencies
    @State private var viewModel: CreateEditorViewModel
    @Binding var showCreateDocumentSheet: Bool
    
    // MARK: - View State
    @State private var position: CodeEditor.Position = CodeEditor.Position()
    @State private var messages: Set<TextLocated<Message>> = Set()
    @State private var isExpanded: Bool = false
    @State private var showEditor: Bool = false
    @State private var saveSuccess: Bool = false
    
    // MARK: - Initialization
    init(documentListModel: DocumentListModel, showCreateDocumentSheet: Binding<Bool>) {
        self._viewModel = State(initialValue: CreateEditorViewModel(documentListModel: documentListModel))
        self._showCreateDocumentSheet = showCreateDocumentSheet
    }
    
    // MARK: - Body
    var body: some View {
        HStack(alignment: .bottom, spacing: 4) {
            VStack {
                if isExpanded {
                    fullQueryEditorView()
                        .opacity(showEditor ? 1 : 0)
                        .animation(.easeInOut(duration: 0.3), value: showEditor)
                        .onTapOutsideGesture {
                            closeWithAnimation()
                        }
                }
            }
            .fixedSize(horizontal: !isExpanded, vertical: !isExpanded)
            .padding(.vertical, 4)
            .padding(.horizontal, 6)
            .modifier(GlassBackgroundStyle(cornerRadius: 10))
            .shadow(color: .black.opacity(0.15), radius: 5, x: 0, y: 2)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(.separator, lineWidth: 1)
            )
        }
        .onAppear {
            withAnimation(.spring(response: 0.3, blendDuration: 0.1)) {
                isExpanded = true
            }
            
            // This will run approximately when the animation finishes
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.10) {
                showEditor = true
            }
        }
    }
    
    // MARK: - Private Methods
    private func closeWithAnimation() {
        withAnimation(.spring(response: 0.2, dampingFraction: 0.8)) {
            isExpanded = false
        }
        
        // Dismiss after animation completes
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.10) {
            showEditor = false
            showCreateDocumentSheet = false
        }
    }
    
    private func handleSave() {
        Task {
            let success = await viewModel.saveDocument()
            if success {
                // Show success feedback
                await MainActor.run {
                    withAnimation(.easeIn(duration: 0.2)) {
                        saveSuccess = true
                    }
                }
                
                // Reload documents
                _ = await viewModel.loadDocuments()
                
                // Wait for success animation to be visible (delay closing)
                try? await Task.sleep(nanoseconds: 800_000_000) // 0.8 seconds
                
                // Close the editor
                await MainActor.run {
                    closeWithAnimation()
                }
            }
        }
    }
    
    // Full query editor view as a private function
    private func fullQueryEditorView() -> some View {
        VStack(spacing: 0) {
            // Query Editor Header
            HStack {
                Text("Insert Document")
                    .font(.headline)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                if let error = viewModel.errorMessage {
                    Text(error)
                        .font(.system(size: 10))
                        .foregroundColor(.red)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
                
                Button(action: {
                    closeWithAnimation()
                }) {
                    Text("Discard")
                        .font(.system(size: 10))
                        .foregroundColor(.red)
                        .tint(.red)
                }
                .buttonStyle(DistructiveButtonStyleText())
                .disabled(viewModel.isLoading || saveSuccess)
                
                Button(action: handleSave) {
                    ZStack {
                        ProgressView()
                            .controlSize(.mini)
                            .opacity(viewModel.isLoading ? 1 : 0)
                            .animation(.easeIn, value: viewModel.isLoading)
                        
                        Text("Save")
                    }
                    .frame(minWidth: 80)
                }
                .if(saveSuccess) { view in
                    view.buttonStyle(SuccessButtonStyle())
                } else: { view in
                    view.buttonStyle(OutlineButtonStyle())
                }
                .disabled(viewModel.isLoading || saveSuccess)
            }
            .padding([.top, .horizontal, .bottom], 8)
            
            CodeEditor(text: $viewModel.jsonDocument, position: $position, messages: $messages, language: .mongodb())
                .environment(\.codeEditorTheme, Theme.defaultDark)
                .environment(\.codeEditorLayoutConfiguration, .init(wrapText: true))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(.separator, lineWidth: 1)
                )
                .padding(.bottom, 2)
                .cornerRadius(10)
                .frame(height: isExpanded ? 320 : 0) // Collapse height when not expanded
                .disabled(viewModel.isLoading || saveSuccess)
        }
    }
}

// MARK: - Button Styles
struct SuccessButtonStyle: ButtonStyle {
    @Environment(\.colorScheme) var colorScheme
    @State private var isHovering = false
    
    func makeBody(configuration: Configuration) -> some View {
        HStack {
            configuration.label
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 10)
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(.separator, lineWidth: 1)
        )
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(
                    Color.green
                )
        )
        .onHover { hovering in
            isHovering = hovering
        }
    }
}
