//
//  AISearchView.swift
//  Collection
//
//  Created by Fauzaan on 3/14/25.
//

import SwiftUI
import AIProxy
import Combine
import PostHog

struct AISearchView: View {
    @Binding var filter: String
    let showQueryEditor: Bool
    let tableName: String
    @Binding var isSubmitAnimating: Bool
    @Binding var processingStage: ProcessingStage
    let onBack: () -> Void
    let onLoadDocuments: (_ filter: String) -> Void
    let onRefresh: () -> Void
    
    @Environment(ConnectionInstance.self) private var instance
    @FocusState private var isSearchFocused: Bool
    @State private var filterQuery: String = ""
    @State private var search: String = ""
    
    var body: some View {
        VStack(spacing: 6) {
            // First row: Full width input field
            mainInputSection
                .padding(.leading, 8)
            
            // Second row: Action buttons
            actionButtonsSection
        }
        .padding(.top, 10)
        .padding(10)
        // Add refresh keyboard shortcut
        .overlay(
            Button("") {
                onRefresh()
            }
            .keyboardShortcut("r", modifiers: .command)
            .opacity(0)
            .frame(width: 0, height: 0)
        )
        .frame(maxWidth: 500)
    }
    
    // MARK: - View Components
    
    @ViewBuilder
    private var mainInputSection: some View {
        HStack {
            searchTextField
        }
        .frame(maxWidth: .infinity)
    }
    
    @ViewBuilder
    private var actionButtonsSection: some View {
        HStack(alignment: .bottom, spacing: 12) {
            // Left side tools
            leftToolsSection
                .padding(.bottom, 4)
                .padding(.leading, 6)
            
            Spacer()
            
            // Right side controls
            rightControlsSection
        }
    }
    
    @ViewBuilder
    private var leftToolsSection: some View {
        HStack(spacing: 8) {
            HStack(spacing: 4) {
                Image(systemName: "table")
                    .foregroundStyle(.secondary)
                    .font(.caption)
                Text(tableName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 4)
            .padding(.horizontal, 6)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(.separator, lineWidth: 1)
            )
            .customHelp("This table schema is shared with LLM provider", delay: 0.2, position: .top, shortcut: nil, spacing: 4)
        }
    }
    
    @ViewBuilder
    private var rightControlsSection: some View {
        HStack(alignment: .bottom) {
            Button(action: onBack) {
                HStack(spacing: 4) {
                    Text("Close")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    Text("ESC")
                        .font(.caption2)
                        .padding(.vertical, 2)
                        .padding(.horizontal, 6)
                        .background(
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color(.controlColor).opacity(0.3))
                        )
                }
            }
            .keyboardShortcut(.escape, modifiers: [])
            .buttonStyle(AIBackButtonStyle())
            
            if processingStage != .idle {
                Button(action: {
                    cancelProcessing()
                }) {
                    Image(systemName: "stop.fill")
                        .font(.system(size: 13, weight: .bold))
                }
                .buttonStyle(ChatSendButtonStyle())
            } else {
                Button(action: {
                    Task {
                        PostHogSDK.shared.capture("ai_search")
                        await processNaturalLanguageQuery(search: search)
                    }
                }) {
                    Image(systemName: "arrow.up")
                        .font(.system(size: 13, weight: .bold))
                }
                .buttonStyle(ChatSendButtonStyle())
                .disabled(search.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
    }
    

    
    @ViewBuilder
    private var searchTextField: some View {
        TextField("Ask what to find (e.g. id: 2)...", text: $search)
            .textFieldStyle(.plain)
            .focused($isSearchFocused)
            .onSubmit {
                Task {
                    await processNaturalLanguageQuery(search: search)
                }
            }
            .task {
                isSearchFocused = true
            }
            .onChange(of: showQueryEditor, {
                isSearchFocused = true
            })
            .disabled(processingStage != .idle)
            .padding(.bottom, processingStage != .idle ? 2 : 0)
    }
    
    // MARK: - Processing Logic
    
    private func cancelProcessing() {
        processingStage = .idle
        // Cancel any ongoing AI request if possible
    }
    
    // MARK: - AI Request Methods
    
    /// Submits a natural language query to AI service and processes the result
    private func processNaturalLanguageQuery(search: String) async {
        guard !search.isEmpty else { return }
        
        await MainActor.run {
            processingStage = .writingQuery
        }

        do {
            filter = try await performAIQuery(databaseService: instance.databaseService, search: search)
            
            await processQueryResult(filter)
        } catch {
            await handleQueryError(error)
        }
    }
    
    private func performAIQuery(databaseService: DatabaseService, search: String) async throws -> String {
        guard let selectedTab = instance.selectedTab?.name else {
            fatalError("Database driver not set yet")
        }
        
        let prompt = try await instance.databaseService.buildSystemPrompt(for: selectedTab)
        
        let openAIService = AIProxy.openAIService(
            partialKey: "v2|3fe1f505|AS4tm59nSGxScFCN",
            serviceURL: "https://api.aiproxy.pro/4c1638f9/2f62a0df"
        )
        
        let stream = try await openAIService.streamingChatCompletionRequest(
            body: .init(
                model: "gpt-4.1-mini",
                messages: [
                    .user(content: .text(search)),
                    .system(content: .text(prompt))
                ]
            )
        )
        
        var result = ""
        for try await chunk in stream {
            if let content = chunk.choices.first?.delta.content {
                result += content
            }
        }
        
        return result
    }
    
    @MainActor
    private func processQueryResult(_ result: String) async {
        filterQuery = result
        search = ""
        
        onLoadDocuments(filterQuery)
        
        // Trigger scale animation on submit
        withAnimation(.easeInOut(duration: 0.15)) {
            isSubmitAnimating = true
        }
        
        // Reset animation after a short delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            withAnimation(.easeInOut(duration: 0.15)) {
                isSubmitAnimating = false
                processingStage = .idle
                isSearchFocused = true
            }
        }
        
    }
    
    @MainActor
    private func handleQueryError(_ error: Error) async {
        if let aiError = error as? AIProxyError,
           case .unsuccessfulRequest(let statusCode, let responseBody) = aiError {
            debugLog("Error: Received \(statusCode) status code with response body: \(responseBody)")
        } else {
            debugLog("Error: Could not create Message: \(error.localizedDescription)")
        }
        processingStage = .idle
    }
}


// MARK: - Processing Stage Enum
/// Represents the different stages of query processing
public enum ProcessingStage: Int {
    case idle = 0
    case writingQuery = 1
    case fetchingData = 2
    
    var description: String {
        switch self {
        case .idle:
            return ""
        case .writingQuery:
            return "Writing query"
        case .fetchingData:
            return "Fetching data"
        }
    }
}
