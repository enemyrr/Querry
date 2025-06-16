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
    @State private var cachedDocuments: QueryResult?
    @State private var cachedTabName: String?
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                VStack {
                    if cachedSchema != nil || currentQueryResult != nil {
                        TableListViewController(
                            schema: cachedSchema,
                            queryResult: currentQueryResult
                        )
                    }
                }
                .overlay {
                    overlayContent
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(.controlBackgroundColor).opacity(0.2))
                .cornerRadius(20)
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
            .onChange(of: instance.id) { _, _ in
                clearCache()
                Task {
                    await loadDocumentsIfNeeded()
                }
            }
        }
    }
    
    /// Overlay content for loading/error states
    @ViewBuilder
    private var overlayContent: some View {
        switch viewState {
        case .error(let message):
            ZStack {
                // Semi-transparent background
                Color(.controlBackgroundColor)
                    .opacity(0.8)
                    .cornerRadius(20)
                
                // Error content
                ContentUnavailableView {
                    Label("Failed to Load", systemImage: "exclamationmark.triangle")
                } description: {
                    Text(message)
                } actions: {
                    Button("Retry") {
                        Task {
                            await loadDocumentsIfNeeded()
                        }
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding(24)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
            }
            
        case .loaded, .loading:
            // No overlay when data is loaded
            EmptyView()
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
            let documentsResult: QueryResult
            
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
                documentsResult = documents
                
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
                documentsResult = documents
            }
            
            // Cache the results
            cachedDocuments = documentsResult
            cachedTabName = selectedTab.name
            
            // Note: For raw queries, the documentsResult.columns may differ from schemaToUse.columns
            // The TableListViewController will prioritize QueryResult columns over schema columns
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
    
    /// Extract current schema from viewState
    private var currentSchema: DatabaseSchemaResult? {
        if case .loaded(_, let schema) = viewState {
            return schema
        }
        return nil
    }
    
    /// Extract current query result from viewState
    private var currentQueryResult: QueryResult? {
        if case .loaded(let queryResult, _) = viewState {
            return queryResult
        }
        return nil
    }
}

enum TableListViewState {
    case loading
    case error(String)
    case loaded(QueryResult, DatabaseSchemaResult)
}
