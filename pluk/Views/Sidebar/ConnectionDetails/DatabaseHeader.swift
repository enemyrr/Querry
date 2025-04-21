//
//  DatabaseHeader.swift
//  Collection
//
//  Created by Fauzaan on 3/23/25.
//

import SwiftUI
import SwiftUI
import MongoKitten

// MARK: - Database List
struct DatabaseHeader: View {
    @Environment(\.colorScheme) var colorScheme
    @State private var isHovering = false
    var viewModel: SidebarViewModel
    var database: MongoDatabase?

    var body: some View {
        VStack {
            SearchInput(viewModel: viewModel)
            
            HStack {
                HStack(spacing: 2) {
                    HStack(spacing: 4) {
                        Text(database?.name ?? "No Database")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                        
                        if (isHovering) {
                            Image(systemName: "chevron.down")
                                .font(.footnote)
                                .opacity(0.7)
                        }
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(
                                (isHovering)
                                ? (colorScheme == .dark ? Color.black : Color.white)
                                    .opacity(
                                        isHovering ? 0.2 : 0.3
                                    )
                                : Color.clear
                            )
                    )
                    .onHover { hovering in
                        withAnimation(.easeOut(duration: 0.05)) {
                            isHovering = hovering
                        }
                    }
                    
                }
                
                Spacer()
                
                HStack(spacing: 0) {
                    CreateTable(
                        viewModel: viewModel
                    )
                }
            }

        }
    }
}


// MARK: - SearchInput
private struct SearchInput: View {
    var viewModel: SidebarViewModel
    @State private var localSearchText: String = ""
    @FocusState private var isSearchFocused: Bool
    
    var body: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.gray)
                .font(.system(size: 14))
            
            TextField("Search", text: Binding(
                get: { viewModel.searchText },
                set: { viewModel.searchText = $0 }
            ))
            .focused($isSearchFocused)
            .textFieldStyle(.plain)
            .font(.system(size: 14))
            .foregroundColor(.white)
            .onExitCommand {
                viewModel.searchText = ""
            }
            
            if !viewModel.searchText.isEmpty {
                Button(action: { viewModel.searchText = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.gray)
                        .font(.system(size: 12))
                }
                .buttonStyle(.plain)
                .onHover { hovering in
                    if hovering {
                        NSCursor.pointingHand.push()
                    } else {
                        NSCursor.pop()
                    }
                }
                .transition(.opacity)
                .padding(.horizontal, 2)
            } else {
                HStack(spacing: 4) {
                    Text("⌘K")
                        .font(.system(size: 10))
                        .padding(.vertical, 2)
                        .padding(.horizontal, 4)
                        .foregroundColor(.white.opacity(0.2))
                        .background(
                            RoundedRectangle(cornerRadius: 4)
                                .stroke(.white.opacity(0.2))
                        )
                }
                
            }
            
        }
        .padding(.leading, 8)
        .padding(.trailing, 6)
        .padding(.vertical, 6)
        .background {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.black.opacity(0.2))
        }
        .onTapGesture {
            isSearchFocused = true
        }
        .overlay(
            Button("") {
                isSearchFocused = true
            }
            .keyboardShortcut("k", modifiers: [.command])
            .opacity(0)
        )
        .animation(.easeInOut(duration: 0.2), value: viewModel.searchText)
    }
}
