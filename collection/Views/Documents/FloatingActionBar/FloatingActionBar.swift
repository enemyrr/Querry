//
//  FloatingActionBar.swift
//  Collection
//
//  Created by Fauzaan on 2/26/25.
//

import SwiftUI
import AIProxy

let anthropicService = AIProxy.anthropicService(
    partialKey: "v2|7052267d|N7VQjRQ4F47T6FKQ",
    serviceURL: "https://api.aiproxy.pro/4c1638f9/11e0b28c"
)


let openAIService = AIProxy.openAIService(
    partialKey: "v2|3fe1f505|AS4tm59nSGxScFCN",
    serviceURL: "https://api.aiproxy.pro/4c1638f9/2f62a0df"
)

struct FloatingActionBar: View {
    @ObservedObject var viewModel: DocumentViewModel
    @State private var action: ActionBar = ActionBar.main
    @State private var search: String = ""
    @State private var aiResponse: String = ""
    @State private var isLoading: Bool = false
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        HStack {
            switch action {
            case .main:
                mainView
            case .search:
                searchView
            }
        }
        .modifier(GlassBackgroundStyle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(.separator, lineWidth: 1)
        )
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: viewModel.actionBarUpdateTrigger)
    }
    
    private var mainView: some View {
        HStack(spacing: 5) {
            Pagination(viewModel: viewModel)
            
            Divider()
                .frame(height: 22)
                .padding(.vertical, 6)
            
            Button(action: {
                withAnimation(.spring(response: 0.3)) {
                    action = ActionBar.search
                }
            }) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 14))
                    .contentShape(Rectangle())
            }
            .buttonStyle(ActionButtonStyle(padding: EdgeInsets(top: 7, leading: 8, bottom: 7, trailing: 8)))
            .keyboardShortcut("p", modifiers: .command)
            .customHelp("Filter documents", position: .top, shortcut: KeyboardShortcut(
                modifiers: [.command],
                key: "P"
            ), spacing: 10)
            
            Divider()
                .frame(height: 22)
                .padding(.vertical, 6)
            
            // Action buttons for pending operations
            Group {
                // Batch delete button - only show when there are documents marked for deletion
                if viewModel.pendingActionsCount(for: .delete) > 0 {
                    DeleteActionButton(
                        deleteCount: viewModel.pendingActionsCount(for: .delete),
                        isProcessingBatch: viewModel.isProcessingBatch,
                        onDelete: {
                            Task {
                                await viewModel.commitPendingActions()
                            }
                        }
                    )
                    .padding(.horizontal, 2)
                    
                    Divider()
                        .frame(height: 22)
                        .padding(.vertical, 6)
                }
                
                // Batch update button - only show when there are documents marked for update
                if viewModel.pendingActionsCount(for: .update) > 0 {
                    UpdateActionButton(
                        updateCount: viewModel.pendingActionsCount(for: .update),
                        isProcessingBatch: viewModel.isProcessingBatch,
                        onUpdate: {
                            Task {
                                await viewModel.commitPendingActions()
                            }
                        }
                    )
                    
                    Divider()
                        .frame(height: 22)
                        .padding(.vertical, 6)
                }
            }
            
            // More options button
            Button(action: {
                // TODO:
                // Add an action
            }) {
                Image(systemName: "ellipsis")
                    .font(.system(size: 14))
                    .contentShape(Rectangle())
            }
            .buttonStyle(ActionButtonStyle(padding: EdgeInsets(top: 12, leading: 8, bottom: 12, trailing: 8)))
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 4)
    }
    
    @State private var shimmerAction = IntelligenceUIPlatterView.ShimmerAction()
    @FocusState private var isSearchFocused: Bool
    
    private var searchView: some View {
        VStack(spacing: 10) {
            HStack(spacing: 8) {
                // Back button
                Button(action: {
                    withAnimation(.spring(response: 0.3)) {
                        action = ActionBar.main
                        aiResponse = ""
                    }
                }) {
                    Image(systemName: "arrow.backward")
                        .font(.system(size: 12))
                        .contentShape(Rectangle())
                }
                .buttonStyle(ActionButtonStyle(padding: EdgeInsets(top: 7, leading: 8, bottom: 7, trailing: 8), isActive: true))
                .keyboardShortcut(.escape, modifiers: [])
                .customHelp("To go back", position: .top, shortcut: KeyboardShortcut(
                    modifiers: [],
                    key: "Esc"
                ))
                
                // Search field container
                HStack {
                    TextField("Ask AI anything...", text: $search)
                        .focusSection()
                        .focused($isSearchFocused)
                        .textFieldStyle(.plain)
                        .font(.system(size: 15))
                        .frame(width: 450)
                        .onSubmit {
                            submitAIRequest()
                            shimmerAction()
                        }
                        .onAppear {
                            // Set focus after a slight delay to ensure view hierarchy is ready
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                isSearchFocused = true
                            }
                        }
                    
                    ProgressView().controlSize(.small).opacity(isLoading ? 1 : 0)
                }
                .padding(.vertical, 8)
            }
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 4)
        .background(
            IntelligenceUIPlatterView()
                .cornerRadius(8)
                .hasExteriorLight(false)
                .shimmerOn(shimmerAction)
        ).transition(.opacity.animation(.easeInOut(duration: 0.2)))
    }
}

