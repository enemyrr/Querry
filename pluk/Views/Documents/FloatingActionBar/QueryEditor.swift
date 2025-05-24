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
    var viewModel: SearchQueryViewModel
    @State private var position: CodeEditor.Position = CodeEditor.Position()
    @State private var messages: Set<TextLocated<Message>> = Set()
    
    @State private var isExpanded: Bool = false
    @State private var showEditor: Bool = false
    @Binding var showQueryEditor: Bool
    
    var body: some View {
        HStack(alignment: .bottom, spacing: 4) {
            VStack {
                if isExpanded {
                    fullQueryEditorView()
                        .onTapOutsideGesture {
                            closeWithAnimation()
                        }
                        .onKeyPress(.escape) {
                            closeWithAnimation()
                            return .handled
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
                    .stroke(.separator)
            )
            .cornerRadius(10)
        }
        .opacity(opacityValue)
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
    
    @State private var opacityValue: Double = 1.0
    
    // MARK: - Private Methods
    private func closeWithAnimation() {
        withAnimation(.spring(response: 0.2, dampingFraction: 0.8)) {
            isExpanded = false
            opacityValue = 0.0
        }
        
        // Dismiss after animation completes
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.11) {
            showEditor = false
            showQueryEditor = false
            opacityValue = 1.0
        }
    }
    
    @State private var displayedIcon: String = "play.fill"
    
    private func fullQueryEditorView() -> some View {
        VStack(spacing: 0) {
            // Query Editor Header
            HStack {
                Text("Query Editor")
                    .font(.headline)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                //                Text("\(viewModel.matchingDocumentsCount) rows \(viewModel.queryExecutionTime)")
                //                    .foregroundColor(.secondary)
                //                    .font(.subheadline)
                //
                //                Button(action: {}) {
                //                    Image(systemName: "clock")
                //                        .foregroundColor(.secondary)
                //                }
                //                .buttonStyle(.plain)
                //
                //                Text(viewModel.lastQueryTime)
                //                    .foregroundColor(.secondary)
                //                    .font(.subheadline)
                
                    Button(action: viewModel.clearQuery) {
                        Text("Clear")
                            .font(.system(size: 12))
                    }
                    .buttonStyle(OutlineSecondaryButtonStyle())
                    .opacity(viewModel.query == viewModel.defaultQuery ? 0 : 1)
                    .transition(.asymmetric(
                        insertion: .scale.combined(with: .opacity),
                        removal: .opacity
                    ))
                    .animation(.spring(response: 0.3), value: viewModel.query != viewModel.defaultQuery)
                
                Button(action: viewModel.executeQuery) {
                    Image(systemName: displayedIcon)
                        .foregroundColor(.secondary)
                        .contentTransition(.symbolEffect(.replace))
                        .frame(width: 10)
                    Text("Run")
                }
                .keyboardShortcut(.return, modifiers: .command)
                .buttonStyle(OutlineButtonStyle())
                .disabled(viewModel.processingStage != .idle)
                .customHelp("Run current query", delay: 0.5, position: .left, shortcut: KeyboardShortcut(
                    modifiers: [.command],
                    key: "Enter"
                ), spacing: 8)
            }
            .padding([.top, .horizontal, .bottom], 8)
            .onChange(of: viewModel.processingStage) { oldValue, newValue in
                if newValue == .idle && oldValue != .idle {
                    // When returning to idle from any non-idle state, delay the icon change
                    // Keep showing the stop icon for a bit longer
                    withAnimation {
                        displayedIcon = "stop.fill"
                    }
                    
                    // Then change back to play icon after delay
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.50) { // Adjust delay time as needed
                        withAnimation(.easeInOut(duration: 0.3)) {
                            displayedIcon = "play.fill"
                        }
                    }
                } else if newValue != .idle {
                    // Immediately show stop icon when starting a query
                    withAnimation {
                        displayedIcon = "stop.fill"
                    }
                }
            }
            
            CodeEditor(text: Binding<String>(
                get: { viewModel.query },
                set: { viewModel.query = $0 }
            ), position: $position, messages: $messages, language: .mongodb())
            .environment(\.codeEditorTheme, Theme.defaultDark)
            .environment(\.codeEditorLayoutConfiguration, .init(wrapText: true))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(.separator)
            )
            .padding(.bottom, 2)
            .frame(height: 120)
            .cornerRadius(10)
        }
    }
}
