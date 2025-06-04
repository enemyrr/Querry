//
//  TableListView.swift
//  Pluk
//
//  Created by Fauzaan on 6/2/25.
//
import Foundation
import SwiftUI
import AppKit

// MARK: - SwiftUI View that internally uses AppKit
struct TableListView: View {
    private let viewModel: DocumentListModel
    
    init(viewModel: DocumentListModel) {
        self.viewModel = viewModel
    }
    
    var body: some View {
        InternalTableListViewWrapper(viewModel: viewModel)
            .background(Color.clear)
            .background {
                RoundedRectangle(cornerRadius: 10)
                    .stroke(.separator, lineWidth: 1)
            }
            .task {
                if !viewModel.intialLoadComplete {
                    await viewModel.loadDocuments()
                }
            }
    }
    
    private struct InternalTableListViewWrapper: NSViewControllerRepresentable {
        let viewModel: DocumentListModel
        
        func makeNSViewController(context: Context) -> TableListViewController {
            return TableListViewController(rows: viewModel.formattedDocuments)
        }
        
        func updateNSViewController(_ nsViewController: TableListViewController, context: Context) {
//            nsViewController.updateContent()
        }
    }
}