enum ActionBar: String, CaseIterable, Codable {
    case main = "main"
    case search = "search"
}

// MARK: - AI Request Functions
extension FloatingActionBar {
    func submitAIRequest() {
        guard !search.isEmpty else { return }
        
        isLoading = true
        
        Task {
            do {
                let response = try await openAIService.chatCompletionRequest(body: .init(
                    model: "gpt-4o-mini",
                    messages: [
                        .user(content: .text(search)),
                        .developer(content: .text("""
                    You are a MongoDB query assistant for a GUI application that uses Swift with Kitten support. Your primary task is to convert natural language user queries into valid MongoDB filter queries.
                    
                    # Core Responsibilities
                    - Convert user questions and requests into MongoDB filter queries
                    - Return ONLY the MongoDB query without explanation
                    - Optimize queries for best performance
                    - Support all MongoDB operators and query features

                    # Response Format
                    - Return ONLY the MongoDB query in Swift syntax with Kitten support
                    - Do not include any explanation, preamble, or commentary
                    - Format the query for readability with proper indentation
                    - One-line queries are acceptable for simple filters

                    # Examples
                    <example>
                    user: Find all users where age is greater than 30
                    assistant: Filter<User>(.age > 30)
                    </example>

                    <example>
                    user: Get documents where status is active and created date is in the last week
                    assistant: Filter<Document>(.and([
                        .status == "active",
                        .createdAt > Date().addingTimeInterval(-604800)
                    ]))
                    </example>

                    <example>
                    user: Show me customers from New York or California with at least 5 orders
                    assistant: Filter<Customer>(.and([
                        .or([
                            .state == "New York",
                            .state == "California"
                        ]),
                        .orders.count >= 5
                    ]))
                    </example>

                    # Important Rules
                    - NEVER provide explanations or ask clarifying questions
                    - NEVER describe what the query does
                    - Return ONLY the MongoDB query code
                    - Use Swift syntax with Kitten support (.and, .or, etc.)
                    - When user input is ambiguous, make reasonable assumptions about field names and types
                    - If a query cannot be created, return "Invalid query" without explanation

                    # MongoDB Kitten Swift Syntax Guidelines
                    - Use Filter<TypeName> for all queries
                    - Simple comparisons: .fieldName == value, .fieldName > value
                    - Logical operators: .and([...]), .or([...]), .not(...)
                    - Array operators: .in, .all, .elemMatch
                    - Text search: .text("search string")
                    - Regular expressions: .regex("pattern", "options")
                    - Geospatial: .near, .geoWithin

                    Remember: Your job is to convert natural language to MongoDB queries ONLY. No explanations, no discussion.
                    """))
                        ]
                ))
//                print(response.choices.first?.message.content ?? "")
                
//                let response = try await anthropicService.messageRequest(body: AnthropicMessageRequestBody(
//                    maxTokens: 1024,
//                    messages: [
//                        AnthropicInputMessage(content: [.text(search)], role: .user)
//                    ],
//                    model: "claude-3-haiku-20240307",
//                    system:  """
//                    You are a MongoDB query assistant for a GUI application that uses Swift with Kitten support. Your primary task is to convert natural language user queries into valid MongoDB filter queries.
//                    
//                    # Core Responsibilities
//                    - Convert user questions and requests into MongoDB filter queries
//                    - Return ONLY the MongoDB query without explanation
//                    - Optimize queries for best performance
//                    - Support all MongoDB operators and query features
//
//                    # Response Format
//                    - Return ONLY the MongoDB query in Swift syntax with Kitten support
//                    - Do not include any explanation, preamble, or commentary
//                    - Format the query for readability with proper indentation
//                    - One-line queries are acceptable for simple filters
//
//                    # Examples
//                    <example>
//                    user: Find all users where age is greater than 30
//                    assistant: Filter<User>(.age > 30)
//                    </example>
//
//                    <example>
//                    user: Get documents where status is active and created date is in the last week
//                    assistant: Filter<Document>(.and([
//                        .status == "active",
//                        .createdAt > Date().addingTimeInterval(-604800)
//                    ]))
//                    </example>
//
//                    <example>
//                    user: Show me customers from New York or California with at least 5 orders
//                    assistant: Filter<Customer>(.and([
//                        .or([
//                            .state == "New York",
//                            .state == "California"
//                        ]),
//                        .orders.count >= 5
//                    ]))
//                    </example>
//
//                    # Important Rules
//                    - NEVER provide explanations or ask clarifying questions
//                    - NEVER describe what the query does
//                    - Return ONLY the MongoDB query code
//                    - Use Swift syntax with Kitten support (.and, .or, etc.)
//                    - When user input is ambiguous, make reasonable assumptions about field names and types
//                    - If a query cannot be created, return "Invalid query" without explanation
//
//                    # MongoDB Kitten Swift Syntax Guidelines
//                    - Use Filter<TypeName> for all queries
//                    - Simple comparisons: .fieldName == value, .fieldName > value
//                    - Logical operators: .and([...]), .or([...]), .not(...)
//                    - Array operators: .in, .all, .elemMatch
//                    - Text search: .text("search string")
//                    - Regular expressions: .regex("pattern", "options")
//                    - Geospatial: .near, .geoWithin
//
//                    Remember: Your job is to convert natural language to MongoDB queries ONLY. No explanations, no discussion.
//                    """
//                ))
//                
                var fullResponse = ""
                
                fullResponse = response.choices.first?.message.content ?? "No response"
//                for content in response.content {
//                    if case .text(let message) = content {
//                           fullResponse = message
//                       }
//                }
                
                print(fullResponse)
                await MainActor.run {
                    aiResponse = fullResponse
                }
            } catch AIProxyError.unsuccessfulRequest(let statusCode, let responseBody) {
                await MainActor.run {
                    aiResponse = "Error: Received \(statusCode) status code with response body: \(responseBody)"
                }
            } catch {
                await MainActor.run {
                    aiResponse = "Error: Could not create an Anthropic message: \(error.localizedDescription)"
                }
            }
            
            await MainActor.run {
                isLoading = false
            }
        }
    }
}

