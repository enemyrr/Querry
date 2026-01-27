//
//  AICommandPrompt.swift
//  Pluk
//
//  Created by Claude on 9/3/25.
//

import SwiftUI
import AIProxy
import PostHog

struct AICommandPrompt: View {
    @Environment(ConnectionInstance.self) private var instance
    @Binding var isPresented: Bool
    @Binding var generatedQuery: String
    let cursorLineNumber: Int
    let selectedText: String
    @State private var userPrompt: String = ""
    @State private var isGenerating: Bool = false
    @State private var hasError: Bool = false
    @FocusState private var isTextFieldFocused: Bool
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            TextField(selectedText.isEmpty ? "What do you want to generate?" : "What do you want to do with the selected query?", text: $userPrompt)
                .padding(.leading, 4)
                .textFieldStyle(.plain)
                .focused($isTextFieldFocused)
                .onChange(of: userPrompt) { _, _ in
                    hasError = false
                }
            
            HStack {
                // Primary action
                if !isGenerating {
                    Button(action: {
                        Task {
                            await generateCommand()
                        }
                    }) {
                        Text("Generate ⏎")
                    }
                    .buttonStyle(AICommandPromptPrimaryButtonStyle())
                    .disabled(userPrompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .keyboardShortcut(.return, modifiers: [])
                }
                
                // Secondary action
                Button(action: {
                    isPresented = false
                }) {
                    HStack(spacing: 4) {
                        Text("Cancel")
                        Text("ESC")
                            .opacity(0.6)
                    }
                }
                .font(.callout)
                .buttonStyle(AICommandPromptSecondaryButtonStyle())
                .keyboardShortcut(.escape, modifiers: [])
                
                if isGenerating {
                    ProgressView()
                        .controlSize(.mini)
                } else if hasError {
                    Text("Something went wrong. Please try again.")
                        .font(.caption)
                        .foregroundColor(.red)
                        .lineLimit(1)
                }
                
                if !isGenerating {
                    Button("") {
                        Task {
                            await generateCommand()
                        }
                    }
                    .hidden()
                    .keyboardShortcut(.return, modifiers: [.command])
                }
            }
        }
        .padding(8)
        .foregroundColor(.secondary)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(.separator, lineWidth: 0.5)
        )
        .shadow(color: Color(.sRGBLinear, white: 0, opacity: 0.05), radius: 4)
        .frame(width: 450)
        .offset(y: CGFloat(cursorLineNumber * 16)) // Position based on line number
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                isTextFieldFocused = true
            }
        }
    }
    
    private func generateCommand() async {
        let userMessage = userPrompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !userMessage.isEmpty else { return }

        isGenerating = true
        hasError = false

        do {
            var result = ""
            var isFirstToken = true

            for try await chunk in AIService.generateSQL(
                prompt: userMessage,
                selectedText: selectedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : selectedText,
                databaseService: instance.databaseService
            ) {
                result += chunk
                // Hide loading and close prompt on first token
                if isFirstToken {
                    await MainActor.run {
                        isGenerating = false
                        isPresented = false
                    }
                    isFirstToken = false
                }
                // Stream each chunk to the editor
                await MainActor.run {
                    generatedQuery = result
                }
            }

            AnalyticsService.shared.trackAIQueryGeneration(
                hasSelectedText: !selectedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                databaseType: instance.connection.databaseType,
                promptLength: userMessage.count,
                success: true
            )
            hasError = false
        } catch {
            await MainActor.run {
                isGenerating = false
                hasError = true
            }

            await MainActor.run {
                AnalyticsService.shared.trackAIQueryGeneration(
                    hasSelectedText: !selectedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                    databaseType: instance.connection.databaseType,
                    promptLength: userMessage.count,
                    success: false
                )
            }
            debugLog(error)
        }
    }
}
