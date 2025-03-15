//
//  SearchInput.swift
//  Collection
//
//  Created by Fauzaan on 3/14/25.
//

import SwiftUI
import AIProxy



struct AISearchView: View {
    @State private var search: String = ""
    @State private var shimmerAction = IntelligenceUIPlatterView.ShimmerAction()
    @FocusState private var isSearchFocused: Bool
    @ObservedObject var viewModel: DocumentViewModel
    
    var body: some View {
        VStack(spacing: 10) {
            HStack(spacing: 8) {
                // Back button
                Button(action: {
                    withAnimation(.spring(response: 0.3)) {
                        viewModel.action = ActionBar.main
//                        viewModel.aiResponse = ""
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
                        .textFieldStyle(.plain)
                        .font(.system(size: 15))
                        .frame(width: 450)
                        .onSubmit {
                            Task {
                                await viewModel.submitAIRequest(search: search)
                                shimmerAction()
                            }
                        }
                        .onAppear {
                            // Set focus after a slight delay to ensure view hierarchy is ready
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                isSearchFocused = true
                            }
                        }
                    
                    ProgressView().controlSize(.small).opacity(viewModel.isAILoading ? 1 : 0)
                }
                .padding(.vertical, 8)
            }
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 4)
        .background(
            IntelligenceUIPlatterView()
                .cornerRadius(8)
                .hasExteriorLight(false)
                .shimmerOn(shimmerAction)
        ).transition(.opacity.animation(.easeInOut(duration: 0.2)))
    }

}

