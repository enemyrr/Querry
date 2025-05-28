//
//  FloatingActionBar.swift
//  Collection
//
//  Created by Fauzaan on 2/26/25.
//

import SwiftUI
import MongoKitten

struct FloatingActionBar: View {
    let screenWidth: CGFloat
    var viewModel: DocumentListModel
    @Bindable var searchQueryViewModel: SearchQueryViewModel
    @Environment(\.colorScheme) private var colorScheme
    @State private var containerWidth: CGFloat = 0
    
    init(viewModel: DocumentListModel, searchQueryViewModel: SearchQueryViewModel,  screenWidth: CGFloat) {
        self.viewModel = viewModel
        self.searchQueryViewModel = searchQueryViewModel
        self.screenWidth = screenWidth
    }
    
    var body: some View {
        Button("") {
            searchQueryViewModel.showQueryEditor = true
        }
        .keyboardShortcut("f", modifiers: [.command])
        .padding(0)
        .opacity(0)
        .frame(width: 0, height: 0)
        
        VStack(spacing: 0) {
            if !searchQueryViewModel.showQueryEditor && !searchQueryViewModel.showCreateDocumentSheet {
                topRectangleView
                    .padding(.horizontal, 10)
                    .frame(width: containerWidth)
                    .animation(.smooth, value: searchQueryViewModel.showQueryEditor || searchQueryViewModel.showCreateDocumentSheet)
            }

            if !searchQueryViewModel.showCreateDocumentSheet && searchQueryViewModel.showQueryEditor {
                QueryEditor(viewModel: searchQueryViewModel, showQueryEditor: $searchQueryViewModel.showQueryEditor)
                    .frame(width: screenWidth * 0.9)
            }
            
            if searchQueryViewModel.showCreateDocumentSheet {
                CreateEditor(documentListModel: viewModel, showCreateDocumentSheet: $searchQueryViewModel.showCreateDocumentSheet)
                        .frame(width: screenWidth * (0.9))
            }
            
            HStack {
                switch viewModel.action {
                case .main:
                    mainView
                case .search:
                    AISearchView(viewModel: searchQueryViewModel, DocumentListModel: viewModel)
                        .frame(width: screenWidth * 0.55)
                default:
                    mainView
                }
                
            }
            .modifier(GlassBackgroundStyle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(.separator, lineWidth: 1)
            )
            .cornerRadius(8)
            .background(
                Group {
                    if viewModel.isLoadingAnimation {
                        GlowingBubbleLoader()
                    }
                    
                    if viewModel.error != nil {
                        LoadingErrorIndicator()
                    }
                }
            )
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: viewModel.actionBarUpdateTrigger)
            .background(
                GeometryReader { geometry in
                    Color.clear
                        .onAppear {
                            containerWidth = geometry.size.width
                        }
                        .onChange(of: geometry.size.width) { oldWidth, newWidth in
                            containerWidth = newWidth
                        }
                }
            )
        }
    }
    
    @State private var isHoveringTopRectangle: Bool = false
    
    private var topRectangleView: some View {
        VStack {
            HStack {
                Text("Query Editor")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.gray)

                Spacer()
                
                if searchQueryViewModel.query != searchQueryViewModel.defaultQuery {
                    Button(action: {
                        searchQueryViewModel.clearQuery()
                    }) {
                        Text("Clear")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    .buttonStyle(ActionButtonStyle(padding: EdgeInsets(top: 2, leading: 6, bottom: 2, trailing: 6)))
                    .padding([.vertical, .trailing], -4)
                }
            }
        }
        .padding(.top, 6)
        .padding(.horizontal, 8)
        .frame(maxWidth: .infinity)
        .padding(.bottom, isHoveringTopRectangle ? 8 : 5)
        .modifier(GlassBackgroundStyleRoundedTop())
        .overlay(
            RoundedCorners(tl: 8, tr: 8, bl: 0, br: 0)
                .stroke(.separator, lineWidth: 0.5)
        )
        .shadow(color: isHoveringTopRectangle ? Color.black.opacity(0.2) : Color.clear, radius: 3, x: 0, y: 1)
        .contentShape(Rectangle()) // Ensure the entire area is interactive
        .onHover { hovering in
            isHoveringTopRectangle = hovering
        }
        .animation(.spring(response: 0.2), value: isHoveringTopRectangle)
        .onTapGesture {
            searchQueryViewModel.openQueryEditor()
        }
    }
    
    private var mainView: some View {
        HStack(spacing: 5) {
            Pagination(viewModel: viewModel, filter: searchQueryViewModel.getFilter())
            
            Divider()
                .frame(height: 22)
                .padding(.vertical, 6)
            
            
            Button(action: searchQueryViewModel.executeQuery) {
                let iconName = viewModel.isLoadingAnimation ? "xmark" : "arrow.clockwise"
                Image(systemName: iconName)
                    .font(.system(size: 14))
                    .contentTransition(.symbolEffect(.replace.magic(fallback: .downUp.byLayer), options: .nonRepeating))
                    .frame(width: 16, height: 16)
                    .contentShape(Rectangle()) // Keep this for hit testing
            }
            .buttonStyle(ActionButtonStyle(padding: EdgeInsets(top: 7, leading: 8, bottom: 7, trailing: 8), isActive: viewModel.isLoading))
            .keyboardShortcut("r", modifiers: .command)
            .disabled(viewModel.isLoading)
            .customHelp("Refresh", position: .top, shortcut: KeyboardShortcut(
                modifiers: [.command],
                key: "R"
            ), spacing: 10)
            
            Group {
                // Batch delete button - only show when there are documents marked for deletion
                if viewModel.pendingActionsCount(for: .delete) > 0 {
                    Divider()
                        .frame(height: 22)
                        .padding(.vertical, 6)
                    
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
                }
                
                // Batch update button - only show when there are documents marked for update
                if viewModel.pendingActionsCount(for: .update) > 1 {
                    Divider()
                        .frame(height: 22)
                        .padding(.vertical, 6)
                    
                    UpdateActionButton(
                        updateCount: viewModel.pendingActionsCount(for: .update),
                        isProcessingBatch: viewModel.isProcessingBatch,
                        onUpdate: {
                            Task {
                                await viewModel.commitPendingActions()
                            }
                        }
                    )
                }
            }
            
            Divider()
                .frame(height: 22)
                .padding(.vertical, 6)
            
            Button(action: {
                withAnimation(.spring(response: 0.3)) {
                    searchQueryViewModel.showCreateDocumentSheet = true
                }
            }) {
                Image(systemName: "plus.circle")
                    .font(.system(size: 14))
                    .contentShape(Rectangle())
            }
            .buttonStyle(ActionButtonStyle(padding: EdgeInsets(top: 7, leading: 8, bottom: 7, trailing: 8), isActive: searchQueryViewModel.showCreateDocumentSheet))
            .keyboardShortcut("n", modifiers: .command)
            .customHelp("Create documents", position: .top, shortcut: KeyboardShortcut(
                modifiers: [.command],
                key: "N"
            ), spacing: 10)
            
            
            Divider()
                .frame(height: 22)
                .padding(.vertical, 6)
            
            
            Button(action: {
                withAnimation(.spring(response: 0.3)) {
                    viewModel.action = ActionBar.search
                }
            }) {
                Image(systemName: "sparkles")
                    .font(.system(size: 14))
                    .contentShape(Rectangle())
            }
            .buttonStyle(ActionButtonStyle(padding: EdgeInsets(top: 7, leading: 8, bottom: 7, trailing: 8)))
            .keyboardShortcut("p", modifiers: .command)
            .customHelp("AI Search", position: .top, shortcut: KeyboardShortcut(
                modifiers: [.command],
                key: "p"
            ), spacing: 10)
            
            // TODO: More options button
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
    
    private var FilterIcon: some View {
        HStack(spacing: 4) {
            Button(action: {
                viewModel.showFilterEditor = true
                searchQueryViewModel.showQueryEditor = true
            }) {
                BadgedFilterIcon()
            }
            .buttonStyle(ActionButtonStyle(padding: EdgeInsets(top: 7, leading: 8, bottom: 7, trailing: 8)))
            .keyboardShortcut("p", modifiers: .command)
            .customHelp("AI Search", position: .top, shortcut: KeyboardShortcut(
                modifiers: [.command],
                key: "p"
            ), spacing: 10)
            
            // TODO: More options button
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
        .padding(.vertical, 6)
        .modifier(GlassBackgroundStyle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(.separator, lineWidth: 1)
        )
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: viewModel.actionBarUpdateTrigger)
    }
    
}

struct BadgedFilterIcon: View {
    var isFiltered = true
    
    var body: some View {
        ZStack(alignment: .topTrailing) {
            Image(systemName: "line.3.horizontal.decrease")
                .font(.system(size: 14))
                .foregroundColor(.gray)
            
            if isFiltered {
                Circle()
                    .fill(Color.orange)
                    .frame(width: 8, height: 8)
                    .offset(x: 5, y: -5)
            }
        }
    }
}

enum ActionBar: String, CaseIterable, Codable {
    case main = "main"
    case search = "search"
    case create = "create"
}

// MARK: - Action Buttons
struct DeleteActionButton: View {
    let deleteCount: Int
    let isProcessingBatch: Bool
    let onDelete: () -> Void
    
    var body: some View {
        Button(action: onDelete) {
            HStack(spacing: 4) {
                if !isProcessingBatch {
                    Image(systemName: "trash")
                        .font(.system(size: 12))
                }
                
                Text(isProcessingBatch ? "Deleting" : "\(deleteCount)")
                    .font(.system(size: 12, weight: .light))
                    .lineLimit(1)
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
        .shadow(color: .black.opacity(0.5), radius: 2, x: 0, y: 1)
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
                    Image(systemName: "icloud.and.arrow.up.fill")
                        .font(.system(size: 12))
                    
                    Text("\(updateCount)")
                        .font(.system(size: 12, weight: .medium))
                }
            }
            .foregroundColor(.white)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color.orange.opacity(isProcessingBatch ? 0.8 : 1))
            .cornerRadius(6)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(isProcessingBatch)
        .shadow(color: .black.opacity(0.5), radius: 2, x: 0, y: 1)
        .transition(.scale.combined(with: .opacity))
        .keyboardShortcut("s", modifiers: .command)
        .customHelp("Save Changes", position: .top, shortcut: KeyboardShortcut(
            modifiers: [.command],
            key: "S"
        ), spacing: 10)
    }
}
