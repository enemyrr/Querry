//
//  TableListView.swift
//  Pluk
//
//  Created by Fauzaan on 6/2/25.
//
import Foundation
import SwiftUI
import AppKit

struct TableListView: View {
    private let viewModel: DocumentListModel
    
    init(viewModel: DocumentListModel) {
        self.viewModel = viewModel
    }
    
    var body: some View {
        Group {
            if let rowDocuments = viewModel.rowDocuments {
                InternalTableListViewWrapper(
                    rows: rowDocuments,
                    isLoading: viewModel.isLoading
                )
                .background {
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(.separator, lineWidth: 1)
                }
            } else {
                ProgressView().controlSize(.small)
            }
        }
        .task {
            if !viewModel.intialLoadComplete {
                await viewModel.loadDocuments()
            }
        }
    }
    
    private struct InternalTableListViewWrapper: NSViewControllerRepresentable {
        var rows: PostgreSQLQueryResult
        var isLoading: Bool = false
        
        func makeNSViewController(context: Context) -> TableListViewController {
            return TableListViewController(rows: rows)
        }
        
        func updateNSViewController(_ nsViewController: TableListViewController, context: Context) {
            nsViewController.updateRows(rows, isLoading: isLoading)
        }
    }
}

