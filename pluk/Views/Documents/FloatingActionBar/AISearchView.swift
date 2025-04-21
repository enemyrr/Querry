//
//  AISearchView.swift
//  Collection
//
//  Created by Fauzaan on 3/14/25.
//

import SwiftUI
import AIProxy
import Combine

// MARK: - View

struct AISearchView: View {
    @Bindable var viewModel: SearchQueryViewModel
    var DocumentListModel: DocumentListModel
    
    // Focus state for the search field
    @FocusState private var isSearchFocused: Bool
    
    // Original user query
    @State private var originalQuery: String = ""
    
    // Animation timer
    @State private var animationTimer: Timer? = nil
    @State private var animationDots: String = ""
    
    var body: some View {
        HStack(spacing: 8) {
            // Back button
            Button(action: viewModel.goBack) {
                Image(systemName: "arrow.backward")
                    .font(.system(size: 14))
                    .contentShape(Rectangle())
            }
            .buttonStyle(ActionButtonStyle(padding: EdgeInsets(top: 7, leading: 7, bottom: 7, trailing: 7), isActive: true))
            .keyboardShortcut(.escape, modifiers: [])
            .customHelp("Go back", position: .top, shortcut: KeyboardShortcut(
                modifiers: [],
                key: "Escape"
            ), spacing: 10)
            .padding(.leading, 3)
            
            HStack(spacing: 12) {
                // Main TextField with dynamic display text
                if viewModel.processingStage != .idle {
                    Text(viewModel.processingStage.description + animationDots)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .transition(.push(from: .bottom))
                        .id("processing-\(viewModel.processingStage.description)")
                        .animation(
                            .interpolatingSpring(stiffness: 50, damping: 10),
                            value: viewModel.processingStage
                        )
                } else {
                    TextField("Tell Pluk what to find (e.g. fruits: \"Apple\")...", text: $viewModel.search)
                        .focusSection()
                        .font(
                            Font.system(.body, design: .monospaced)
                        )
                        .focused($isSearchFocused)
                        .textFieldStyle(.plain)
                        .onSubmit {
                            submitQuery()
                        }
                        .onAppear {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                                isSearchFocused = true
                            }
                        }
                        .transition(.opacity)
                        .animation(.easeInOut(duration: 0.3), value: viewModel.processingStage)
                }
            }
            .padding(.vertical, 8)
            .animation(.easeInOut, value: viewModel.processingStage)
            
            HStack {
                if viewModel.processingStage != .idle {
                    Button(action: {
                        // TODO: Ability to disable
                    }) {
                        Image(systemName: "stop.fill")
                            .font(.system(size: 12))
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .padding(6)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(
                                Color.white.opacity(0.1)
                            )
                    )
                    .onAppear {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                            // Animate to full opacity and size
                            withAnimation(.easeOut(duration: 0.3)) {
                                // Use withAnimation to trigger the state change animation
                            }
                        }
                    }
                }
//                Text("Enter")
//                    .font(.system(size: 12))
//                    .padding(.vertical, 4)
//                    .padding(.horizontal, 6)
//                    .foregroundColor(.white.opacity(0.2))
//                    .background(
//                        RoundedRectangle(cornerRadius: 4)
//                            .stroke(.white.opacity(0.2))
//                    )

            }
            .padding(.vertical, 4)
            .padding(.trailing, 2)

//            Divider()
//                .frame(height: 22)
//                .padding(.vertical, 6)
//            
//            PaginationMinimal(viewModel: DocumentListModel)
        }
        .frame(height: 34)
        .padding(.horizontal, 6)
        .padding(.vertical, 4)
        .background(
            IntelligenceUIPlatterView()
        )
        .onChange(of: viewModel.processingStage) { _, isProcessing in
            if viewModel.processingStage != .idle {
                startProcessingAnimation()
            } else {
                stopProcessingAnimation()
            }
        }
    }
    
    // MARK: - Private Methods
    private func submitQuery() {
        guard !viewModel.search.isEmpty else { return }
        
        // Save original query for potential future use
        originalQuery = viewModel.search
        
        // Submit the query - the ViewModel handles all the stages
        Task {
            await viewModel.processNaturalLanguageQuery(search: viewModel.search)
        }
        isSearchFocused = false
    }
    
    private func startProcessingAnimation() {
        // Start animation timer
        animationTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { _ in
            if animationDots.count >= 3 {
                animationDots = ""
            } else {
                animationDots += "."
            }
        }
    }
    
    private func stopProcessingAnimation() {
        // Stop animation timer
        animationTimer?.invalidate()
        animationTimer = nil
        animationDots = ""
    }
}

