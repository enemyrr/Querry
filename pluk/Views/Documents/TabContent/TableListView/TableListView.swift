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
    let selectedTab: DatabaseTab
    @Environment(ConnectionInstance.self) private var instance
    
    enum ViewState {
        case loading
        case error(String)
        case loaded(DatabaseService.QueryResult, DatabaseSchemaResult)
    }
    
    @State private var viewState: ViewState = .loading
    @State private var searchFilter: String = ""
    
    @State private var isLoading = false
    @State private var loadingError: Error?
    
    @State private var schema: DatabaseSchemaResult?
    @State private var documents: PostgreSQLQueryResult?
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                VStack {
                        switch viewState {
                             case .loading:
                                Text("")
                             case .error(let message):
                                Text(message)
//                                 ErrorStateView(
//                                     message: message,
//                                     retryAction: { await loadDocuments() }
//                                 )
                                 
                             case .loaded(let queryResult, let schema):
                                 if let postgresData = queryResult.data as? PostgreSQLQueryResult {
                                     TableListViewController(
                                         rows: postgresData,
                                         schema: schema
                                     )
                                 }
                             }
                    }
                .frame(
                    maxWidth: .infinity,
                    maxHeight: .infinity
                )
                .background(
                    Color(.controlBackgroundColor).opacity(0.5)
                )
                .cornerRadius(10)

                }
                
                VStack {
                    Spacer()
                    FloatingActionBar(screenWidth: geometry.size.width)
                        .padding(.bottom, 10)
                }
            .frame(width: geometry.size.width, height: geometry.size.height)
            .task(id: instance.selectedTab?.name) {
                if let selectedTab = instance.selectedTab {
                    do {
                        documents = try await instance
                            .fetchDocuments(from: selectedTab.name)
                    } catch {
                        print(error)
                    }
                }
            }
            .task { await loadDocuments() }
            .task(id: selectedTab.name) { await loadDocuments() }
            .refreshable { await loadDocuments() }
            //            .task(id: instance.selectedTab?.name) {
            //                if let selectedTab = instance.selectedTab {
            //                    do {
            //                        schema = try await instance.getSchema(for: selectedTab.name)
            //                    } catch {
            //                        print(error)
            //                    }
            //                }
            //            }
        }
        
    }
    
    private func loadDocuments() async {
        do {
            viewState = .loading
               
//            async let schemaTask = databaseService.getSchema(
//                for: selectedTab.name
//            )
//            async let documentsTask = databaseService.findDocuments(
//                in: selectedTab.name,
//                filter: searchFilter,
//                skip: selectedTab.skip,
//                limit: selectedTab.limit
//            )
               
//            let (schema, documents) = try await (schemaTask, documentsTask)
               
            guard let schema = schema else {
                viewState = .error("Could not load schema")
                return
            }
               
//            viewState = .loaded(documents, schema)
        } catch {
            viewState = .error(error.localizedDescription)
        }
    }
}
