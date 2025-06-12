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
    
    @State private var cachedSchema: DatabaseSchemaResult?
    @State private var cachedDocuments: DatabaseService.QueryResult?
    @State private var cachedTabName: String?
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                VStack {
                    switch viewState {
                    case .loading:
                        ProgressView("Loading...")
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                        
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
                // FloatingActionBar(screenWidth: geometry.size.width)
                //     .padding(.bottom, 10)
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
            .task(id: selectedTab.name) {
                await loadDocumentsIfNeeded()
            }
            .onChange(of: searchFilter) { _, newValue in
                // Only refetch documents when search filter changes, keep schema cached
                Task {
                    await loadDocuments(forceFetch: true, fetchSchema: false)
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
            await loadDocuments(forceFetch: true, fetchSchema: true)
        } else {
            // Use cached data
            if let cachedDocuments = cachedDocuments,
               let cachedSchema = cachedSchema {
                viewState = .loaded(cachedDocuments, cachedSchema)
            }
        }
    }
    
    /// Load documents with options to force fetch and control schema fetching
    private func loadDocuments(forceFetch: Bool = false, fetchSchema: Bool = true) async {
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
                    filter: searchFilter
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
                    filter: searchFilter
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
        await loadDocuments(forceFetch: true, fetchSchema: true)
    }
    
    /// Clear cache when needed (e.g., connection changes)
    func clearCache() {
        cachedSchema = nil
        cachedDocuments = nil
        cachedTabName = nil
        viewState = .loading
    }
}
