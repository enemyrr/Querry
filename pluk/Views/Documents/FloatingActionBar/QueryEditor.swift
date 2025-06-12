//
//  QueryEditor.swift
//  Collection
//
//  Created by Fauzaan on 3/16/25.
//

import SwiftUI
import LanguageSupport
import OnTapOutsideGesture

struct QueryEditor: View {
    @Binding var showQueryEditor: Bool
    @Binding var filter: String
    let isLoading: Bool
    let totalCount: Int
    let onLoadDocuments: (_ filter: String?) -> Void
    
    @State private var position: CodeEditor.Position = CodeEditor.Position()
    @State private var messages: Set<TextLocated<Message>> = Set()
    @State private var isExpanded: Bool = false
    @State private var showEditor: Bool = false
    @State private var showClearQueryButton: Bool = false
    @State private var queryStartTime: Date?
    @State private var lastExecutionTime: TimeInterval = 0
    @State private var lastQueryCompletionTime: Date?
    @State private var displayedQueryExecutionTime: String = ""
    
    private var queryExecutionTime: String {
        if isLoading && displayedQueryExecutionTime.isEmpty {
            return "executing..."
        } else if !displayedQueryExecutionTime.isEmpty {
            return displayedQueryExecutionTime
        } else {
            return ""
        }
    }
    
    private var lastQueryTime: String {
        if let completionTime = lastQueryCompletionTime {
            let timeInterval = Date().timeIntervalSince(completionTime)
            
            if timeInterval < 1 {
                let milliseconds = Int(timeInterval * 1000)
                return "\(milliseconds)ms ago"
            } else if timeInterval < 60 {
                return String(format: "%.0fs ago", timeInterval)
            } else if timeInterval < 3600 {
                let minutes = Int(timeInterval / 60)
                return "\(minutes)m ago"
            } else {
                let hours = Int(timeInterval / 3600)
                return "\(hours)h ago"
            }
        } else {
            return ""
        }
    }
    
    var body: some View {
        HStack(alignment: .bottom, spacing: 4) {
            VStack {
                if isExpanded {
                    fullQueryEditorView()
                        .onTapOutsideGesture {
                            closeWithAnimation()
                        }
                        .onKeyPress(.escape) {
                            closeWithAnimation()
                            return .handled
                        }
                }
            }
            .fixedSize(horizontal: !isExpanded, vertical: !isExpanded)
            .padding(.vertical, 4)
            .padding(.horizontal, 6)
            .modifier(GlassBackgroundStyle(cornerRadius: 10))
            .shadow(color: .black.opacity(0.15), radius: 5, x: 0, y: 2)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(.separator)
            )
            .cornerRadius(10)
        }
        .opacity(opacityValue)
        .onAppear {
            withAnimation(.spring(response: 0.3, blendDuration: 0.1)) {
                isExpanded = true
            }
            
            // This will run approximately when the animation finishes
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.10) {
                showEditor = true
            }
        }
    }
    
    @State private var opacityValue: Double = 1.0
    
    // MARK: - Private Methods
    private func closeWithAnimation() {
        withAnimation(.spring(response: 0.2, dampingFraction: 0.8)) {
            isExpanded = false
            opacityValue = 0.0
        }
        
        // Dismiss after animation completes
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.11) {
            showEditor = false
            showQueryEditor = false
            opacityValue = 1.0
        }
    }
    
    @State private var displayedIcon: String = "play.fill"
    
    private func fullQueryEditorView() -> some View {
        VStack(spacing: 0) {
            // Query Editor Header
            HStack {
                Text("Query Editor")
                    .font(.headline)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Text("\(totalCount) rows \(queryExecutionTime)")
                    .foregroundColor(.secondary)
                    .font(.subheadline)
                
                Button(action: {}) {
                    Image(systemName: "clock")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                
                Text(lastQueryTime)
                    .foregroundColor(.secondary)
                    .font(.subheadline)
                
                Button(action: {
                    filter = ""
                    queryStartTime = Date()
                    onLoadDocuments(filter)
                }) {
                    Text("Clear")
                        .font(.system(size: 12))
                }
                .buttonStyle(OutlineSecondaryButtonStyle())
                .opacity(filter.isEmpty ? 0.5 : 1)
                .transition(.asymmetric(
                    insertion: .scale.combined(with: .opacity),
                    removal: .opacity
                ))
                .animation(.spring(response: 0.3), value: filter.isEmpty)
                
                Button(action: {
                    queryStartTime = Date()
                    onLoadDocuments(filter)
                }) {
                    Image(systemName: displayedIcon)
                        .foregroundColor(.secondary)
                        .contentTransition(.symbolEffect(.replace))
                        .frame(width: 10)
                    Text("Run")
                }
                .keyboardShortcut(.return, modifiers: .command)
                .buttonStyle(OutlineButtonStyle())
                .disabled(isLoading)
                .customHelp("Run current query", delay: 1.5, position: .left, shortcut: KeyboardShortcut(
                    modifiers: [.command],
                    key: "Enter"
                ), spacing: 8)
            }
            .padding([.top, .horizontal, .bottom], 8)
            .onChange(of: isLoading) { oldValue, newValue in
                // Calculate execution time when query completes
                if oldValue && !newValue, let startTime = queryStartTime {
                    let completionTime = Date()
                    lastExecutionTime = completionTime.timeIntervalSince(startTime)
                    lastQueryCompletionTime = completionTime
                    displayedQueryExecutionTime = String(format: "in %.2fs", lastExecutionTime)
                }
                
                if oldValue != newValue {
                    // When returning to idle from any non-idle state, delay the icon change
                    // Keep showing the stop icon for a bit longer
                    withAnimation {
                        displayedIcon = "stop.fill"
                    }
                    
                    // Then change back to play icon after delay
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.50) { // Adjust delay time as needed
                        withAnimation(.easeInOut(duration: 0.3)) {
                            displayedIcon = "play.fill"
                        }
                    }
                } else {
                    // Immediately show stop icon when starting a query
                    withAnimation {
                        displayedIcon = "stop.fill"
                    }
                }
            }
            
            CodeEditor(text: $filter, position: $position, messages: $messages, language: .mongodb())
                .environment(\.codeEditorTheme, Theme.defaultDark)
                .environment(\.codeEditorLayoutConfiguration, .init(wrapText: true))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(.separator)
                )
                .padding(.bottom, 2)
                .frame(height: 220)
                .cornerRadius(10)
        }
    }
}