// MARK: - Action Buttons

struct DeleteActionButton: View {
    let deleteCount: Int
    let isProcessingBatch: Bool
    let onDelete: () -> Void
    
    var body: some View {
        Button(action: onDelete) {
            HStack(spacing: 4) {
                Image(systemName: "trash")
                    .font(.system(size: 12))
                Text("\(deleteCount)")
                    .font(.system(size: 12, weight: .medium))
            }
            .foregroundColor(.white)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color.red.opacity(isProcessingBatch ? 0.7 : 1))
            .cornerRadius(6)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(isProcessingBatch)
        .transition(.scale.combined(with: .opacity))
    }
}

struct UpdateActionButton: View {
    let updateCount: Int
    let isProcessingBatch: Bool
    let onUpdate: () -> Void
    
    var body: some View {
        Button(action: onUpdate) {
            HStack(spacing: 4) {
                Image(systemName: "pencil")
                    .font(.system(size: 12))
                Text("\(updateCount)")
                    .font(.system(size: 12, weight: .medium))
            }
            .foregroundColor(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.blue.opacity(isProcessingBatch ? 0.7 : 1))
            .cornerRadius(6)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(isProcessingBatch)
        .customHelp("Update \(updateCount) marked documents", position: .top, spacing: 4)
    }
}

