//
//  SearchQueryViewModel.swift
//  Collection
//
//  Created on 3/16/25.
//

import SwiftUI
import AIProxy
import Combine

/// A shared ViewModel that handles both AI-powered search and query editing functionality
class SearchQueryViewModel: ObservableObject {
    // Document ViewModel reference
    private let documentViewModel: DocumentViewModel
    
    // MARK: - Shared Properties
    
    /// The derived technical filter from natural language query
    @Published var derivedFilter: String = ""
    
    /// Flag indicating if processing is in progress
    @Published var isProcessing: Bool = false
    
    /// Flag to show/hide the filter view
    @Published var showFilterView: Bool = false
    
    // MARK: - AI Search Properties
    
    /// The natural language search query input by the user
    @Published var search: String = ""
    
    /// The editable version of the filter for manual adjustments
    @Published var editableFilter: String = ""
    
    /// Flag to show/hide search suggestions
    @Published var showSuggestions: Bool = false
    
    /// Available filter suggestions based on current input
    @Published var filterSuggestions: [FilterSuggestion] = []
    
    // MARK: - Query Editor Properties
    
    /// Flag to show the full query editor
    @Published var isFullQueryEditorOpen: Bool = false
    
    /// The number of documents matching the current query
    @Published var matchingDocumentsCount: Int = 0
    
    /// The time the query took to execute
    @Published var queryExecutionTime: String = "0s"
    
    /// The last time the query was executed
    @Published var lastQueryTime: String = ""
    
    // Private cancellables set
    private var cancellables = Set<AnyCancellable>()
    
    init(documentViewModel: DocumentViewModel) {
        self.documentViewModel = documentViewModel
        
        // Setup search text monitoring
        $search
            .debounce(for: .milliseconds(300), scheduler: RunLoop.main)
            .sink { [weak self] text in
                self?.updateFilterSuggestions(for: text)
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Public Methods
    
    func goBack() {
        Task { @MainActor in
            withAnimation(.spring(response: 0.3)) {
                documentViewModel.action = ActionBar.main
            }
        }
    }
    
    func processNaturalLanguageQuery() {
        guard !search.isEmpty && !isProcessing else { return }
        
        isProcessing = true
        
        Task {
            do {
                try await Task.sleep(for: .milliseconds(800))
                derivedFilter = extractTechnicalFilter(from: search)
                try await Task.sleep(for: .milliseconds(200))
                
                await MainActor.run { [weak self] in
                    guard let self = self else { return }
                    self.isProcessing = false
                    if !self.derivedFilter.isEmpty {
                        withAnimation {
                            self.showFilterView = true
                        }
                    }
                }
                
                 await documentViewModel.submitAIRequest(search: search)
            } catch {
                await MainActor.run { [weak self] in
                    self?.isProcessing = false
                }
                print("Error during query processing: \(error)")
            }
        }
    }
    
    func submitDirectFilter() {
        guard !search.isEmpty && !isProcessing else { return }
        
        isProcessing = true
        showSuggestions = false
        
        Task {
            do {
                derivedFilter = search
                try await Task.sleep(for: .milliseconds(600))
                
                await MainActor.run { [weak self] in
                    self?.isProcessing = false
                }
            } catch {
                await MainActor.run { [weak self] in
                    self?.isProcessing = false
                }
                print("Error during filter submission: \(error)")
            }
        }
    }
    
    func insertSuggestion(_ suggestion: FilterSuggestion) {
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
    
    // MARK: - Private Methods
    
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
    
    // MARK: - Query Editor Methods
    
    /// Toggle the full query editor view
    func toggleFullQueryEditor() {
        Task { @MainActor in
            withAnimation(.spring(response: 0.15)) {
                isFullQueryEditorOpen.toggle()
            }
        }
    }
    
    /// Execute the current query and update results
    func executeQuery() {
        guard !isProcessing else { return }
        
        isProcessing = true
        
        Task {
            do {
                // Simulate query execution
                try await Task.sleep(for: .milliseconds(600))
                
                // Update query stats
                await MainActor.run { [weak self] in
                    guard let self = self else { return }
                    self.matchingDocumentsCount = 2 // This would be the actual count from the query
                    self.queryExecutionTime = "0s"
                    self.lastQueryTime = "just now"
                    self.isProcessing = false
                }
            } catch {
                await MainActor.run { [weak self] in
                    self?.isProcessing = false
                }
                print("Error during query execution: \(error)")
            }
        }
    }
    
    /// Parse filter into components for syntax highlighting
    func parseFilterComponents(_ filter: String) -> [FilterComponent] {
        var components: [FilterComponent] = []
        
        let words = filter.split(separator: " ")
        for (index, word) in words.enumerated() {
            let text = String(word)
            
            if ["AND", "OR", "NOT"].contains(text.uppercased()) {
                components.append(FilterComponent(id: index, text: text, color: .blue))
            } else if ["=", ">", "<", ">=", "<=", "!=", "CONTAINS", "IN"].contains(text.uppercased()) {
                components.append(FilterComponent(id: index, text: text, color: .purple))
            } else if text.hasPrefix("'") && text.hasSuffix("'") {
                components.append(FilterComponent(id: index, text: text, color: .green))
            } else if let _ = Double(text) {
                components.append(FilterComponent(id: index, text: text, color: .orange))
            } else if ["true", "false"].contains(text.lowercased()) {
                components.append(FilterComponent(id: index, text: text, color: .orange))
            } else {
                components.append(FilterComponent(id: index, text: text, color: .primary))
            }
            
            if index < words.count - 1 {
                components.append(FilterComponent(id: index + 1000, text: " ", color: .primary))
            }
        }
        
        return components
    }
}
