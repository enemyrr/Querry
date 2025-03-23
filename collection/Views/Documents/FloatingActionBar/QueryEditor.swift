//
//  QueryEditor.swift
//  Collection
//
//  Created by Fauzaan on 3/16/25.
//

import SwiftUI
import LanguageSupport
import OnTapOutsideGesture

struct QueryEditor: View {
    @ObservedObject var viewModel: SearchQueryViewModel
    @ObservedObject var documentViewModel: DocumentViewModel
    @State private var position: CodeEditor.Position = CodeEditor.Position()
    @State private var messages: Set<TextLocated<Message>> = Set()
    
    var body: some View {
        HStack(alignment: .bottom, spacing: 4) {
            if !viewModel.lastQuery.isEmpty {
                VStack {
                    if !viewModel.isFullQueryEditorOpen {
                        filterSyntaxView()
                            .onTapGesture {
                                viewModel.openFullQueryEditor()
                            }
                        
                    } else {
                        fullQueryEditorView()
                            .onTapOutsideGesture {
                                viewModel.closeFullQueryEditor()
                            }
                    }
                }
                .fixedSize(horizontal: viewModel.isFullQueryEditorOpen ? false : true, vertical: false)
                .padding(.vertical, 4)
                .padding(.horizontal, 6)
                .animation(.spring(response: 0.4, dampingFraction: 0.7), value: viewModel.isFullQueryEditorOpen)
                .modifier(GlassBackgroundStyle(cornerRadius: viewModel.isFullQueryEditorOpen ? 10 : 6))
                .shadow(color: .black.opacity(viewModel.isFullQueryEditorOpen ? 0 : 0.15), radius: 5, x: 0, y: 2)
                .overlay(
                    RoundedRectangle(cornerRadius: viewModel.isFullQueryEditorOpen ? 10 : 6)
                        .stroke(.separator, lineWidth: 1)
                )
                
            }
            
            if !viewModel.isFullQueryEditorOpen {
                Spacer()
                Text("\(documentViewModel.totalItems) documents").font(.footnote)
                    .padding(.vertical, 4)
                    .padding(.horizontal, 6)
                    .modifier(GlassBackgroundStyle(cornerRadius: 6))
                    .shadow(color: .black.opacity(0.15), radius: 5, x: 0, y: 2)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(.separator, lineWidth: 1)
                    )
            }
        }
    }
    
    // Function to display filter syntax with highlighting
    private func filterSyntaxView() -> some View {
        return HStack(spacing: 2) {
            Image(systemName: "curlybraces.square.fill")
                .font(.footnote)
                .padding(.trailing, 6)
            
            ScrollView(.horizontal, showsIndicators: false) {
                Text(viewModel.lastQuery)
                    .font(.footnote.monospaced())
                    .lineLimit(1)
                    .foregroundColor(.primary)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .fixedSize(horizontal: true, vertical: false)  // Use intrinsic size by default
        .frame(maxWidth: 250, alignment: .leading)  // But cap it at 250
    }
    
    // Full query editor view as a private function
    private func fullQueryEditorView() -> some View {
        VStack(spacing: 0) {
            // Query Editor Header
            HStack {
                Text("Query Editor")
                    .font(.headline)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Text("\(viewModel.matchingDocumentsCount) rows \(viewModel.queryExecutionTime)")
                    .foregroundColor(.secondary)
                    .font(.subheadline)
                
                Button(action: {}) {
                    Image(systemName: "clock")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                
                Text(viewModel.lastQueryTime)
                    .foregroundColor(.secondary)
                    .font(.subheadline)
                
                Button(action: {
                    viewModel.executeQuery()
                }) {
                    Image(systemName: "play.fill")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .disabled(viewModel.isProcessing)
            }
            .padding([.top, .horizontal, .bottom], 12)
            
            CodeEditor(text: $viewModel.aiQueryResult, position: $position, messages: $messages, language: .sqlite(), layout: .init(showMinimap: false, wrapText: true))
                .environment(\.codeEditorTheme, Theme.defaultDark)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(.separator, lineWidth: 1)
                )
                .padding(.bottom, 2)
                .cornerRadius(10)
                .frame(height: 120)
        }
    }
}
