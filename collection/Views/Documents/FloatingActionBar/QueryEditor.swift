//
//  QueryEditor.swift
//  Collection
//
//  Created by Fauzaan on 3/16/25.
//

import SwiftUI
import LanguageSupport

struct QueryEditor: View {
    @ObservedObject var viewModel: SearchQueryViewModel
    @ObservedObject var documentViewModel: DocumentViewModel
    @State private var position: CodeEditor.Position = CodeEditor.Position()
    @State private var messages: Set<TextLocated<Message>> = Set()
    
    var body: some View {
        HStack(alignment: .bottom, spacing: 4) {
            // Show content if we have either a derived filter or an AI query result
            if !viewModel.aiQueryResult.isEmpty {
                VStack {
                    if !viewModel.isFullQueryEditorOpen {
                        filterSyntaxView()
                            .onTapGesture {
                                viewModel.toggleFullQueryEditor()
                            }
                    } else {
                        fullQueryEditorView()
                    }
                }
                .padding(.vertical, 4)
                .padding(.horizontal, 6)
                .animation(.spring(response: 0.4, dampingFraction: 0.7), value: viewModel.isFullQueryEditorOpen)
                .modifier(GlassBackgroundStyle(cornerRadius: viewModel.isFullQueryEditorOpen ? 10 : 8))
                .overlay(
                    RoundedRectangle(cornerRadius: viewModel.isFullQueryEditorOpen ? 10 : 8)
                        .stroke(.separator, lineWidth: 1)
                )
                
                if !viewModel.isFullQueryEditorOpen {
                    Spacer()
                    HStack(spacing: 4) {
                        Text("\(documentViewModel.totalItems) documents").font(.caption)
                            .padding(.vertical, 4)
                            .padding(.horizontal, 6)
                            .modifier(GlassBackgroundStyle(cornerRadius: 6))
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(.separator, lineWidth: 1)
                            )
                        
//                        Button(action: {
//                            viewModel.executeQuery()
//                        }) {
//                            HStack(spacing: 6) {
//                                Image(systemName: "play.fill")
//                                    .font(.caption)
//                                
//                            }
//                            .padding(.vertical, 6)
//                            .padding(.horizontal, 8)
//                            .background(
//                                RoundedRectangle(cornerRadius: 6)
//                                    .fill(
//                                        Color.black.opacity(0.3)
//                                    )
//                            )
//                            .modifier(GlassBackgroundStyle(cornerRadius: 6))
//                            .overlay(
//                                RoundedRectangle(cornerRadius: 6)
//                                    .stroke(.separator, lineWidth: 1)
//                            )
//                        }
//                        .buttonStyle(.plain)
//                        .disabled(viewModel.isProcessing)
                    }
                }
            }
        }
    }
    
    // Function to display filter syntax with highlighting
    private func filterSyntaxView() -> some View {
        let singleLineText = viewModel.aiQueryResult
            .replacingOccurrences(of: "\n", with: "")  // Remove all newlines completely
            .replacingOccurrences(of: "\t", with: "")  // Remove all tabs completely
            // Handle spaces around brackets and punctuation - specific order matters
            .replacingOccurrences(of: " {", with: "{")
            .replacingOccurrences(of: "{ ", with: "{")
            .replacingOccurrences(of: " }", with: "}")
            .replacingOccurrences(of: "} ", with: "}")
            .replacingOccurrences(of: " [", with: "[")
            .replacingOccurrences(of: "[ ", with: "[")
            .replacingOccurrences(of: " ]", with: "]")
            .replacingOccurrences(of: "] ", with: "]")
            .replacingOccurrences(of: " :", with: ": ")
            .replacingOccurrences(of: " ,", with: ", ")
            // Only collapse multiple spaces between words/values after handling brackets
            .replacingOccurrences(of: "  +", with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespaces)
        
        return HStack(spacing: 2) {
            Image(systemName: "curlybraces.square.fill")
                .font(.caption)
                .padding(.trailing, 8)
            
            ScrollViewReader { scrollProxy in
                ScrollView(.horizontal, showsIndicators: false) {
                    Text(singleLineText)
                        .font(.caption.monospaced())
                        .lineLimit(1)
                        .foregroundColor(.primary)
                        .id("endOfText") // Assign an ID to scroll to
                }
                .onChange(of: viewModel.aiQueryResult) { _, _ in
                    // Scroll to the end whenever the aiQueryResult changes
                    withAnimation {
                        scrollProxy.scrollTo("endOfText", anchor: .trailing)
                    }
                }
                .onAppear {
                    // Scroll to the end when the view first appears
                    scrollProxy.scrollTo("endOfText", anchor: .trailing)
                }
            }
        }
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
                
                Button(action: {
                    viewModel.toggleFullQueryEditor()
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding([.top, .horizontal, .bottom])
            

            CodeEditor(text: $viewModel.aiQueryResult, position: $position, messages: $messages, language: .sqlite(), layout: .init(showMinimap: false, wrapText: true))
                .environment(\.codeEditorTheme, Theme.defaultDark)
//                .background(Color(.white).opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(.separator, lineWidth: 1)
                )
                .cornerRadius(10)
                .frame(height: 120)
        }
    }
}
