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
    @Environment(\.colorScheme) var colorScheme
    
    @State private var viewState: TableListViewState = .loading
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
    @State private var needsToSelectLastRow = false
    
    // Generic error handling
    @State private var currentError: Error?
    @State private var showingErrorAlert = false
    @State private var showingViewStateError = false
    @State private var viewStateErrorMessage: String = ""
    
    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                FilterBuilderView(columns: cachedSchema?.columns ?? [], tableName: selectedTab.name) { filter in
                    Task {
                        await loadDocuments(forceFetch: true, filter: filter)
                    }
                }
                
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
                        modificationTracker: modificationTracker,
                        needsToSelectLastRow: needsToSelectLastRow,
                        onDeleteNewRow: { index in
                            deleteNewlyAddedRecord(atIndex: index)
                            needsToSelectLastRow = false
                        }
                    )
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(
                Color(colorScheme == .dark ? .black : .white).opacity(0.6)
            )
            
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
                        Task {
                            await loadDocuments(forceFetch: true, fetchSchema: false, page: 1, limit: 300, filter: filter)
                        }
                    },
                    onCommitModifications: {
                        Task {
                            await commitModifications()
                        }
                    },
                    onNewRecord: {
                        handleNewRecord()
                    },
                    currentQueryResult: currentQueryResult
                )
                .padding(.bottom, 10)
            }
        }
        .task(id: selectedTab.name) {
            await loadDocumentsIfNeeded()
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
        .alert(
            "Error",
            isPresented: $showingViewStateError
        ) {
            Button("OK") {}
        } message: {
            Text(viewStateErrorMessage)
        }
        .onChange(of: viewState) { _, newValue in
            if case .error(let message) = newValue {
                viewStateErrorMessage = message
                showingViewStateError = true
            }
        }
    }
    
    // MARK: - Error Handling
    private func showError(_ error: Error) {
        currentError = error
        showingErrorAlert = true
    }
    
    // MARK: - Save Modifications
    private func commitModifications() async {
        guard let driver = instance.databaseService else {
            debugLog("❌ No database driver available")
            return
        }
        
        NSApp.keyWindow?.makeFirstResponder(nil)
        
        let modifications = modificationTracker.allModifications
        
        guard !modifications.isEmpty else {
            debugLog("ℹ️ No modifications to save")
            return
        }
        
        debugLog("💾 Saving \(modifications.count) modified rows...")
        
        for rowModification in modifications {
            do {
                switch rowModification.type {
                case .insert:
                    var newDocument = [String: Any]()
                    for (columnName, cellMod) in rowModification.cellModifications {
                        newDocument[columnName] = cellMod.newValue
                    }
                    try await driver.createDocument(in: selectedTab.name, document: newDocument)
                    debugLog("✅ Inserted new row at index \(rowModification.rowIndex)")
                    
                case .update:
                    // Get the row data
                    guard let currentQueryResult = currentQueryResult,
                          rowModification.rowIndex < currentQueryResult.rawRows.count else {
                        debugLog("❌ Invalid row index: \(rowModification.rowIndex)")
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
                    var rowId: Any?
                    if let idValue = originalRow["id"] {
                        rowId = idValue
                    } else if let firstColumn = currentQueryResult.columns.first {
                        rowId = originalRow[firstColumn.name]
                    }
                    
                    guard let id = rowId else {
                        debugLog("❌ Could not find row identifier for row \(rowModification.rowIndex)")
                        continue
                    }
                    
                    // Use the database driver to update the row
                    try await driver.updateDocument(
                        in: selectedTab.name,
                        id: id,
                        data: updateData
                    )
                    
                    debugLog("✅ Updated row \(rowModification.rowIndex) with \(updateData.count) changes")
                case .delete:
                    // Get the row data
                    guard let currentQueryResult = currentQueryResult,
                          rowModification.rowIndex < currentQueryResult.rawRows.count else {
                        debugLog("❌ Invalid row index: \(rowModification.rowIndex)")
                        continue
                    }
                    
                    let originalRow = currentQueryResult.rawRows[rowModification.rowIndex]
                    
                    // Find the primary key or unique identifier for this row
                    var rowId: Any?
                    if let idValue = originalRow["id"] {
                        rowId = idValue
                    } else if let firstColumn = currentQueryResult.columns.first {
                        rowId = originalRow[firstColumn.name]
                    }
                    
                    guard let id = rowId else {
                        debugLog("❌ Could not find row identifier for row \(rowModification.rowIndex)")
                        continue
                    }
                    
                    try await driver.deleteDocument(in: selectedTab.name, id: id)
                    debugLog("✅ Deleted row at index \(rowModification.rowIndex)")
                }
            } catch {
                showError(error)
                return
            }
        }
        
        // Clear modifications after successful save
        modificationTracker.resetAllModifications()
        
        // Optionally refresh the data to show the saved changes
        await loadDocuments(forceFetch: true, fetchSchema: false, page: 1, limit: 300)
        
        debugLog("✅ All modifications saved successfully")
    }
    
    private func handleNewRecord() {
        guard let schema = cachedSchema, let currentResult = cachedDocuments else { return }
        
        var newRawRow = [String: Any]()
        var newProcessedRow = [String: QueryRowInfo]()
        
        for column in schema.columns {
            newRawRow[column.columnName] = nil
            newProcessedRow[column.columnName] = QueryRowInfo(
                value: nil,
                dataType: column.dataType,
                format: column.formatType
            )
        }
        
        let newIndex = currentResult.rawRows.count
        modificationTracker.markAsNewRow(rowIndex: newIndex, initialData: newRawRow)
        
        var updatedRawRows = currentResult.rawRows
        updatedRawRows.append(newRawRow)
        
        var updatedProcessedRows = currentResult.rows
        updatedProcessedRows.append(newProcessedRow)
        
        // Always use schema to populate columns for consistency
        let columnsFromSchema = schema.columns.enumerated().map { (index, schemaColumn) in
            QueryColumnInfo(
                name: schemaColumn.columnName,
                dataType: schemaColumn.dataType,
                format: schemaColumn.formatType,
                index: index
            )
        }
        
        let updatedResult = QueryResult(
            columns: columnsFromSchema,
            rows: updatedProcessedRows,
            totalCount: currentResult.totalCount + 1,
            rawRows: updatedRawRows
        )
        
        cachedDocuments = updatedResult
        
        if let updatedDocuments = cachedDocuments, let currentSchema = cachedSchema {
            viewState = .loaded(updatedDocuments, currentSchema)
        }
        
        needsToSelectLastRow = true
    }
    
    func deleteNewlyAddedRecord(atIndex: Int) {
        guard let currentResult = cachedDocuments else { return }
        
        // Ensure the index is valid
        guard atIndex >= 0 && atIndex < currentResult.rawRows.count else {
            debugLog("❌ Invalid index for deletion: \(atIndex)")
            return
        }
        
        // Remove from raw rows
        var updatedRawRows = currentResult.rawRows
        modificationTracker.deleteRow(rowIndex: atIndex)
        updatedRawRows.remove(at: atIndex)
        
        // Remove from processed rows
        var updatedProcessedRows = currentResult.rows
        updatedProcessedRows.remove(at: atIndex)
        
        // Create updated result
        let updatedResult = QueryResult(
            columns: currentResult.columns,
            rows: updatedProcessedRows,
            totalCount: currentResult.totalCount - 1,
            rawRows: updatedRawRows
        )
        
        // Update cached documents
        cachedDocuments = updatedResult
        
        // Update view state
        if let updatedDocuments = cachedDocuments, let currentSchema = cachedSchema {
            viewState = .loaded(updatedDocuments, currentSchema)
        }
        
        debugLog("✅ Deleted new record at index \(atIndex)")
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
    private func loadDocuments(forceFetch: Bool = false, fetchSchema: Bool = true, page: Int = 1, limit: Int = 300, filter: String? = nil) async {
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
                    filter: filter ?? "",
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
                    filter: filter ?? "",
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
            debugLog(error.localizedDescription)
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
        // During loading, return cached schema to prevent UI flicker
        return cachedSchema
    }
    
    /// Extract current query result from viewState
    private var currentQueryResult: QueryResult? {
        if case .loaded(let queryResult, _) = viewState {
            return queryResult
        }
        // During loading, return cached documents to prevent UI flicker
        return cachedDocuments
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

enum TableListViewState: Equatable {
    case loading
    case error(String)
    case loaded(QueryResult, DatabaseSchemaResult)
    
    var isError: Bool {
        if case .error = self {
            return true
        }
        return false
    }
    
    static func == (lhs: TableListViewState, rhs: TableListViewState) -> Bool {
        switch (lhs, rhs) {
        case (.loading, .loading):
            return true
        case (.error(let lhsMessage), .error(let rhsMessage)):
            return lhsMessage == rhsMessage
        case (.loaded(let lhsResult, let lhsSchema), .loaded(let rhsResult, let rhsSchema)):
            // Simple comparison - you might want to implement proper equality for QueryResult and DatabaseSchemaResult
            return lhsResult.totalCount == rhsResult.totalCount && 
                   lhsSchema.columns.count == rhsSchema.columns.count
        default:
            return false
        }
    }
}
