//
//  Pagination.swift
//  Collection
//
//  Created by Fauzaan on 3/6/25.
//

import SwiftUI

struct Pagination: View {
    @ObservedObject var viewModel: DocumentViewModel
    
    var body: some View {
        HStack(spacing: 0) {
            if viewModel.currentPage > 1 {
                Button(action: {
                    withAnimation(.spring(response: 0.3)) {
                        viewModel.previousPage()
                    }
                }) {
                    Image(systemName: "chevron.left")
                        .foregroundColor(.white)
                        .font(.system(size: 14))
                        .contentShape(Rectangle())
                }
                .buttonStyle(ActionButtonStyle(padding: EdgeInsets(top: 7, leading: 9, bottom: 7, trailing: 9)))
            }
            
            Button(action: {
                // Open Modal
            }) {
                Text("\(viewModel.totalItems) documents").foregroundColor(.gray)
            }
            .buttonStyle(ActionButtonStyle(padding: EdgeInsets(top: 7, leading: 8, bottom: 7, trailing: 8), disableScaleEffect: true))
            
            if viewModel.currentPage < viewModel.totalPages {
                Button(action: {
                    withAnimation(.spring(response: 0.3)) {
                        viewModel.nextPage()
                    }
                }) {
                    Image(systemName: "chevron.right")
                        .foregroundColor(.white)
                        .font(.system(size: 14))
                        .contentShape(Rectangle())
                }
                .buttonStyle(ActionButtonStyle(padding: EdgeInsets(top: 7, leading: 9, bottom: 7, trailing: 9)))
            }
        }
    }
}
