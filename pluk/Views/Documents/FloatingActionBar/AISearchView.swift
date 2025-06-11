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
    var viewModel: DocumentListModel
    var selectedTab: DatabaseTab
    
    @FocusState private var isSearchFocused: Bool
    @State private var filterQuery: String = ""
    @State private var processingStage: ProcessingStage = .idle
    @State private var search: String = ""
    @State private var animationDots: String = ""
    
    // Timer using async/await instead of Timerd
    @State private var animationTask: Task<Void, Never>?
    
    var body: some View {
        HStack(spacing: 8) {
            searchInputSection
            actionButtonSection
        }
        .frame(height: 34)
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(IntelligenceUIPlatterView())
        .task(id: processingStage) {
            await handleProcessingStageChange()
        }
        .onDisappear {
            animationTask?.cancel()
        }
    }
    
    // MARK: - View Components
    
    @ViewBuilder
    private var searchInputSection: some View {
        HStack(spacing: 12) {
            if processingStage != .idle {
                processingText
            } else {
                searchTextField
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 8)
        .animation(.easeInOut, value: processingStage)
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
    }
    
    @ViewBuilder
    private var searchTextField: some View {
        TextField("Ask what to find (e.g. id: 2)...", text: $search)
            .focusSection()
            .font(.system(.body, design: .monospaced))
            .focused($isSearchFocused)
            .textFieldStyle(.plain)
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
    }
    
    @ViewBuilder
    private var actionButtonSection: some View {
        HStack {
            if processingStage != .idle {
                Button("Stop", systemImage: "stop.fill") {
                    cancelProcessing()
                }
                .labelStyle(.iconOnly)
                .font(.system(size: 12))
                .buttonStyle(.plain)
                .padding(6)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(.white.opacity(0.1))
                )
            }
        }
        .padding(.vertical, 4)
        .padding(.trailing, 2)
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
        guard !search.isEmpty else { return }
        
        processingStage = .writingQuery
        
        do {
            let result = try await performAIQuery(search: search)
            await processQueryResult(result)
        } catch {
            await handleQueryError(error)
        }
    }
    
    private func performAIQuery(search: String) async throws -> String {
        guard let prompt = try await viewModel.instance.databaseDriver?.buildSystemPrompt(for: selectedTab.name) else {
            fatalError("Database driver not set yet")
        }
        
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
        
        await viewModel.loadDocuments(filter: filterQuery)
        
        // Delay before resetting state
        try? await Task.sleep(for: .seconds(1.1))
        processingStage = .idle
        isSearchFocused = false
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
