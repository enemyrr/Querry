//
//  SchemaModeActionBar.swift
//  Pluk
//
//  Created by Fauzaan on 10/20/25.
//

import SwiftUI

struct SchemaModeActionBar: View {
    @Binding var tabViewMode: DatabaseTab.ViewMode
    let columnCount: Int
    let isLoading: Bool
    let debouncedIsLoading: Bool
    let onRefresh: (_ currentPage: Int, _ itemsPerPage: Int, _ fetchSchema: Bool) -> Void
    let onDebounceLoadingChange: (Bool) -> Void

    @State private var debounceTask: Task<Void, Never>?
    @State private var loadingTask: Task<Void, Never>?

    var body: some View {
        HStack(spacing: 5) {
            columnsCountLabel()
            
            Divider()
                .frame(height: 22)
                .padding(.vertical, 6)
            Button(action: {
                if !isLoading {
                    // Cancel any existing loading operations before starting new one
                    loadingTask?.cancel()
                    debounceTask?.cancel()

                    onRefresh(1, 300, true)
                }
            }) {
                let iconName = debouncedIsLoading ? "xmark" : "arrow.clockwise"

                Image(systemName: iconName)
                    .font(.system(size: 14))
                    .contentTransition(.symbolEffect(.replace.magic(fallback: .downUp.byLayer), options: .nonRepeating))
                    .frame(width: 16, height: 16)
                    .contentShape(Rectangle())
                    .onChange(of: isLoading) { oldValue, newValue in
                        // Cancel previous debounce task
                        debounceTask?.cancel()

                        if newValue {
                            // Show loading immediately
                            onDebounceLoadingChange(true)
                        } else {
                            // Debounce the loading -> stopped transition
                            debounceTask = Task { @MainActor in
                                do {
                                    try await Task.sleep(for: .milliseconds(400))
                                    // Double-check we haven't been cancelled and loading hasn't restarted
                                    if !Task.isCancelled && !isLoading {
                                        onDebounceLoadingChange(false)
                                    }
                                } catch {
                                    // Task was cancelled, ignore
                                }
                            }
                        }
                    }
            }
            .buttonStyle(ActionButtonStyle(padding: EdgeInsets(top: 7, leading: 8, bottom: 7, trailing: 8), isActive: debouncedIsLoading))
            .disabled(isLoading)
            .customHelp("Refresh", position: .top, shortcut: KeyboardShortcut(
                modifiers: [.command],
                key: "R"
            ), spacing: 10)
            
            Button(action: {
                
            }) {
                Image(systemName: "plus.circle")
                    .font(.system(size: 14))
                    .contentShape(Rectangle())
                    .foregroundStyle(.secondary)
            }
            .disabled(true)
            .buttonStyle(ActionButtonStyle(padding: EdgeInsets(top: 7, leading: 8, bottom: 7, trailing: 8), isActive: false))
            .foregroundStyle(.secondary)
            
            ViewModeToggle(tabViewMode: $tabViewMode)
                .padding(.leading, 2)
                .padding(.vertical, -2)
        }
        .padding(8)
    }
    
    @ViewBuilder
    private func columnsCountLabel() -> some View {
        HStack(spacing: 0) {
            Button(action: {
                // Open Modal
            }) {
                Text("\(columnCount) Columns")
                    .foregroundColor(.gray)
            }
            .buttonStyle(ActionButtonStyle(padding: EdgeInsets(top: 7, leading: 8, bottom: 7, trailing: 8), disableScaleEffect: true))
        }
    }
}
