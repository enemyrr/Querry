//
//  FloatingActionBar.swift
//  Collection
//
//  Created by Fauzaan on 2/26/25.
//

import SwiftUI

struct FloatingActionBar: View {
    let screenWidth: CGFloat
    var viewModel: DocumentListModel
    @Environment(\.colorScheme) private var colorScheme
    @State private var searchQueryViewModel: SearchQueryViewModel
    
    init(viewModel: DocumentListModel, screenWidth: CGFloat) {
        self.viewModel = viewModel
        self.searchQueryViewModel = SearchQueryViewModel(DocumentListModel: viewModel)
        self.screenWidth = screenWidth
    }

    var body: some View {
        VStack {
            if viewModel.action == .search {
                QueryEditor(viewModel: searchQueryViewModel, DocumentListModel: viewModel)
                    .padding(.bottom, searchQueryViewModel.isFullQueryEditorOpen ? -12 : -2)
                    .frame(width: screenWidth * (searchQueryViewModel.isFullQueryEditorOpen ? 0.9 : 0.6))
            }
            
            HStack {
                switch viewModel.action {
                case .main:
                    mainView
                case .search:
                    AISearchView(viewModel: searchQueryViewModel, DocumentListModel: viewModel)
                        .frame(width: screenWidth * 0.6)
                }
            }
            .modifier(GlassBackgroundStyle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(.separator, lineWidth: 1)
            )
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: viewModel.actionBarUpdateTrigger)
        }
    }
    
    
    @State private var isLoading = false

    private var mainView: some View {
        HStack(spacing: 5) {
            Pagination(viewModel: viewModel)
            
            Divider()
                .frame(height: 22)
                .padding(.vertical, 6)
            

            Button(action: {
                isLoading = true // Start loading state
                Task {
                    await viewModel.loadDocuments()
                    isLoading = false // End loading state
                }
            }) {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 14))
                    .contentShape(Rectangle())
                    .symbolEffect(
                        .rotate,
                        value: isLoading
                    )
            }
            .buttonStyle(ActionButtonStyle(padding: EdgeInsets(top: 7, leading: 8, bottom: 7, trailing: 8)))
            .keyboardShortcut("r", modifiers: .command)
            .customHelp("Refresh", position: .top, shortcut: KeyboardShortcut(
                modifiers: [.command],
                key: "R"
            ), spacing: 10)
            
            Divider()
                .frame(height: 22)
                .padding(.vertical, 6)
            

            Button(action: {
                withAnimation(.spring(response: 0.3)) {
                    viewModel.action = ActionBar.search
                }
            }) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 14))
                    .contentShape(Rectangle())
            }
            .buttonStyle(ActionButtonStyle(padding: EdgeInsets(top: 7, leading: 8, bottom: 7, trailing: 8)))
            .keyboardShortcut("f", modifiers: .command)
            .customHelp("Filter documents", position: .top, shortcut: KeyboardShortcut(
                modifiers: [.command],
                key: "F"
            ), spacing: 10)
            
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
                if viewModel.pendingActionsCount(for: .update) > 1 {
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
//            Button(action: {
//                // TODO:
//                // Add an action
//            }) {
//                Image(systemName: "ellipsis")
//                    .font(.system(size: 14))
//                    .contentShape(Rectangle())
//            }
//            .buttonStyle(ActionButtonStyle(padding: EdgeInsets(top: 12, leading: 8, bottom: 12, trailing: 8)))
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 4)
    }
}

enum ActionBar: String, CaseIterable, Codable {
    case main = "main"
    case search = "search"
}

// MARK: - Action Buttons
struct DeleteActionButton: View {
    let deleteCount: Int
    let isProcessingBatch: Bool
    let onDelete: () -> Void
    
    var body: some View {
        Button(action: onDelete) {
            HStack(spacing: 4) {
                if isProcessingBatch {
                    // Display a loading indicator when processing
                    ProgressView()
                        .scaleEffect(0.7)
                        .frame(width: 16, height: 16)
                        .tint(.white)
                } else {
                    // Display trash icon when not processing
                    Image(systemName: "trash")
                        .font(.system(size: 12))
                }
                
                Text(isProcessingBatch ? "Deleting..." : "\(deleteCount)")
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
        .keyboardShortcut("s", modifiers: .command)
        .customHelp("Delete Documents", position: .top, shortcut: KeyboardShortcut(
            modifiers: [.command],
            key: "S"
        ), spacing: 10)
    }
}

struct UpdateActionButton: View {
    let updateCount: Int
    let isProcessingBatch: Bool
    let onUpdate: () -> Void
    
    var body: some View {
        Button(action: onUpdate) {
            HStack(alignment: .bottom, spacing: 4) {
                if isProcessingBatch {
                    // Display a loading indicator when processing
                    ProgressView()
                        .controlSize(.mini)
                        .frame(width: 16, height: 16)
                        .tint(.white)
                } else {
                    // Display save icon when not processing
                    Image(systemName: "square.and.arrow.down")
                        .font(.system(size: 12))
                    
                    Text("\(updateCount)")
                        .font(.system(size: 12, weight: .medium))
                }
            }
            .foregroundColor(.white)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color.blue.opacity(isProcessingBatch ? 0.8 : 1))
            .cornerRadius(6)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(isProcessingBatch)
        .transition(.scale.combined(with: .opacity))
        .keyboardShortcut("s", modifiers: .command)
        .customHelp("Save Changes", position: .top, shortcut: KeyboardShortcut(
            modifiers: [.command],
            key: "S"
        ), spacing: 10)
    }
}
