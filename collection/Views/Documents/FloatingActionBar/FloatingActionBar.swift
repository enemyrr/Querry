//
//  FloatingActionBar.swift
//  Collection
//
//  Created by Fauzaan on 2/26/25.
//

import SwiftUI

struct FloatingActionBar: View {
    let screenWidth: CGFloat
    @ObservedObject var viewModel: DocumentViewModel
    @Environment(\.colorScheme) private var colorScheme
    @StateObject private var searchQueryViewModel: SearchQueryViewModel
    
    init(viewModel: DocumentViewModel, screenWidth: CGFloat) {
        self._viewModel = ObservedObject(wrappedValue: viewModel)
        self._searchQueryViewModel = StateObject(wrappedValue: SearchQueryViewModel(documentViewModel: viewModel))
        self.screenWidth = screenWidth
    }

    var body: some View {
        VStack {
            if viewModel.action == .search {
                QueryEditor(viewModel: searchQueryViewModel, documentViewModel: viewModel)
                    .padding(.bottom, searchQueryViewModel.isFullQueryEditorOpen ? -12 : -2)
                    .frame(width: screenWidth * (searchQueryViewModel.isFullQueryEditorOpen ? 0.9 : 0.6))
            }
            
            HStack {
                switch viewModel.action {
                case .main:
                    mainView
                case .search:
                    AISearchView(viewModel: searchQueryViewModel, documentViewModel: viewModel)
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
    
    
    private var mainView: some View {
        HStack(spacing: 5) {
            Pagination(viewModel: viewModel)
            
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
                key: "f"
            ), spacing: 10)
            
            Divider()
                .frame(height: 22)
                .padding(.vertical, 6)
            
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

