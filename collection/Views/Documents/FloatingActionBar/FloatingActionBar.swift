//
//  FloatingActionBar.swift
//  Collection
//
//  Created by Fauzaan on 2/26/25.
//

import SwiftUI

struct FloatingActionBar: View {
    @ObservedObject var viewModel: DocumentViewModel
    @State private var action: ActionBar = ActionBar.main
    @State private var search: String = ""
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
            
            // Next button
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
        HStack(spacing: 8) {
            // Back button
            Button(action: {
                withAnimation(.spring(response: 0.3)) {
                    action = ActionBar.main
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
                    .onChange(of: isSearchFocused) { oldValue, newValue in
                        if newValue {
                            shimmerAction()
                        }
                    }
                    .textFieldStyle(.plain)
                    .font(.system(size: 15))
                    .frame(width: 450)
                    .onAppear {
                        // Set focus after a slight delay to ensure view hierarchy is ready
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            isSearchFocused = true
                        }
                    }
            }
            .padding(.vertical, 8)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 4)
        .background(
            IntelligenceUIPlatterView()
                .cornerRadius(8)
                .hasInteriorLight(true)
                .hasExteriorLight(true)
        ).transition(.opacity.animation(.easeInOut(duration: 0.2)))
    }
    
    private var loadingView: some View {
        HStack(spacing: 10) {
            Image(systemName: "arrow.2.circlepath")
                .foregroundStyle(.green)
//                .font(.caption)
                .symbolEffect(.rotate.clockwise.byLayer, options: .repeat(.periodic(delay: 1)))
            
//            ProgressView()
//                .controlSize(.small)
            Text("Fetching Documents ...")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }
}

enum ActionBar: String, CaseIterable, Codable {
    case main = "main"
    case search = "search"
}

