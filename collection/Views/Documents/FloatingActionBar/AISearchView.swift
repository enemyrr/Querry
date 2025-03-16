//
//  AISearchView.swift
//  Collection
//
//  Created by Fauzaan on 3/14/25.
//

import SwiftUI
import AIProxy

// MARK: - View

struct AISearchView: View {
    // Shared search/query view model
    @ObservedObject var viewModel: SearchQueryViewModel
    
    // Focus state for the search field
    @FocusState private var isSearchFocused: Bool
    
    init(viewModel: SearchQueryViewModel) {
        self.viewModel = viewModel
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
                // Main TextField
                TextField("Tell collection what to find (e.g. fruits: \"Apple\")...", text: $viewModel.search)
                    .focusSection()
                    .focused($isSearchFocused)
                    .textFieldStyle(.plain)
                    .disabled(viewModel.isProcessing)
                    .onSubmit {
                        viewModel.processNaturalLanguageQuery()
                        isSearchFocused = false
                    }
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                            isSearchFocused = true
                        }
                    }
            }
            .frame(maxWidth: 400)
            .padding(.vertical, 8)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 4)
        .background(IntelligenceUIPlatterView())
    }
}

