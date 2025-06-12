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
    
    @State private var viewState: TableListViewState = .loading
    @State private var searchFilter: String = ""
    
    @State private var cachedSchema: DatabaseSchemaResult?
    @State private var cachedDocuments: DatabaseService.QueryResult?
    @State private var cachedTabName: String?
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                VStack {
                    switch viewState {
                    case .loading:
                        EmptyView()
                    case .error(let message):
                        ContentUnavailableView {
                            Label("Failed to Load", systemImage: "exclamationmark.triangle")
                        } description: {
                            Text(message)
                        }
                        
                    case .loaded(let queryResult, let schema):
                        if let postgresData = queryResult.data as? PostgreSQLQueryResult {
                            TableListViewController(
                                rows: postgresData,
                                schema: schema
                            )
                        }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(.controlBackgroundColor).opacity(0.2))
                .cornerRadius(10)
            }
            
            VStack {
                Spacer()
                FloatingActionBar(
                    screenWidth: geometry.size.width, 
                    viewState: viewState,
                    onRefresh: { currentPage, itemsPerPage, fetchSchema in
                        Task {
                            await loadDocuments(
                                forceFetch: true, 
                                fetchSchema: fetchSchema, 
                                page: currentPage, 
                                limit: itemsPerPage
                            ) 
                        } 
                    },
                    onLoadDocuments: { filter in
                        if let filter = filter {
                            searchFilter = filter
                        }
                        
                        Task {
                            await loadDocuments(forceFetch: true, fetchSchema: false, page: 1, limit: 300)
                        }
                    }
                )
                .padding(.bottom, 10)
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
            .task(id: selectedTab.name) {
                await loadDocumentsIfNeeded()
            }
            .onChange(of: searchFilter) { _, newValue in
                Task {
                    await loadDocuments(forceFetch: true, fetchSchema: false, page: 1, limit: 300)
                }
            }
        }
    }
    
    /// Load documents only if they don't exist in cache or tab has changed
    private func loadDocumentsIfNeeded() async {
        let shouldFetch = cachedTabName != selectedTab.name ||
        cachedSchema == nil ||
        cachedDocuments == nil
        
        if shouldFetch {
            await loadDocuments(forceFetch: true, fetchSchema: true, page: 1, limit: 300)
        } else {
            // Use cached data
            if let cachedDocuments = cachedDocuments,
               let cachedSchema = cachedSchema {
                viewState = .loaded(cachedDocuments, cachedSchema)
            }
        }
    }
    
    /// Load documents with options to force fetch and control schema fetching
    private func loadDocuments(forceFetch: Bool = false, fetchSchema: Bool = true, page: Int = 1, limit: Int = 300) async {
        guard let driver = instance.databaseService else {
            viewState = .error("Driver not set")
            return
        }
        
        // If not forcing fetch and we have cached data for the same tab, use it
        if !forceFetch &&
            cachedTabName == selectedTab.name,
           let cachedDocuments = cachedDocuments,
           let cachedSchema = cachedSchema {
            viewState = .loaded(cachedDocuments, cachedSchema)
            return
        }
        
        do {
            viewState = .loading
            
            // Determine what to fetch
            let schemaToUse: DatabaseSchemaResult
            let documentsResult: DatabaseService.QueryResult
            
            if fetchSchema && (cachedSchema == nil || cachedTabName != selectedTab.name) {
                // Fetch both schema and documents
                async let schemaTask = instance.getSchema(for: selectedTab.name)
                async let documentsTask = driver.findDocuments(
                    in: selectedTab.name,
                    filter: searchFilter,
                    skip: (page - 1) * limit,
                    limit: limit
                )
                
                let (schema, documents) = try await (schemaTask, documentsTask)
                
                guard let schema = schema else {
                    viewState = .error("Could not load schema")
                    return
                }
                
                schemaToUse = schema
                documentsResult = DatabaseService.QueryResult(
                    data: documents.data,
                    timestamp: Date(),
                    totalCount: documents.totalCount
                )
                
                // Cache the schema
                cachedSchema = schema
            } else {
                // Use cached schema, only fetch documents
                guard let schema = cachedSchema else {
                    viewState = .error("No cached schema available")
                    return
                }
                
                let documents = try await driver.findDocuments(
                    in: selectedTab.name,
                    filter: searchFilter,
                    skip: (page - 1) * limit,
                    limit: limit
                )
                
                schemaToUse = schema
                documentsResult = DatabaseService.QueryResult(
                    data: documents.data,
                    timestamp: Date(),
                    totalCount: documents.totalCount
                )
            }
            
            // Cache the results
            cachedDocuments = documentsResult
            cachedTabName = selectedTab.name
            
            viewState = .loaded(documentsResult, schemaToUse)
            
        } catch {
            viewState = .error(error.localizedDescription)
        }
    }
    
    /// Public method to refresh data when needed (e.g., from parent view)
    func refreshData() async {
        await loadDocuments(forceFetch: true, fetchSchema: true, page: 1, limit: 300)
    }
    
    /// Clear cache when needed (e.g., connection changes)
    func clearCache() {
        cachedSchema = nil
        cachedDocuments = nil
        cachedTabName = nil
        viewState = .loading
    }
}

enum TableListViewState {
    case loading
    case error(String)
    case loaded(DatabaseService.QueryResult, DatabaseSchemaResult)
}
