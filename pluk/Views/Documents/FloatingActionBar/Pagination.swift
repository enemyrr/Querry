//
//  Pagination.swift
//  Collection
//
//  Created by Fauzaan on 3/6/25.
//

import SwiftUI
import MongoKitten

struct Pagination: View {
    var viewModel: DocumentListModel
    var filter: Document? = [:]
    
    var body: some View {
        HStack(spacing: 0) {
            Button(action: {
                withAnimation(.spring(response: 0.3)) {
                    viewModel.previousPage(filter: filter)
                }
            }) {
                Image(systemName: "chevron.left")
                    .foregroundColor(.white)
                    .opacity(viewModel.currentPage <= 1 ? 0.3 : 1)
                    .font(.system(size: 14))
                    .contentShape(Rectangle())
            }
            .disabled(viewModel.currentPage <= 1)
            .buttonStyle(ActionButtonStyle(padding: EdgeInsets(top: 7, leading: 9, bottom: 7, trailing: 9)))
            .keyboardShortcut(.leftArrow, modifiers: .command)
            .customHelp("Go to previous page", position: .top, shortcut: KeyboardShortcut(
                modifiers: [.command],
                key: "←"
            ))
            .transition(.scale.combined(with: .opacity))
            
            Button(action: {
                // Open Modal
            }) {
                Text("\(viewModel.totalItems) rows").foregroundColor(.gray)
            }
            .buttonStyle(ActionButtonStyle(padding: EdgeInsets(top: 7, leading: 8, bottom: 7, trailing: 8), disableScaleEffect: true))
            
            Button(action: {
                withAnimation(.spring(response: 0.3)) {
                    viewModel.nextPage(filter: filter)
                }
            }) {
                Image(systemName: "chevron.right")
                    .foregroundColor(.white)
                    .opacity(viewModel.currentPage >= viewModel.totalPages ? 0.3 : 1)
                    .font(.system(size: 14))
                    .contentShape(Rectangle())
            }
            .disabled(viewModel.currentPage >= viewModel.totalPages)
            .buttonStyle(ActionButtonStyle(padding: EdgeInsets(top: 7, leading: 9, bottom: 7, trailing: 9)))
            .keyboardShortcut(.rightArrow, modifiers: .command)
            .customHelp( "Go to next page", position: .top, shortcut: KeyboardShortcut(
                modifiers: [.command],
                key: "→"
            ))
            .transition(.scale.combined(with: .opacity))
        }
    }
}

struct PaginationMinimal: View {
    var viewModel: DocumentListModel
    
    var body: some View {
        HStack(spacing: 0) {
            Button(action: {
                withAnimation(.spring(response: 0.3)) {
                    viewModel.previousPage()
                }
            }) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 14))
                    .contentShape(Rectangle())
                    .foregroundColor(.white.opacity(viewModel.currentPage <= 1 ? 0.5 : 1))
            }
            .disabled(viewModel.currentPage <= 1)
            .buttonStyle(ActionButtonStyle(padding: EdgeInsets(top: 7, leading: 9, bottom: 7, trailing: 9)))
            .keyboardShortcut(.leftArrow, modifiers: .command)
            .customHelp("Go to previous page", position: .top, shortcut: KeyboardShortcut(
                modifiers: [.command],
                key: "←"
            ))
            .transition(.scale.combined(with: .opacity))
            
            Button(action: {
                withAnimation(.spring(response: 0.3)) {
                    viewModel.nextPage()
                }
            }) {
                Image(systemName: "chevron.right")
                    .font(.system(size: 14))
                    .contentShape(Rectangle())
                    .foregroundColor(.white.opacity(viewModel.currentPage >= viewModel.totalPages ? 0.5 : 1))
            }
            .disabled(viewModel.currentPage >= viewModel.totalPages)
            .buttonStyle(ActionButtonStyle(padding: EdgeInsets(top: 7, leading: 9, bottom: 7, trailing: 9)))
            .keyboardShortcut(.rightArrow, modifiers: .command)
            .customHelp("Go to next page", position: .top, shortcut: KeyboardShortcut(
                modifiers: [.command],
                key: "→"
            ))
            .transition(.scale.combined(with: .opacity))
        }
    }
}
