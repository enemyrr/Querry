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
        print("🏁 TableListView.init()")
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
                            .background {
                                TabConnectedBorder()
                            }
                            .onAppear {
                                let appearTime = CFAbsoluteTimeGetCurrent()
                                print("✅ TableListViewController appeared at +\(String(format: "%.3f", appearTime - viewCreationTime))s")
                            }
                        } else {
                            VStack {}
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .background(Color(.controlBackgroundColor).opacity(0.5))
                            .cornerRadius(10)
                            .background {
                                TabConnectedBorder()
                            }
                        }
                    }
                    .task(id: viewModel.instance.selectedTab?.id) {
                        // Load schema first to show table structure immediately
                        if let selectedTab = viewModel.instance.selectedTab {
                            do {
                                let schemaStart = CFAbsoluteTimeGetCurrent()
                                print("🏗️ Loading schema to show table structure at +\(String(format: "%.3f", schemaStart - viewCreationTime))s")
                                let schemaResult = try await viewModel.databaseDriver.getSchema(for: selectedTab.name)
                                await MainActor.run {
                                    let schemaEnd = CFAbsoluteTimeGetCurrent()
                                    print("📋 Schema loaded at +\(String(format: "%.3f", schemaEnd - viewCreationTime))s - triggering view update")
                                    self.schema = schemaResult
                                    print("📋 Table structure ready with \(schemaResult.columns.count) columns")
                                }
                            } catch {
                                print("Failed to get schema: \(error)")
                            }
                        }
                    }
                    .task(id: viewModel.instance.selectedTab?.id) {
                        // Load data separately to fill the table
                        let dataStart = CFAbsoluteTimeGetCurrent()
                        print("📊 Starting data load at +\(String(format: "%.3f", dataStart - viewCreationTime))s")
                        await viewModel.loadDocuments()
                        let dataEnd = CFAbsoluteTimeGetCurrent()
                        print("🏁 Data load completed at +\(String(format: "%.3f", dataEnd - viewCreationTime))s")
                    }
                }
                
                VStack {
                    Spacer()
//                    let actionBarStart = CFAbsoluteTimeGetCurrent()
//                    print("🎬 Creating FloatingActionBar at +\(String(format: "%.3f", actionBarStart - viewCreationTime))s")
//                    
//                    FloatingActionBar(viewModel: viewModel, searchQueryViewModel: searchQueryViewModel, screenWidth: geometry.size.width)
//                        .padding(.bottom, 10)
//                        .onAppear {
//                            let actionBarAppear = CFAbsoluteTimeGetCurrent()
//                            print("🎬 FloatingActionBar appeared at +\(String(format: "%.3f", actionBarAppear - viewCreationTime))s")
//                        }
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
            .onAppear {
                let bodyStart = CFAbsoluteTimeGetCurrent()
                print("🔄 TableListView.body appeared at +\(String(format: "%.3f", bodyStart - viewCreationTime))s")
            }
            .onChange(of: geometry.size) { oldSize, newSize in
                let geometryTime = CFAbsoluteTimeGetCurrent()
                print("📐 GeometryReader updated at +\(String(format: "%.3f", geometryTime - viewCreationTime))s")
            }
        }
        .onAppear {
            let totalAppear = CFAbsoluteTimeGetCurrent()
            print("🎉 COMPLETE TableListView appeared at +\(String(format: "%.3f", totalAppear - viewCreationTime))s")
        }
    }
}
