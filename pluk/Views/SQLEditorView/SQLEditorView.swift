//
//  SQLEditorView.swift
//  Pluk
//
//  Created by Claude on 8/31/25.
//

import SwiftUI
import CodeEditorView
import LanguageSupport

struct SQLEditorView: View {
    @Environment(ConnectionInstance.self) private var instance
    @Environment(\.colorScheme) var colorScheme
    
    @State private var sqlQuery: String = ""
    @State private var viewState: SQLEditorViewState = .idle
    @State private var selectedResultIndex: Int = 0
    @State private var isExecuting: Bool = false
    @State private var lastExecutionTime: TimeInterval = 0
    @State private var lastRowCount: Int = 0
    @State private var lastError: Error?
    @State private var showAICommandPrompt: Bool = false
    @State private var initialCursorLineNumber: Int = 0
    @State private var aiErrorSuggestion: String? = nil
    @State private var isLoadingAISuggestion: Bool = false
    @State private var showAIErrorSuggestion: Bool = false
    @State private var originalQueryBeforeSuggestion: String = ""
    @State private var originalFullEditorContent: String = ""
    @State private var executedQueryPosition: CodeEditor.Position = CodeEditor.Position()
    @State private var showingInlineDiff: Bool = false
    
    @State private var splitRatio: CGFloat = 0.4
    private var isLoading : Bool { viewState == .loading }
    
    var body: some View {
        SplitView(.vertical, $splitRatio, dividerColor: lastError != nil ? Color(.red).opacity(0.5) : isExecuting ? Color(red: 1.0, green: 0.5, blue: 0.0) : Color(.separatorColor), minSize: 40) {
            VStack(spacing: 0) {
                sqlEditor
                editorToolbar
            }
        } right: {
            resultsContent
        }
        .background(
            Color(colorScheme == .dark ? .black : .white).opacity(0.6)
        )
        .background(
            // Hidden button for Cmd+K shortcut
            Button(action: {
                initialCursorLineNumber = cursorLineNumber + 1
                showAICommandPrompt = true
            }) {
                EmptyView()
            }
                .keyboardShortcut("k", modifiers: [.command])
                .hidden()
        ).onAppear {
            loadAvailableDatabases()
        }
    }
    
    @State private var selectedDatabase: String = ""
    @State private var availableDatabases: [any DatabaseWrapper] = []
    
    private var executionSummaryText: String {
        guard lastExecutionTime > 0 else { return "" }
        
        let timeInMs = lastExecutionTime * 1000
        let formattedTime = String(format: "%.0f", timeInMs)
        
        if lastRowCount > 0 {
            let formatter = NumberFormatter()
            formatter.numberStyle = .decimal
            let formattedCount = formatter.string(from: NSNumber(value: lastRowCount)) ?? "\(lastRowCount)"
            return "\(formattedCount) rows returned in \(formattedTime)ms"
        } else {
            return "Executed in \(formattedTime)ms"
        }
    }
    
    private var editorToolbar: some View {
        HStack {
            Text(executionSummaryText)
                .font(.callout)
                .foregroundColor(.secondary)
            
            Spacer()
            
            HStack(spacing: 0) {
                // Prettify SQL button
                ToolbarIconButton(
                    systemName: "wand.and.stars",
                    action: prettifySQL,
                    disabled: sqlQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || showingInlineDiff,
                    tooltip: ""
                )
                .keyboardShortcut("i", modifiers: [.command])
                .customHelp(
                    "Format SQL",
                    position: .top,
                    shortcut: KeyboardShortcut(
                        modifiers: [.command],
                        key: "i"
                    )
                )
                
                // Add to Favorites button
                //                ToolbarIconButton(
                //                    systemName: "heart",
                //                    action: addToFavorites,
                //                    disabled: sqlQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                //                    tooltip: "Add to Favorites"
                //                )
            }
            
            
            // Database selection button (secondary style)
            Menu {
                if !availableDatabases.isEmpty {
                    ForEach(availableDatabases, id: \.name) { database in
                        Button(database.name) {
                            selectedDatabase = database.name
                        }
                    }
                } else {
                    Text("No databases available")
                        .foregroundColor(.secondary)
                }
            } label: {
                HStack(spacing: 0) {
                    Text("Database: ")
                        .font(.system(size: 12))
                    Text(selectedDatabase)
                        .font(.system(size: 12, weight: .medium))
                    Spacer(minLength: 4)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 10))
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .foregroundColor(.secondary)
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(.separator, lineWidth: 0.5)
                )
            }
            .buttonStyle(.plain)
            .fixedSize()
            
