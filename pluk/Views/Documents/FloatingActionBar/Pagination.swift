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
    @State private var isHovering = false

    private let paginationManager: PaginationManager
    
    var body: some View {
        let isPreviousDisabled = viewModel.currentPage <= 1
        let isNextDisabled = viewModel.totalRows != viewModel.rowsPerPage
        
        HStack(spacing: 0) {
            Button(action: {
                withAnimation(.spring(response: 0.3)) {
                    viewModel.previousPage(filter: filter)
                }
            }) {
                Image(systemName: "chevron.left")
                    .foregroundColor(.white)
                    .opacity(isPreviousDisabled ? 0.3 : 1)
                    .font(.system(size: 14))
                    .contentShape(Rectangle())
            }
            .disabled(isPreviousDisabled)
            .buttonStyle(ActionButtonStyle(padding: EdgeInsets(top: 7, leading: 9, bottom: 7, trailing: 9)))
            .keyboardShortcut(.leftArrow, modifiers: .command)
            .customHelp("Go to previous page", position: .top, shortcut: KeyboardShortcut(
                modifiers: [.command],
                key: "←"
            ))
            .onHover { hovering in
                if !isPreviousDisabled {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isHovering = hovering
                    }
                }
            }
            .transition(.scale.combined(with: .opacity))
            
            Button(action: {
                // Open Modal
            }) {
                Text(isHovering ? "Page \(paginationManager.currentPage)" : "\(paginationManager.totalRows) rows")
                    .foregroundColor(.gray)
                    .frame(width: 60)
            }
           
            .buttonStyle(ActionButtonStyle(padding: EdgeInsets(top: 7, leading: 8, bottom: 7, trailing: 8), disableScaleEffect: true))
            
            Button(action: {
                withAnimation(.spring(response: 0.3)) {
                    viewModel.nextPage(filter: filter)
                }
            }) {
                Image(systemName: "chevron.right")
                    .foregroundColor(.white)
                    .opacity(isNextDisabled ? 0.3 : 1)
                    .font(.system(size: 14))
                    .contentShape(Rectangle())
            }
            .disabled(isNextDisabled)
            .buttonStyle(ActionButtonStyle(padding: EdgeInsets(top: 7, leading: 9, bottom: 7, trailing: 9)))
            .keyboardShortcut(.rightArrow, modifiers: .command)
            .customHelp( "Go to next page", position: .top, shortcut: KeyboardShortcut(
                modifiers: [.command],
                key: "→"
            ))
            .onHover { hovering in
                if !isNextDisabled {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isHovering = hovering
                    }
                }
            }
            .transition(.scale.combined(with: .opacity))
        }
    }
}
