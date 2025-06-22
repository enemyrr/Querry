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
    @State private var sortColumn: String?
    @State private var sortAscending: Bool = true
    
    @State private var cachedSchema: DatabaseSchemaResult?
    @State private var cachedDocuments: QueryResult?
    @State private var cachedTabName: String?
    
    // Task management for preventing race conditions
    @State private var loadingTask: Task<Void, Never>?
    
    // Modification tracking
    @State private var modificationTracker = TableModificationTracker()
    @State private var isProcessingUpdates = false
    
    // Generic error handling
    @State private var currentError: Error?
    @State private var showingErrorAlert = false
    
    var body: some View {
        ZStack {
            VStack {
                if cachedSchema != nil || currentQueryResult != nil {
                    TableListViewController(
                        schema: cachedSchema,
                        queryResult: currentQueryResult,
                        tableName: selectedTab.name,
                        onSort: { column, ascending in
                            sortColumn = column
                            sortAscending = ascending
                            loadingTask?.cancel()
                            loadingTask = Task {
                                await loadDocuments(forceFetch: true, fetchSchema: false, page: 1, limit: 300)
                            }
                        },
                        modificationTracker: modificationTracker
                    )
                }
            }
            .overlay {
                overlayContent
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(.controlBackgroundColor).opacity(0.5))
            .cornerRadius(20)
            
            VStack {
                Spacer()
                FloatingActionBar(
                    viewState: viewState,
                    tableName: selectedTab.name,
                    modificationTracker: modificationTracker,
                    isProcessingUpdates: isProcessingUpdates,
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
                    },
                    onSaveChanges: {
                        Task {
                            await saveModifications()
                        }
                    }
                )
                .padding(.bottom, 10)
            }
        }
        .task(id: selectedTab.name) {
            await loadDocumentsIfNeeded()
        }
        .onChange(of: searchFilter) { _, newValue in
            loadingTask?.cancel()
            modificationTracker.resetAllModifications()
            loadingTask = Task {
                await loadDocuments(forceFetch: true, fetchSchema: false, page: 1, limit: 300)
            }
        }
        .onChange(of: instance.id) { _, _ in
            loadingTask?.cancel()
            clearCache()
            modificationTracker.resetAllModifications()
            loadingTask = Task {
                await loadDocumentsIfNeeded()
            }
        }
        .onDisappear {
            loadingTask?.cancel()
        }.alert(
            "Update Failed",
            isPresented: $showingErrorAlert,
            presenting: currentError
        ) { error in
            Button("OK") {}
        } message: { error in
            Text(error.localizedDescription)
        }
        .background(
            // Hidden button for keyboard shortcut handling
            Button("") {
                Task {
                    await performUndo()
                }
            }
            .keyboardShortcut("z", modifiers: .command)
            .opacity(0)
            .allowsHitTesting(false)
        )
    }
    
    // MARK: - Error Handling
      private func showError(_ error: Error) {
          currentError = error
          showingErrorAlert = true
      }
      
      private func handleErrorRetry(_ error: Error) async {
          // Generic retry logic - you can customize this based on the error type
          if error is DatabaseError {
              await loadDocuments(forceFetch: true, fetchSchema: true, page: 1, limit: 300)
          } else {
              await loadDocumentsIfNeeded()
          }
      }
      
      // MARK: - Undo Functionality
      private func performUndo() async {
          guard modificationTracker.canUndo else {
              print("ℹ️ No modifications to undo")
              return
          }
          
          let success = modificationTracker.undo()
          if success {
              print("✅ Undo successful")
          } else {
              print("❌ Undo failed")
          }
      }
    
    // MARK: - Save Modifications
    private func saveModifications() async {
        guard let driver = instance.databaseService else {
            print("❌ No database driver available")
            return
        }
        
        let modifications = modificationTracker.allModifications
        guard !modifications.isEmpty else {
            print("ℹ️ No modifications to save")
            return
        }
        
        print("💾 Saving \(modifications.count) modified rows...")
        
        for rowModification in modifications {
            do {
                // Get the row data
                guard let currentQueryResult = currentQueryResult,
                      rowModification.rowIndex < currentQueryResult.rawRows.count else {
                    print("❌ Invalid row index: \(rowModification.rowIndex)")
                    continue
                }
                
                let originalRow = currentQueryResult.rawRows[rowModification.rowIndex]
                
                // Create update data with only modified columns
                var updateData: [String: Any] = [:]
                for (columnName, cellMod) in rowModification.cellModifications {
                    if cellMod.hasChanged {
                        updateData[columnName] = cellMod.newValue
                    }
                }
                
                // Find the primary key or unique identifier for this row
                // This is a simplified approach - you might need to adapt based on your schema
                var rowId: Any?
                if let idValue = originalRow["id"] {
                    rowId = idValue
                } else if let firstColumn = currentQueryResult.columns.first {
                    rowId = originalRow[firstColumn.name]
                }
                
                guard let id = rowId else {
                    print("❌ Could not find row identifier for row \(rowModification.rowIndex)")
                    continue
                }
                
                // Use the database driver to update the row
                try await driver.updateDocument(
                    in: selectedTab.name,
                    id: id,
                    data: updateData
                )
                
                print("✅ Updated row \(rowModification.rowIndex) with \(updateData.count) changes")
            } catch {
                showError(error)
                return
            }
        }
        
        // Clear modifications after successful save
        modificationTracker.resetAllModifications()
        
        // Optionally refresh the data to show the saved changes
        await loadDocuments(forceFetch: true, fetchSchema: false, page: 1, limit: 300)
        
        print("✅ All modifications saved successfully")
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
        
        // Check if task was cancelled before proceeding
        if Task.isCancelled { return }
        
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
            
            // Check if task was cancelled after setting loading state
            if Task.isCancelled { return }
            
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
                    limit: limit,
                    sortBy: sortColumn,
                    ascending: sortAscending
                )
                
                let (schema, documents) = try await (schemaTask, documentsTask)
                
                // Check if task was cancelled after async operations
                if Task.isCancelled { return }
                
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
                    limit: limit,
                    sortBy: sortColumn,
                    ascending: sortAscending
                )
                
                // Check if task was cancelled after document fetch
                if Task.isCancelled { return }
                
                schemaToUse = schema
                documentsResult = documents
            }
            
            // Final check before updating state
            if Task.isCancelled { return }
            
            // Cache the results
            cachedDocuments = documentsResult
            cachedTabName = selectedTab.name
            
            // Check if this is a raw query with different columns than schema
            if hasColumnMismatch(queryResult: documentsResult, schema: schemaToUse) {
                // Update tab to indicate schema deviation
                updateTabSchemaDeviation(true)
            } else {
                // Reset schema deviation if columns match
                updateTabSchemaDeviation(false)
            }
            
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
        loadingTask?.cancel()
        cachedSchema = nil
        cachedDocuments = nil
        cachedTabName = nil
        sortColumn = nil
        sortAscending = true
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
    
    private func hasColumnMismatch(queryResult: QueryResult?, schema: DatabaseSchemaResult?) -> Bool {
        guard let queryResult = queryResult, let schema = schema else {
            return false
        }
        
        // If query result has columns but they don't match schema columns, it's likely a raw query
        if !queryResult.columns.isEmpty {
            let queryColumnNames = Set(queryResult.columns.map { $0.name })
            let schemaColumnNames = Set(schema.columns.map { $0.columnName })
            return queryColumnNames != schemaColumnNames
        }
        
        return false
    }
    
    /// Update the selected tab's schema deviation state
    private func updateTabSchemaDeviation(_ hasDeviation: Bool) {
        if let tabIndex = instance.tabs.firstIndex(where: { $0.id == selectedTab.id }) {
            instance.tabs[tabIndex].hasSchemaDeviation = hasDeviation
        }
    }
}

enum TableListViewState {
    case loading
    case error(String)
    case loaded(QueryResult, DatabaseSchemaResult)
}
