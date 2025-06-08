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
            if let schema = schema {
                TableListViewController(
                    rows: viewModel.rowDocuments,
                    schema: schema
                )
                .background(Color(.controlColor).opacity(0.1))
                .cornerRadius(10)
                .background {
                    TabConnectedBorder()
                }
            } else {
                VStack {
                    ProgressView().controlSize(.small)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(.controlColor).opacity(0.1))
                .cornerRadius(10)
                .background {
                    TabConnectedBorder()
                }
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
        }
        .task {
            if !viewModel.intialLoadComplete {
                await viewModel.loadDocuments()
            }
        }
    }
}
