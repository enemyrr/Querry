//
//  ContentModeActionBar.swift
//  Pluk
//
//  Created by Fauzaan on 10/20/25.
//

import SwiftUI
import MongoKitten

struct ContentModeActionBar: View {
    @Binding var currentPage: Int
    @Binding var tabViewMode: DatabaseTab.ViewMode
    let totalPages: Int
    let totalCount: Int
    let totalPerPage: Int
    let modificationTracker: TableModificationTracker
    let isProcessingUpdates: Bool
    let tableName: String
    let isLoading: Bool
    let debouncedIsLoading: Bool
    let onRefresh: (_ currentPage: Int, _ itemsPerPage: Int, _ fetchSchema: Bool) -> Void
    let onCommitModifications: () -> Void
    let onNewRecord: () -> Void
    let onOpenAISearch: () -> Void
    let onDebounceLoadingChange: (Bool) -> Void

    @State private var debounceTask: Task<Void, Never>?
    @State private var loadingTask: Task<Void, Never>?

    var body: some View {
        HStack(spacing: 5) {
            Pagination(
                currentPage: $currentPage,
                totalPages: totalPages,
                totalCount: totalCount,
                totalPerPage: totalPerPage,
                onRefresh: { onRefresh(currentPage, totalPerPage, false) },
                modificationTracker: modificationTracker,
                onCommitModifications: onCommitModifications
            )

            Divider()
                .frame(height: 22)
                .padding(.vertical, 6)

            Button(action: {
                if !isLoading {
                    // Cancel any existing loading operations before starting new one
                    loadingTask?.cancel()
                    debounceTask?.cancel()

                    onRefresh(currentPage, totalPerPage, true)
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
                onNewRecord()
            }) {
                Image(systemName: "plus.circle")
                    .font(.system(size: 14))
                    .contentShape(Rectangle())
            }
            .buttonStyle(ActionButtonStyle(padding: EdgeInsets(top: 7, leading: 8, bottom: 7, trailing: 8), isActive: false))
            .customHelp("Insert Row", position: .top, shortcut: KeyboardShortcut(
                modifiers: [.command],
                key: "I"
            ), spacing: 10)

            Group {
                if modificationTracker.hasPendingDeletions {
                    HStack(spacing: 6) {
                        Divider()
                            .frame(height: 22)
                            .padding(.vertical, 6)
                            .padding(.trailing, 4)
                            .transition(.opacity.combined(with: .move(edge: .top)))

                        DeleteActionButton(
                            deleteCount: modificationTracker.pendingDeletionCount,
                            isProcessingBatch: isProcessingUpdates,
                            onDelete: {
                                onCommitModifications()
                            }
                        )
                        Button(action: {
                            modificationTracker.resetAllModifications(of: .delete)
                            NotificationCenter.default.post(name: .tableReloadData, object: nil, userInfo: ["tableName": tableName])
                        }) {
                            Text("Discard")
                        }
                        .buttonStyle(ActionButtonStyle(padding: EdgeInsets(top: 7, leading: 8, bottom: 7, trailing: 8)))
                        .customHelp("Discard deletions", position: .top)
                    }

                }
            }

            // Batch update button - only show when there are documents marked for update
            if modificationTracker.hasModifications {
                HStack(spacing: 6) {
                    Divider()
                        .frame(height: 22)
                        .padding(.vertical, 6)
                        .padding(.trailing, 4)
                        .transition(.opacity.combined(with: .move(edge: .top)))

                    UpdateActionButton(
                        updateCount: modificationTracker.modifiedRowCount,
                        isProcessingBatch: isProcessingUpdates,
                        onUpdate: {
                            onCommitModifications()
                        }
                    )

                    Button(action: {
                        modificationTracker.resetAllModifications(of: .update, .insert)
                        NotificationCenter.default.post(name: .tableReloadData, object: nil, userInfo: ["tableName": tableName])
                    }) {
                        Text("Discard")
                    }
                    .buttonStyle(ActionButtonStyle(padding: EdgeInsets(top: 7, leading: 8, bottom: 7, trailing: 8)))
                    .customHelp("Discard Changes", position: .top)
                }
            }

            Button(action: {
                onOpenAISearch()
            }) {
                HStack(spacing: 4) {
                    Image(systemName: "sparkles")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(height: 15)
                        .contentShape(Rectangle())

                    Text("Ask AI")
                }
            }
            .buttonStyle(ActionButtonStyle(padding: EdgeInsets(top: 7, leading: 8, bottom: 7, trailing: 8)))
            .customHelp("Ask AI", position: .top, shortcut: KeyboardShortcut(
                modifiers: [.command],
                key: "L"
            ), spacing: 10)

            ViewModeToggle(tabViewMode: $tabViewMode)
                .padding(.leading, 2)
                .padding(.vertical, -2)
        }
        .padding(8)
    }
}
