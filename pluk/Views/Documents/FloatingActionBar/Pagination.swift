//
//  Pagination.swift
//  Collection
//
//  Created by Fauzaan on 3/6/25.
//

import SwiftUI
import MongoKitten

struct Pagination: View {
    @Binding var currentPage: Int
    var totalPages: Int
    var totalCount: Int
    var totalPerPage: Int
    let onRefresh: () -> Void
    
    @Environment(ConnectionInstance.self) private var instance
    @State private var filter: String?
    @State private var isPreviousHovering = false
    @State private var isNextHovering = false
    @State private var previousClickCooldown = false
    @State private var nextClickCooldown = false
    
    // Computed property to determine if either button is being hovered
    private var isAnyButtonHovering: Bool {
        isPreviousHovering || isNextHovering
    }
    
    var body: some View {
        let isPreviousDisabled = currentPage <= 1
        let isNextDisabled = totalCount != totalPerPage
        
        HStack(spacing: 0) {
            Button(action: {
                withAnimation(.spring(response: 0.3)) {
                    previousPage(filter: filter)
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
            ), spacing: 10)
            .onHover { hovering in
                withAnimation(.easeInOut(duration: 0.2)) {
                    isPreviousHovering = hovering
                }
            }
            .transition(.scale.combined(with: .opacity))
            
            Button(action: {
                // Open Modal
            }) {
                Text(isAnyButtonHovering ? "Page \(currentPage)" : "\(totalCount) rows")
                    .foregroundColor(.gray)
                    .frame(width: 60)
            }
            
            .buttonStyle(ActionButtonStyle(padding: EdgeInsets(top: 7, leading: 8, bottom: 7, trailing: 8), disableScaleEffect: true))
            
            Button(action: {
                withAnimation(.spring(response: 0.3)) {
                    nextPage(filter: filter)
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
            ), spacing: 10)
            .onHover { hovering in
                withAnimation(.easeInOut(duration: 0.2)) {
                    isNextHovering = hovering
                }
            }
            .transition(.scale.combined(with: .opacity))
        }
    }
    
    
    
    // MARK: - Pagination Methods
    @MainActor
    func nextPage(filter: String?) {
        currentPage += 1
        onRefresh()
    }
    
    @MainActor
    func previousPage(filter: String?) {
        guard currentPage > 1 else { return }
        self.currentPage -= 1
        onRefresh()
    }
}
