//
//  AISearchView.swift
//  Collection
//
//  Created by Fauzaan on 3/14/25.
//

import SwiftUI
import AIProxy
import Combine

struct AISearchView: View {
    @Binding var filter: String
    let showQueryEditor: Bool
    let tableName: String
    @Binding var isSubmitAnimating: Bool
    let onBack: () -> Void
    let onLoadDocuments: (_ filter: String) -> Void
    
    @Environment(ConnectionInstance.self) private var instance
    @FocusState private var isSearchFocused: Bool
    @State private var filterQuery: String = ""
    @State private var processingStage: ProcessingStage = .idle
    @State private var search: String = ""
    @State private var animationDots: String = ""

    
    // Timer using async/await instead of Timerd
    @State private var animationTask: Task<Void, Never>?
    
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
        .task(id: processingStage) {
            await handleProcessingStageChange()
        }
        .onDisappear {
            animationTask?.cancel()
        }
    }
    
    // MARK: - View Components
    
    @ViewBuilder
    private var mainInputSection: some View {
        HStack {
            if processingStage != .idle {
                processingText
            } else {
                searchTextField
            }
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
        HStack {
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
            .customHelp("This schema shared with LLM provider for query generation", delay: 0.2, position: .right, shortcut: nil, spacing: 6)
        }
    }
    
    @ViewBuilder
    private var rightControlsSection: some View {
        HStack(spacing: 8) {
            if processingStage != .idle {
                Button(action: {
                    cancelProcessing()
                }) {
                    Image(systemName: "stop.fill")
                        .font(.system(size: 14, weight: .bold))
                }
                .buttonStyle(ChatSendButtonStyle())
            } else {
                Button(action: {
                    Task {
                        await processNaturalLanguageQuery(search: search)
                    }
                }) {
                    Image(systemName: "arrow.up")
                        .font(.system(size: 14, weight: .bold))
                }
                .buttonStyle(ChatSendButtonStyle())
                .disabled(search.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
    }
    
    @ViewBuilder
    private var processingText: some View {
        Text(processingStage.description + animationDots)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .transition(.push(from: .bottom))
            .id("processing-\(processingStage.description)")
            .animation(
                .interpolatingSpring(stiffness: 50, damping: 10),
                value: processingStage
            )
            .padding(.bottom, 1)
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
            .transition(.opacity)
            .animation(.easeInOut(duration: 0.3), value: processingStage)
            .onChange(of: showQueryEditor, {
                isSearchFocused = true
            })
    }
    
    // MARK: - Processing Logic
    
    private func handleProcessingStageChange() async {
        if processingStage != .idle {
            await startProcessingAnimation()
        } else {
            stopProcessingAnimation()
        }
    }
    
    private func startProcessingAnimation() async {
        animationTask = Task {
            while !Task.isCancelled && processingStage != .idle {
                animationDots = animationDots.count >= 3 ? "" : animationDots + "."
                try? await Task.sleep(for: .milliseconds(500))
            }
        }
    }
    
    private func stopProcessingAnimation() {
        animationTask?.cancel()
        animationTask = nil
        animationDots = ""
    }
    
    private func cancelProcessing() {
        animationTask?.cancel()
        processingStage = .idle
        // Cancel any ongoing AI request if possible
    }
    
    // MARK: - AI Request Methods
    
    /// Submits a natural language query to AI service and processes the result
    private func processNaturalLanguageQuery(search: String) async {
        guard let databaseService = instance.databaseService else {
            fatalError("Database driver not set yet")
        }
        guard !search.isEmpty else { return }
        
        processingStage = .writingQuery
        
        do {
            filter = try await performAIQuery(databaseService: databaseService, search: search)
            
            await processQueryResult(filter)
        } catch {
            await handleQueryError(error)
        }
    }
    
    private func performAIQuery(databaseService: DatabaseService, search: String) async throws -> String {
        guard let databaseService = instance.databaseService, let selectedTab = instance.selectedTab?.name else {
            fatalError("Database driver not set yet")
        }
        
        let prompt = try await databaseService.buildSystemPrompt(for: selectedTab)
        
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
                isSearchFocused = false
                
            }
        }
        
    }
    
    @MainActor
    private func handleQueryError(_ error: Error) async {
        if let aiError = error as? AIProxyError,
           case .unsuccessfulRequest(let statusCode, let responseBody) = aiError {
            print("Error: Received \(statusCode) status code with response body: \(responseBody)")
        } else {
            print("Error: Could not create Message: \(error.localizedDescription)")
        }
        processingStage = .idle
    }
}

