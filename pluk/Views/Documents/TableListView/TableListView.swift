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
    @State private var schema: DatabaseSchemaResult?
    
    init(viewModel: DocumentListModel) {
        self.viewModel = viewModel
    }
    
    var body: some View {
        Group {
            if let rowDocuments = viewModel.rowDocuments, let schema = schema {
                InternalTableListViewWrapper(
                    rows: rowDocuments,
                    isLoading: viewModel.isLoading,
                    schema: schema
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
            if let selectedTab = viewModel.instance.selectedTab {
                do {
                    let schemaResult = try await viewModel.databaseDriver.getSchema(for: selectedTab.name)
                    await MainActor.run {
                        self.schema = schemaResult
                    }
                } catch {
                    print("Failed to get schema: \(error)")
                }
            }
            
            if !viewModel.intialLoadComplete {
                await viewModel.loadDocuments()
            }
        }
    }
    
    private struct InternalTableListViewWrapper: NSViewControllerRepresentable {
        var rows: PostgreSQLQueryResult
        var isLoading: Bool = false
        var schema: DatabaseSchemaResult
        
        func makeNSViewController(context: Context) -> TableListViewController {
            return TableListViewController(rows: rows, schema: schema)
        }
        
        func updateNSViewController(_ nsViewController: TableListViewController, context: Context) {
            nsViewController.updateRows(rows, isLoading: isLoading, schema: schema)
        }
    }
}