            Button(action: {
                executeQuery()
            }) {
                HStack {
                    Text(selectedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Run" : "Run Selection")
                    
                    if isExecuting {
                        ProgressView()
                            .controlSize(.small)
                            .colorMultiply(.black)
                            .padding(.horizontal, 4.5)
                    } else {
                        Text("⌘⏎")
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .foregroundColor(.black.opacity(0.8) )
                .background(Color(red: 248/255, green: 148/255, blue: 99/255))
                .cornerRadius(8)
                .fixedSize()
            }
            .keyboardShortcut(.return, modifiers: [.command])
            .buttonStyle(PlainButtonStyle())
            .disabled((sqlQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && selectedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) || isExecuting || showingInlineDiff)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }
    
    @State private var position: CodeEditor.Position = CodeEditor.Position()
    @State private var messages: Set<TextLocated<Message>> = Set()
    
    private var cursorLineNumber: Int {
        guard !position.selections.isEmpty else { return 0 }
        let cursorPosition = position.selections[0].location
        let textUpToCursor = String(sqlQuery.prefix(cursorPosition))
        return textUpToCursor.components(separatedBy: .newlines).count - 1
    }
    
    private var selectedText: String {
        guard !position.selections.isEmpty else { return "" }
        let selection = position.selections[0]
        guard selection.length > 0, selection.location + selection.length <= sqlQuery.count else { return "" }
        
        let startIndex = sqlQuery.index(sqlQuery.startIndex, offsetBy: selection.location)
        let endIndex = sqlQuery.index(startIndex, offsetBy: selection.length)
        return String(sqlQuery[startIndex..<endIndex])
    }
    
    private var sqlEditor: some View {
        ZStack(alignment: .topLeading) {
            CodeEditor(text: $sqlQuery, position: $position, messages: $messages, language: .sqlite())
                .environment(\.codeEditorTheme, transparentTheme)
                .environment(\.codeEditorLayoutConfiguration, .init(wrapText: true))
            
            // Placeholder text
            if sqlQuery.isEmpty {
                HStack(alignment: .top, spacing: 4) {
                    Text("Start writing SQL or type")
                        .foregroundColor(.secondary.opacity(0.6))
                        .font(.system(.body, design: .monospaced))
                    
                    Text("⌘K")
                        .font(.callout)
                        .foregroundColor(.primary)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 2)
                        .background(Color(.controlBackgroundColor))
                        .overlay(
                            RoundedRectangle(cornerRadius: 4)
                                .stroke(Color(.separatorColor), lineWidth: 1)
                        )
                        .cornerRadius(4)
                    
                    Text("to generate a query")
                        .foregroundColor(.secondary.opacity(0.6))
                        .font(.system(.body, design: .monospaced))
                }
                .padding(.leading, 38)
                .allowsHitTesting(false)
            }
            
            // AI Command Prompt
            if showAICommandPrompt {
                AICommandPrompt(
                    isPresented: $showAICommandPrompt,
                    generatedQuery: $sqlQuery,
                    cursorLineNumber: initialCursorLineNumber,
                    selectedText: selectedText
                )
                .padding(.top, 8)
                .padding(.leading, 38)
                .transition(.move(edge: .bottom))
                .animation(.easeInOut(duration: 0.3), value: showAICommandPrompt)
            }
            
            // AI Error Suggestion Popup - positioned at center bottom
            if showAIErrorSuggestion {
                VStack {
                    Spacer()
                    
                    AIErrorSuggestionPopup(
                        isPresented: $showAIErrorSuggestion,
                        suggestion: $aiErrorSuggestion,
                        isLoading: isLoadingAISuggestion,
                        onAcceptAndRun: acceptAISuggestion,
                        onAcceptOnly: acceptAISuggestionOnly,
                        onReject: rejectAISuggestion
                    )
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .animation(.easeInOut(duration: 0.3), value: showAIErrorSuggestion)
                .padding(.bottom, -34)
            }
        }
        .padding(.top, 10)
    }
    
    private var transparentTheme: Theme {
        var theme = colorScheme == .dark ? Theme.defaultDark : Theme.defaultLight
        theme.backgroundColour = NSColor.clear
        return theme
    }
    
    private var resultsToolbar: some View {
        HStack {
            Text("Results")
                .font(.headline)
            
            Spacer()
            
            switch viewState {
            case .idle:
                Text("Ready")
                    .foregroundColor(.secondary)
            case .loading:
                Text("Executing...")
                    .foregroundColor(.secondary)
            case .loaded(let result):
                Text("\(result.totalCount) rows")
                    .foregroundColor(.secondary)
            case .error:
                Text("Error")
                    .foregroundColor(.red)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color(NSColor.windowBackgroundColor))
    }
    
    private var resultsContent: some View {
        Group {
            switch viewState {
            case .idle:
                emptyState
            case .loaded(let result):
                resultTable(result: result)
            case .loading:
                EmptyView()
            case .error(let message):
                errorState(message: message)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var emptyState: some View {
        VStack(spacing: 12) {
            HStack(spacing: 4) {
                Text("Write a SQL query and press")
                    .font(.body)
                    .foregroundColor(.secondary.opacity(0.7))
                
                Text("⌘⏎")
                    .font(.callout)
                    .foregroundColor(.primary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color(.controlBackgroundColor))
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(Color(.separatorColor), lineWidth: 1)
                    )
                    .cornerRadius(4)
                
                Text("to execute")
                    .font(.body)
                    .foregroundColor(.secondary.opacity(0.7))
            }
            .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var emptyStateText: AttributedString {
        var text = AttributedString()
        
        if let range = text.range(of: "⌘⏎") {
            text[range].foregroundColor = .primary
            text[range].font = .system(size: 56, weight: .bold)
        }
        
        return text
    }
    
    private func errorState(message: String) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.red)
                    .padding(.top, 1)
                
                VStack(alignment: .leading, spacing: 4) {
                    // Check if this is a DatabaseError with rich information
                    if let error = lastError as? DatabaseError {
                        // Main error message
                        HStack {
                            Text("Error:")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.red)
                            
                            Text(message.sentenceCase)
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                                .lineLimit(2)
                        }
                        
                        // Show position indicator if available
                        if let position = error.position, let query = error.query {
                            VStack(alignment: .leading, spacing: 2) {
                                let (contextLines, caretLine) = buildPositionIndicatorParts(position: position, query: query)
                                
                                // Show context lines in secondary color
                                if !contextLines.isEmpty {
                                    Text(contextLines)
                                        .font(.system(size: 12, design: .monospaced))
                                        .foregroundColor(.secondary)
                                }
                                
                                // Show caret line in red
                                Text(caretLine)
                                    .font(.system(size: 12, design: .monospaced))
                                    .foregroundColor(.red)
                            }
                        }
                        
                        // Show hint if available
                        if let hint = error.hint, !hint.isEmpty {
                            Text("Hint: \(hint)")
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundColor(.secondary)
                        }
                        
                    } else {
                        // Fallback for non-DatabaseError errors
                        HStack {
                            Text("Error:")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.red)
                            
                            Text(message)
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                                .lineLimit(2)
                        }
                        
                    }
                }
                
                Spacer()
            }
            .padding(12)
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
    
    
    private func resultTable(result: QueryResult) -> some View {
        Group {
            if result.columns.isEmpty {
                VStack(alignment: .leading, spacing: 0) {
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 14, weight: .medium))
                            .padding(.top, 1)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Query executed successfully")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.primary)
                            
                            Text("No results returned")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                    }
                    .padding(12)
                    
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            } else {
                TableListViewController(
                    queryResult: result,
                    tableName: "SQL Query Result"
                )
            }
        }
    }
    
    private func executeQuery() {
        // Don't execute if we're showing an inline diff
        guard !showingInlineDiff else { return }
        
        // Determine what query to execute: selected text or full query
        let queryToExecute: String
        let trimmedSelectedText = selectedText.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if !trimmedSelectedText.isEmpty {
            queryToExecute = trimmedSelectedText
        } else {
            queryToExecute = sqlQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        
        guard !queryToExecute.isEmpty else { return }
        
        isExecuting = true
        viewState = .loading
        lastError = nil
        
        Task {
            let startTime = Date()
            
            do {
                let result = try await instance.databaseService.executeRawQuery(queryToExecute, databaseSchema: selectedDatabase)
                
                let executionTime = Date().timeIntervalSince(startTime)
                
                await MainActor.run {
                    viewState = .loaded(result)
                    lastExecutionTime = executionTime
                    lastRowCount = result.totalCount
                }
                
                // Add delay before resetting loading button state
                try? await Task.sleep(for: .milliseconds(250))
                
                await MainActor.run {
                    isExecuting = false
                }
            } catch {
                await MainActor.run {
                    viewState = .error(error.localizedDescription)
                    isExecuting = false
                    lastError = error
                    aiErrorSuggestion = nil // Reset previous suggestion
                }
                
                // Get AI suggestion for the error
                await getAIErrorSuggestion(for: queryToExecute, error: error)
            }
        }
    }
    
    private func getAIErrorSuggestion(for query: String, error: Error) async {
        await MainActor.run {
            isLoadingAISuggestion = true
            showAIErrorSuggestion = true
            originalQueryBeforeSuggestion = query
            originalFullEditorContent = sqlQuery
            executedQueryPosition = position
            
            // Show loading state in editor - keep original query visible
            sqlQuery = query
            showingInlineDiff = true
            
            // Clear any existing messages
            messages = Set()
        }
        
        do {
            let suggestion = try await performAIErrorAnalysis(query: query, error: error)
            await MainActor.run {
                aiErrorSuggestion = suggestion
                isLoadingAISuggestion = false
                
                // Show diff in editor - display both queries
                sqlQuery = formatDiffText(original: originalQueryBeforeSuggestion, suggested: suggestion)
                
                // Apply red/green highlighting with a slight delay to ensure text is set
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    applyDiffHighlighting(original: originalQueryBeforeSuggestion, suggested: suggestion)
                }
            }
        } catch {
            await MainActor.run {
                isLoadingAISuggestion = false
                showAIErrorSuggestion = false
                showingInlineDiff = false
                // Revert to original query on error
                sqlQuery = originalQueryBeforeSuggestion
                messages = Set()
            }
        }
    }
    
    private func performAIErrorAnalysis(query: String, error: Error) async throws -> String {
        let databaseType = instance.connection.databaseType.rawValue
        return try await AIService.analyzeError(query: query, error: error, databaseType: databaseType, databaseService: instance.databaseService)
    }
    
    private func formatDiffText(original: String, suggested: String?) -> String {
        guard let suggested = suggested else {
            return original
        }
        
        // Format both queries using SQL prettier for accurate comparison
        let formattedOriginal = formatSQL(original)
        let formattedSuggested = formatSQL(suggested)
        
        // Create git-like diff showing only changed lines
        let originalLines = formattedOriginal.components(separatedBy: .newlines)
        let suggestedLines = formattedSuggested.components(separatedBy: .newlines)
        
        var diffLines: [String] = []
        let maxLines = max(originalLines.count, suggestedLines.count)
        
        for i in 0..<maxLines {
            let originalLine = i < originalLines.count ? originalLines[i] : ""
            let suggestedLine = i < suggestedLines.count ? suggestedLines[i] : ""
            
            // Only show lines that are different
            if originalLine != suggestedLine {
                // Add original line (will be marked red)
                if !originalLine.isEmpty {
                    diffLines.append(originalLine)
                }
                // Add suggested line (will be marked green)
                if !suggestedLine.isEmpty {
                    diffLines.append(suggestedLine)
                }
            } else if !originalLine.isEmpty {
                // Keep unchanged lines as context
                diffLines.append(originalLine)
            }
        }
        
        return diffLines.joined(separator: "\n")
    }
    
    private func formatSQL(_ query: String) -> String {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQuery.isEmpty else { return query }
        
        // Determine the SQL dialect based on the database type
        let dialect: SQLDialect
        switch instance.connection.databaseType {
        case .postgres:
            dialect = .postgresql
        case .mongodb:
            dialect = .sqlite // MongoDB uses SQL-like queries, use SQLite as fallback
        case .mysql:
            dialect = .mysql
        case .sqlite:
            dialect = .sqlite
        default:
            dialect = .sqlite // Default fallback
        }
        
        // Configure formatting options for consistent diff comparison
        let options = SQLFormatOptions(
            tabWidth: 2,
            useTabs: false,
            keywordCase: .upper,
            dataTypeCase: .upper,
            functionCase: .upper,
            linesBetweenQueries: 1
        )
        
        // Format using the SQLFormatter
        return SQLFormatter.format(trimmedQuery, dialect: dialect, options: options)
    }
    
    private func applyDiffHighlighting(original: String, suggested: String?) {
        guard let suggested = suggested else { return }
        
        // Format both queries for accurate comparison (same as in formatDiffText)
        let formattedOriginal = formatSQL(original)
        let formattedSuggested = formatSQL(suggested)
        
        // Parse the formatted queries to track line types
        let originalLines = formattedOriginal.components(separatedBy: .newlines)
        let suggestedLines = formattedSuggested.components(separatedBy: .newlines)
        let displayedLines = sqlQuery.components(separatedBy: .newlines)
        
        // Clear any existing messages first
        messages = Set()
        var newMessages = Set<TextLocated<Message>>()
        
        // Track which lines in the display are original vs suggested
        var displayLineIndex = 0
        let maxLines = max(originalLines.count, suggestedLines.count)
        
        for i in 0..<maxLines {
            let originalLine = i < originalLines.count ? originalLines[i] : ""
            let suggestedLine = i < suggestedLines.count ? suggestedLines[i] : ""
            
            if originalLine != suggestedLine {
                // Lines are different - show both with colors
                
                // Add original line (red)
                if !originalLine.isEmpty && displayLineIndex < displayedLines.count {
                    let location = TextLocation(zeroBasedLine: displayLineIndex, column: 0)
                    let message = Message(
                        category: .error, // Red for original
                        length: displayedLines[displayLineIndex].count,
                        summary: "",
                        description: nil
                    )
                    newMessages.insert(TextLocated(location: location, entity: message))
                    displayLineIndex += 1
                }
                
                // Add suggested line (green)
                if !suggestedLine.isEmpty && displayLineIndex < displayedLines.count {
                    let location = TextLocation(zeroBasedLine: displayLineIndex, column: 0)
                    let message = Message(
                        category: .live, // Green for suggestion
                        length: displayedLines[displayLineIndex].count,
                        summary: "",
                        description: nil
                    )
                    newMessages.insert(TextLocated(location: location, entity: message))
                    displayLineIndex += 1
                }
            } else if !originalLine.isEmpty {
                displayLineIndex += 1
            }
        }
        
        messages = newMessages
    }
    
    private func acceptAISuggestion() {
        guard let suggestion = aiErrorSuggestion else { return }
        applyAISuggestionToEditor(suggestion: suggestion)
        cleanupSuggestionState()
        // Execute the corrected query immediately
        executeQuery()
    }
    
    private func acceptAISuggestionOnly() {
        guard let suggestion = aiErrorSuggestion else { return }
        applyAISuggestionToEditor(suggestion: suggestion)
        cleanupSuggestionState()
    }
    
    private func applyAISuggestionToEditor(suggestion: String) {
        // If we have a specific selection that was executed, replace only that part
        if !executedQueryPosition.selections.isEmpty && executedQueryPosition.selections[0].length > 0 {
            let selection = executedQueryPosition.selections[0]
            
            // Ensure the selection is still valid for the original content
            guard selection.location + selection.length <= originalFullEditorContent.count else {
                // Fallback: replace entire content if selection is invalid
                sqlQuery = suggestion
                return
            }
            
            // Replace only the selected part with the suggestion
            let startIndex = originalFullEditorContent.index(originalFullEditorContent.startIndex, offsetBy: selection.location)
            let endIndex = originalFullEditorContent.index(startIndex, offsetBy: selection.length)
            
            var newContent = originalFullEditorContent
            newContent.replaceSubrange(startIndex..<endIndex, with: suggestion)
            sqlQuery = newContent
            
            // Update the position to select the new suggestion
            let newSelectionRange = NSRange(location: selection.location, length: suggestion.count)
            position = CodeEditor.Position(selections: [newSelectionRange], verticalScrollPosition: position.verticalScrollPosition)
            
        } else {
            // No specific selection was made, replace entire content
            sqlQuery = suggestion
        }
    }
    
    private func rejectAISuggestion() {
        // Restore the original full editor content, not just the executed query
        sqlQuery = originalFullEditorContent
        position = executedQueryPosition
        cleanupSuggestionState()
    }
    
    private func cleanupSuggestionState() {
        aiErrorSuggestion = nil
        showAIErrorSuggestion = false
        showingInlineDiff = false
        originalQueryBeforeSuggestion = ""
        originalFullEditorContent = ""
        executedQueryPosition = CodeEditor.Position()
        messages = Set()
    }
    
    private func prettifySQL() {
        // Don't prettify if we're showing an inline diff
        guard !showingInlineDiff else { return }
        
        let trimmedQuery = sqlQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQuery.isEmpty else { return }
        
        // Determine the SQL dialect based on the database type
        let dialect: SQLDialect
        switch instance.connection.databaseType {
        case .postgres:
            dialect = .postgresql
        case .mongodb:
            dialect = .sqlite // MongoDB uses SQL-like queries, use SQLite as fallback
        case .mysql:
            dialect = .mysql
        case .sqlite:
            dialect = .sqlite
        default:
            dialect = .sqlite // Default fallback
        }
        
        // Configure formatting options
        let options = SQLFormatOptions(
            tabWidth: 2,
            useTabs: false,
            keywordCase: .upper,
            dataTypeCase: .upper,
            functionCase: .upper,
            linesBetweenQueries: 1
        )
        
        // Format using the SQLFormatter
        let formattedSQL = SQLFormatter.format(trimmedQuery, dialect: dialect, options: options)
        sqlQuery = formattedSQL
    }
    
    private func addToFavorites() {
        // TODO: Implement add to favorites functionality
        // For now, just show that it was triggered
        let trimmedQuery = sqlQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedQuery.isEmpty {
            // This would typically save to UserDefaults or Core Data
        }
    }
    
    private func getCurrentQuery() -> String? {
        let trimmed = sqlQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
    
    private func buildPositionIndicatorParts(position: Int, query: String) -> (contextLines: String, caretLine: String) {
        // Handle multiline queries by finding the correct line and column
        let lines = query.components(separatedBy: .newlines)
        var currentPosition = 0
        
        for (lineIndex, line) in lines.enumerated() {
            let lineLength = line.count + 1 // +1 for newline character
            
            if currentPosition + lineLength > position {
                // The error is on this line
                let columnPosition = position - currentPosition
                let spaces = String(repeating: " ", count: max(0, columnPosition))
                
                // Build context lines (everything except the caret)
                var contextLines = ""
                
                // Add previous lines for context (max 2 lines before)
                let startLine = max(0, lineIndex - 2)
                for i in startLine..<lineIndex {
                    if !contextLines.isEmpty { contextLines += "\n" }
                    contextLines += lines[i]
                }
                
                // Add the error line
                if !contextLines.isEmpty { contextLines += "\n" }
                contextLines += line
                
                // Add next lines for context (max 2 lines after)
                let endLine = min(lines.count, lineIndex + 3)
                for i in (lineIndex + 1)..<endLine {
                    contextLines += "\n" + lines[i]
                }
                
                // Build the red caret line
                let caretLine = "\(spaces)^"
                
                return (contextLines, caretLine)
            }
            
            currentPosition += lineLength
        }
        
        // Fallback to original behavior if position not found
        let spaces = String(repeating: " ", count: max(0, position - 1))
        return (query, "\(spaces)^")
    }
    
    private func buildPositionIndicator(position: Int, query: String) -> String {
        let (contextLines, caretLine) = buildPositionIndicatorParts(position: position, query: query)
        return "\(contextLines)\n\(caretLine)"
    }
    
    private func loadAvailableDatabases() {
        Task {
            await MainActor.run {
                // Show only the current connected database
                if let currentDatabase = instance.databaseService.currentDatabase {
                    self.availableDatabases = [currentDatabase]
                    self.selectedDatabase = currentDatabase.name
                } else {
                    self.availableDatabases = []
                    self.selectedDatabase = ""
                }
            }
        }
    }
}

enum SQLEditorViewState: Equatable {
    case idle
    case loading
    case loaded(QueryResult)
    case error(String)
    
    static func == (lhs: SQLEditorViewState, rhs: SQLEditorViewState) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle), (.loading, .loading):
            return true
        case (.error(let lhsMessage), .error(let rhsMessage)):
            return lhsMessage == rhsMessage
        case (.loaded(let lhsResult), .loaded(let rhsResult)):
            return lhsResult.totalCount == rhsResult.totalCount
        default:
            return false
        }
    }
}

