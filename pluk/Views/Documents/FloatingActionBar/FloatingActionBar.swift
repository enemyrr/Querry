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
    var viewState: TableListViewState
    let tableName: String
    let onRefresh: (_ currentPage: Int, _ itemsPerPage: Int, _ fetchSchema: Bool) -> Void
    let onLoadDocuments: (_ filter: String?) -> Void
    
    @Environment(ConnectionInstance.self) private var instance
    
    @State private var containerWidth: CGFloat = 0
    @State var showQueryEditor: Bool = false
    @State var showCreateDocumentSheet: Bool = false
    @State var filter: String = ""
    
    @State var action: ActionBar = ActionBar.main
    @State var showFilterEditor: Bool = false
    
    @State private var loadingTask: Task<Void, Never>?
    @State private var errorTask: Task<Void, Never>?
    
    // MARK: - Animation States
    @State private var showQueryUpdateAnimation = false
    @State private var previousFilter: String = ""
    @State private var isSubmitAnimating: Bool = false

    // MARK: - Pagination
    @State var currentPage = 1
    @State var totalPages = 1
    @State var totalPerPage = 300
    private var totalCount: Int {
        if case .loaded(let queryResult, _) = viewState {
            return queryResult.totalCount
        }
        return 0
    }
    
    
    private var isLoading: Bool {
        if case .loading = viewState {
            return true
        }
        return false
    }
    
    
    @State private var debouncedIsLoading: Bool = false
    @State private var debounceTask: Task<Void, Never>?
    
    var body: some View {
        Button("") {
            showQueryEditor = true
        }
        .keyboardShortcut("f", modifiers: [.command])
        .padding(0)
        .opacity(0)
        .frame(width: 0, height: 0)
        
        VStack(spacing: 0) {
            if !showQueryEditor && !showCreateDocumentSheet {
                topRectangleView
                    .padding(.horizontal, action == .main ? 10 : 16)
                    .frame(width: containerWidth)
                    .animation(.smooth, value: showQueryEditor || showCreateDocumentSheet)
                    .scaleEffect(isSubmitAnimating ? 1.02 : 1.0)
                    .animation(.easeInOut(duration: 0.10), value: isSubmitAnimating)

            }
            
            if !showCreateDocumentSheet && showQueryEditor {
                QueryEditor(showQueryEditor: $showQueryEditor, filter: $filter, isLoading: isLoading,totalCount: totalCount, onLoadDocuments: onLoadDocuments)
                    .frame(width: screenWidth * 0.9)
            }
            
            if showCreateDocumentSheet {
                //                CreateEditor(documentListModel: viewModel, showCreateDocumentSheet: $searchQueryViewModel.showCreateDocumentSheet)
                //                        .frame(width: screenWidth * (0.9))
            }
            
            HStack {
                switch action {
                case .main:
                    mainView
                case .search:
                    AISearchView(
                        filter: $filter,
                        showQueryEditor: showQueryEditor,
                        tableName: tableName,
                        isSubmitAnimating: $isSubmitAnimating,
                        onBack: {
                            withAnimation(.spring(response: 0.3)) {
                                action = .main
                            }
                        },
                        onLoadDocuments: onLoadDocuments)
                    .frame(width: screenWidth * 0.55)
                default:
                    mainView
                }
                
            }
            .modifier(GlassBackgroundStyle(cornerRadius: action == .main ? 12 : 20))
            .overlay(
                RoundedRectangle(cornerRadius: action == .main ? 12 : 20)
                    .stroke(.separator, lineWidth: 1)
            )
            .background(
                Group {
                    if action == .main {
                        GlowingBubbleLoader(
                            isLoading: isLoading
                        )
                    }
                    
                    if case .error( _) = viewState {
                        LoadingErrorIndicator()
                    }
                }
            )
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: action)
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
                if action == .search {
                    Button(action: {
                        withAnimation(.spring(response: 0.3)) {
                            action = .main
                        }
                    }) {
                        Image(systemName: "arrow.backward")
                            .foregroundColor(.secondary)
                    }
                    .keyboardShortcut(.escape, modifiers: [])
                    .customHelp("Go back", position: .top, shortcut: KeyboardShortcut(
                        modifiers: [],
                        key: "Escape"
                    ), spacing: 6)
                    .buttonStyle(AIBackButtonStyle())
                    .padding(-8)
                    .padding(.trailing, 6)
                }
                
                Text("Query Editor")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.gray)
                
                Spacer()
                
                if !filter.isEmpty {
                    Button(action: {
                        filter = ""
                        onLoadDocuments(filter)
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
        .modifier(
            GlassBackgroundStyleRoundedTop()
        )
        .overlay(
            RoundedCorners(tl: 10, tr: 10, bl: 0, br: 0)
                .stroke(.separator, lineWidth: 1)
        )
        .shadow(color: isHoveringTopRectangle ? Color.black.opacity(0.2) : Color.clear, radius: 3, x: 0, y: 1)
        .contentShape(Rectangle()) // Ensure the entire area is interactive
        .onHover { hovering in
            isHoveringTopRectangle = hovering
        }
        .animation(.spring(response: 0.2), value: isHoveringTopRectangle)
        .onTapGesture {
            openQueryEditor()
        }
    }
    
    private var mainView: some View {
        HStack(spacing: 5) {
            Pagination(
                currentPage: $currentPage,
                totalPages: totalPages,
                totalCount: totalCount,
                totalPerPage: totalPerPage,
                onRefresh: { onRefresh(currentPage, totalPerPage, false) }
            )
            
            Divider()
                .frame(height: 22)
                .padding(.vertical, 6)
            
            Button(action: {
                if !isLoading {
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
                        // Cancel previous debounce
                        debounceTask?.cancel()
                        
                        if newValue {
                            // Show loading immediately
                            debouncedIsLoading = true
                        } else {
                            // Debounce the loading -> stopped transition
                            debounceTask = Task {
                                try? await Task.sleep(for: .milliseconds(400))
                                if !Task.isCancelled {
                                    await MainActor.run {
                                        debouncedIsLoading = false
                                    }
                                }
                            }
                        }
                    }
            }
            .buttonStyle(ActionButtonStyle(padding: EdgeInsets(top: 7, leading: 8, bottom: 7, trailing: 8), isActive: debouncedIsLoading))
            .keyboardShortcut("r", modifiers: .command)
            .disabled(isLoading)
            .customHelp("Refresh", position: .top, shortcut: KeyboardShortcut(
                modifiers: [.command],
                key: "R"
            ), spacing: 10)
            
            Group {
                // Batch delete button - only show when there are documents marked for deletion
                //                if viewModel.pendingActionsCount(for: .delete) > 0 {
                //                Divider()
                //                    .frame(height: 22)
                //                    .padding(.vertical, 6)
                
                //                    DeleteActionButton(
                //                        deleteCount: viewModel.pendingActionsCount(for: .delete),
                //                        isProcessingBatch: viewModel.isProcessingBatch,
                //                        onDelete: {
                //                            Task {
                //                                await viewModel.commitPendingActions()
                //                            }
                //                        }
                //                    )
                //                    .padding(.horizontal, 2)
            }
            
            // Batch update button - only show when there are documents marked for update
            //                if viewModel.pendingActionsCount(for: .update) > 1 {
            //                    Divider()
            //                        .frame(height: 22)
            //                        .padding(.vertical, 6)
            //
            //                    UpdateActionButton(
            //                        updateCount: viewModel.pendingActionsCount(for: .update),
            //                        isProcessingBatch: viewModel.isProcessingBatch,
            //                        onUpdate: {
            //                            Task {
            //                                await viewModel.commitPendingActions()
            //                            }
            //                        }
            //                    )
            //                }
            //            }
            
            Divider()
                .frame(height: 22)
                .padding(.vertical, 6)
            
            Button(action: {
                withAnimation(.spring(response: 0.3)) {
                    //                    searchQueryViewModel.showCreateDocumentSheet = true
                }
            }) {
                Image(systemName: "plus.circle")
                    .font(.system(size: 14))
                    .contentShape(Rectangle())
            }
            .buttonStyle(ActionButtonStyle(padding: EdgeInsets(top: 7, leading: 8, bottom: 7, trailing: 8), isActive: false))
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
                    action = ActionBar.search
                }
            }) {
                Image(systemName: "sparkles")
                    .font(.system(size: 14))
                    .contentShape(Rectangle())
            }
            .buttonStyle(ActionButtonStyle(padding: EdgeInsets(top: 7, leading: 8, bottom: 7, trailing: 8)))
            .keyboardShortcut("l", modifiers: .command)
            .customHelp("AI Search", position: .top, shortcut: KeyboardShortcut(
                modifiers: [.command],
                key: "L"
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
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }
    
    private var FilterIcon: some View {
        HStack(spacing: 4) {
            Button(action: {
                showFilterEditor = true
                //                searchQueryViewModel.showQueryEditor = true
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
        //        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: viewModel.actionBarUpdateTrigger)
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
    
    /// Open the full query editor view with animation
    func openQueryEditor() {
        Task { @MainActor in
            // Only perform animation if the editor is currently open
            if !showQueryEditor {
                withAnimation(.spring(response: 0.15)) {
                    showQueryEditor = true
                }
            }
        }
    }
}

enum ActionBar: String, CaseIterable, Codable {
    case main = "main"
    case search = "search"
    case create = "create"
}
