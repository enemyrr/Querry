//
//  SearchInput.swift
//  Collection
//
//  Created by Fauzaan on 3/14/25.
//

import SwiftUI
import AIProxy

struct AISearchView: View {
    @ObservedObject var viewModel: DocumentViewModel
    
    @State private var search: String = ""
    @State private var derivedFilter: String = ""
    @State private var editableFilter: String = ""
    @State private var isProcessing: Bool = false
    @State private var showFilterView: Bool = false
    @State private var showSuggestions: Bool = false
    @State private var filterSuggestions: [FilterSuggestion] = []
    @FocusState private var isSearchFocused: Bool
    
    var body: some View {
        HStack(spacing: 8) {
            // Back button
            Button(action: {
                withAnimation(.spring(response: 0.3)) {
                    viewModel.action = ActionBar.main
                }
            }) {
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
                TextField("Tell collection what to find (e.g. fruits: \"Apple\")...", text: $search)
                    .focusSection()
                    .focused($isSearchFocused)
                    .textFieldStyle(.plain)
                    .disabled(isProcessing)
                    .onSubmit {
                        processNaturalLanguageQuery()
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
    
    // Process the natural language query to extract technical filters
    private func processNaturalLanguageQuery() {
        guard !search.isEmpty && !isProcessing else { return }
        
        isProcessing = true
        isSearchFocused = false
        
        Task {
            do {
                try await Task.sleep(for: .milliseconds(800))
                derivedFilter = extractTechnicalFilter(from: search)
                try await Task.sleep(for: .milliseconds(200))
                
                await MainActor.run {
                    isProcessing = false
                    if !derivedFilter.isEmpty {
                        withAnimation {
                            showFilterView = true
                        }
                    }
                }
                
                await viewModel.submitAIRequest(search: search)
            } catch {
                await MainActor.run {
                    isProcessing = false
                }
                print("Error during query processing: \(error)")
            }
        }
    }
    
    // Submit a direct filter query
    private func submitDirectFilter() {
        guard !search.isEmpty && !isProcessing else { return }
        
        isProcessing = true
        isSearchFocused = false
        showSuggestions = false
        
        Task {
            do {
                derivedFilter = search
                try await Task.sleep(for: .milliseconds(600))
                
                await MainActor.run {
                    isProcessing = false
                }
            } catch {
                await MainActor.run {
                    isProcessing = false
                }
                print("Error during filter submission: \(error)")
            }
        }
    }
    
    // Update filter suggestions based on current input
    private func updateFilterSuggestions(for input: String) {
        if input.isEmpty {
            showSuggestions = false
            return
        }
        
        let lowercasedInput = input.lowercased()
        var suggestions: [FilterSuggestion] = []
        
        if input.contains("=") || input.contains(">") || input.contains("<") {
            suggestions.append(FilterSuggestion(text: "true", description: "Boolean value", icon: "checkmark.circle", shortcut: ""))
            suggestions.append(FilterSuggestion(text: "false", description: "Boolean value", icon: "xmark.circle", shortcut: ""))
            suggestions.append(FilterSuggestion(text: "currentUser", description: "Current user ID", icon: "person", shortcut: ""))
        } else if lowercasedInput.hasSuffix(" and") || lowercasedInput.hasSuffix(" or") || input.hasSuffix(" ") {
            suggestions.append(FilterSuggestion(text: "author", description: "Document author", icon: "person.text.rectangle", shortcut: ""))
            suggestions.append(FilterSuggestion(text: "date", description: "Document creation date", icon: "calendar", shortcut: ""))
            suggestions.append(FilterSuggestion(text: "extension", description: "File extension", icon: "doc", shortcut: ""))
            suggestions.append(FilterSuggestion(text: "shared", description: "Sharing status", icon: "person.2", shortcut: ""))
        } else {
            suggestions.append(FilterSuggestion(text: "AND", description: "Logical AND operator", icon: "plus.square", shortcut: "&&"))
            suggestions.append(FilterSuggestion(text: "OR", description: "Logical OR operator", icon: "plus.square.fill", shortcut: "||"))
            suggestions.append(FilterSuggestion(text: "CONTAINS", description: "String contains value", icon: "text.magnifyingglass", shortcut: ""))
            suggestions.append(FilterSuggestion(text: "IN", description: "Value in collection", icon: "list.bullet", shortcut: ""))
        }
        
        filterSuggestions = suggestions
        showSuggestions = !suggestions.isEmpty
    }
    
    // Insert a suggestion into the current filter query
    private func insertSuggestion(_ suggestion: FilterSuggestion) {
        if search.hasSuffix(" ") {
            search += suggestion.text
        } else {
            search += " " + suggestion.text
        }
        
        if ["author", "date", "extension", "shared"].contains(suggestion.text.lowercased()) {
            search += " = "
        }
        
        showSuggestions = false
    }
    
    // Extract technical filter from natural language query
    private func extractTechnicalFilter(from query: String) -> String {
        let lowercasedQuery = query.lowercased()
        
        if lowercasedQuery.contains("last month") {
            return "date >= startOfLastMonth AND date <= endOfLastMonth"
        } else if lowercasedQuery.contains("created by me") {
            return "author = 'currentUser'"
        } else if lowercasedQuery.contains("pdf") {
            return "extension = 'pdf'"
        } else if lowercasedQuery.contains("shared with") {
            return "shared = true"
        } else if lowercasedQuery.contains("important") {
            return "tags CONTAINS 'important'"
        } else {
            return "content CONTAINS '\(query)'"
        }
    }
    
    
}

// MARK: - Support Types

// Filter suggestion for the autocomplete
struct FilterSuggestion: Identifiable {
    let id = UUID()
    let text: String
    let description: String
    let icon: String
    let shortcut: String
}

// Component of a filter for syntax highlighting
struct FilterComponent: Identifiable {
    let id: Int
    let text: String
    let color: Color
}

