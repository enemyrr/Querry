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
    @State private var searchQueryViewModel: SearchQueryViewModel
    @State private var viewCreationTime = CFAbsoluteTimeGetCurrent()
    
    init(viewModel: DocumentListModel) {
        self.viewModel = viewModel
        self.searchQueryViewModel = SearchQueryViewModel(documentListModel: viewModel)
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                VStack {
                    Group {
                        if let customSchema = schema {
                            TableListViewController(
                                rows: viewModel.rowDocuments,
                                schema: customSchema
                            )
                            .background(Color(.controlBackgroundColor).opacity(0.5))
                            .cornerRadius(10)
                        } else {
                            VStack {}
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .background(Color(.controlBackgroundColor).opacity(0.5))
                            .cornerRadius(10)
                        }
                    }
                    .task(id: viewModel.instance.selectedTab?.id) {
                        // Load schema first to show table structure immediately
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
                    .task(id: viewModel.instance.selectedTab?.id) {
                        await viewModel.loadDocuments()
                    }
                }
                
                VStack {
                    Spacer()
                    FloatingActionBar(viewModel: viewModel, searchQueryViewModel: searchQueryViewModel, screenWidth: geometry.size.width)
                        .padding(.bottom, 10)
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
    }
}
