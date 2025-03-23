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
    // Shared search/query view model
    @ObservedObject var viewModel: SearchQueryViewModel
    @ObservedObject var documentViewModel: DocumentViewModel
    
    // Focus state for the search field
    @FocusState private var isSearchFocused: Bool
    
    // Original user query
    @State private var originalQuery: String = ""
    
    // Animation timer
    @State private var animationTimer: Timer? = nil
    @State private var animationDots: String = ""
    
    init(viewModel: SearchQueryViewModel, documentViewModel: DocumentViewModel) {
        self.viewModel = viewModel
        self.documentViewModel = documentViewModel
    }
    
    var body: some View {
        HStack(spacing: 8) {
            // Back button
            Button(action: viewModel.goBack) {
                Image(systemName: "arrow.backward")
                    .font(.system(size: 14))
                    .contentShape(Rectangle())
            }
            .buttonStyle(ActionButtonStyle(padding: EdgeInsets(top: 7, leading: 8, bottom: 7, trailing: 8), isActive: true))
            .keyboardShortcut(.escape, modifiers: [])
            .customHelp("Go back", position: .top, shortcut: KeyboardShortcut(
                modifiers: [],
                key: "Escape"
            ), spacing: 10)
            
            HStack(spacing: 12) {
                // Main TextField with dynamic display text
                if viewModel.isProcessing {
                    Text(viewModel.processingStage.description + animationDots)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                              .id("processing-\(viewModel.processingStage.description)")
                              .animation(.easeInOut(duration: 0.3), value: viewModel.processingStage)
                } else {
                    TextField("Tell Pluk what to find (e.g. fruits: \"Apple\")...", text: $viewModel.search)
                        .focusSection()
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
                        .animation(.easeInOut(duration: 0.3), value: viewModel.isProcessing)
                }
            }
            .padding(.vertical, 8)
            .animation(.easeInOut, value: viewModel.isProcessing)
            
            Divider()
                .frame(height: 22)
                .padding(.vertical, 6)
            
            PaginationMinimal(viewModel: documentViewModel)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 4)
        .background(
            IntelligenceUIPlatterView()
        )
        .onReceive(viewModel.$isProcessing) { isProcessing in
            if isProcessing {
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

