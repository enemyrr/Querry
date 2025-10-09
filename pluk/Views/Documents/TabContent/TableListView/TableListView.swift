//
//  TableListView.swift
//  Pluk
//
//  Created by Fauzaan on 6/2/25.
//
import Foundation
import SwiftUI
import AppKit
import ConvexMobile
import Combine

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
    
    // Filter conditions state
    @State private var filterConditions: [FilterCondition] = [FilterCondition(conjunction: .whereClause, field: "", filterOperator: .equals, value: "")]
    @State private var lastTabFilterColumn: String?
    @State private var lastTabFilterValue: String?
    @State private var currentActiveFilter: String? = nil
    
    // Real-time subscription state
    @State private var isSubscribedToRealTime = false
    @State private var receivedFirstRealtimeEvent = false
    @State private var skipNextRealtimeEvent = false
    
    // ConvexMobile testing
    @State private var convexSubscription: AnyCancellable?
    
    // Smart deduplication and change tracking
    @State private var changeDetector = TableChangeDetector()
    @State private var updatedFields: Set<String> = []
    @State private var updatedRows: Set<Int> = []
    
    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                FilterBuilderView(
                    columns: cachedSchema?.columns ?? [], 
                    tableName: selectedTab.name,
                    databaseSchema: selectedTab.databaseSchema,
                    onApplyFilter: { filter in
                        currentActiveFilter = filter.isEmpty ? nil : filter
                        Task {
                            skipNextRealtimeEvent = true
                            await loadOrSubscribe(forceFetch: true, fetchSchema: false, page: 1, limit: 300, filter: filter)
                        }
                    },
                    conditions: $filterConditions
                )
                
                if cachedSchema != nil || currentQueryResult != nil {
                    Divider()
                    TableListViewController(
                        schema: cachedSchema,
                        queryResult: currentQueryResult,
                        tableName: selectedTab.name,
                        cacheNamespace: instance.connection.persistentModelID.storeIdentifier,
                        onSort: { column, ascending in
                            sortColumn = column
                            sortAscending = ascending
                            loadingTask?.cancel()
                            loadingTask = Task {
                                skipNextRealtimeEvent = true
                                await loadOrSubscribe(forceFetch: true, fetchSchema: false, page: 1, limit: 300, filter: currentActiveFilter)
                            }
                        },
                        modificationTracker: modificationTracker,
                        needsToSelectLastRow: needsToSelectLastRow,
                        onDeleteNewRow: { index in
                            deleteNewlyAddedRecord(atIndex: index)
                            needsToSelectLastRow = false
                        },
                        onForeignKeyNavigation: { tableName, columnName, value in
                            instance.createNewTab(name: tableName, filterColumn: columnName, filterValue: value, databaseSchema: selectedTab.databaseSchema)
                        },
                        highlightedFields: updatedFields,
                        highlightedRows: updatedRows
                    )
                } else {
                    Spacer()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(
                Color(colorScheme == .dark ?  Color(.black).opacity(0.25) : Color(.white))
                    .shadow(color: Color(.sRGBLinear, white: 0, opacity: 0.05), radius: 4)
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
                            skipNextRealtimeEvent = true
                             await loadOrSubscribe(
                                 forceFetch: true,
                                 fetchSchema: fetchSchema,
                                 page: currentPage,
                                 limit: itemsPerPage,
                                 filter: currentActiveFilter
                             )
                        }
                    },
                    onLoadDocuments: { filter in
                        Task {
                            skipNextRealtimeEvent = true
                            await loadOrSubscribe(forceFetch: true, fetchSchema: false, page: 1, limit: 300, filter: filter)
                        }
                    },
                    onCommitModifications: {
                        Task {
                            isProcessingUpdates = true
                            await commitModifications()
                            isProcessingUpdates = false
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
            // Set default sort order based on database type
            if instance.connection.databaseType == .convex {
                sortAscending = false // Convex defaults to descending (newest first)
            } else {
                sortAscending = true  // Other databases default to ascending
            }

            // Update filter conditions when tab changes
            updateFilterConditions()
            await loadDocumentsIfNeeded()
        }
        .onDisappear {
            loadingTask?.cancel()
            convexSubscription?.cancel() // Clean up ConvexMobile subscription
            cancelRealTimeSubscription() // Clean up real-time subscription
        }.alert(
            "Operation Failed",
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
                    try await instance.databaseService.createDocument(in: selectedTab.name, databaseSchema: selectedTab.databaseSchema, document: newDocument)
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
                    if let idValue = originalRow["_id"] {
                        rowId = idValue
                    } else if let idValue = originalRow["id"] {
                        rowId = idValue
                    } else if let firstColumn = currentQueryResult.columns.first {
                        rowId = originalRow[firstColumn.name]
                    }
                    
                    guard let id = rowId else {
                        debugLog("❌ Could not find row identifier for row \(rowModification.rowIndex)")
                        continue
                    }
                    
                    // Use the database driver to update the row
                    try await instance.databaseService.updateDocument(
                        in: selectedTab.name,
                        databaseSchema: selectedTab.databaseSchema,
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
                    if let idValue = originalRow["_id"] {
                        rowId = idValue
                    } else if let idValue = originalRow["id"] {
                        rowId = idValue
                    } else if let firstColumn = currentQueryResult.columns.first {
                        rowId = originalRow[firstColumn.name]
                    }
                    
                    guard let id = rowId else {
                        debugLog("❌ Could not find row identifier for row \(rowModification.rowIndex)")
                        continue
                    }
                    
                    try await instance.databaseService.deleteDocument(in: selectedTab.name, databaseSchema: selectedTab.databaseSchema, id: id)
                    debugLog("✅ Deleted row at index \(rowModification.rowIndex)")
                }
            } catch {
                showError(error)
                return
            }
        }
        
        modificationTracker.resetAllModifications()
        
        // Clear modifications after successful save
        if !instance.databaseService.supportsRealTime {
            await loadDocuments(forceFetch: true, fetchSchema: false, page: 1, limit: 300, filter: currentActiveFilter)
        }
        
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
        cachedDocuments == nil || selectedTab.forceFetch
        
        if shouldFetch {
            // Apply initial filter if tab has filter information
            let initialFilter = generateInitialFilter()
            currentActiveFilter = initialFilter
            await loadOrSubscribe(forceFetch: true, fetchSchema: true, page: 1, limit: 300, filter: initialFilter)
            selectedTab.forceFetch = false
        } else {
            if let cachedDocuments = cachedDocuments,
               let cachedSchema = cachedSchema {
                viewState = .loaded(cachedDocuments, cachedSchema)
            }
            
            // Still try to subscribe for real-time if not already subscribed
            if !isSubscribedToRealTime {
                await subscribeToRealTimeUpdatesIfSupported(page: 1)
            }
        }
    }
    
    private func generateInitialFilter() -> String? {
        guard let conditions = createInitialFilterConditions() else {
            return nil
        }
        
        return instance.databaseService.generateFilterQuery(from: conditions, tableName: selectedTab.name, databaseSchema: selectedTab.databaseSchema)
    }
    
    private func createInitialFilterConditions() -> [FilterCondition]? {
        guard let filterColumn = selectedTab.filterColumn,
              let filterValue = selectedTab.filterValue else {
            return nil
        }
        
        return [FilterCondition(
            conjunction: .whereClause,
            field: filterColumn,
            filterOperator: .equals,
            value: filterValue
        )]
    }
    
    // MARK: - Real-time Subscription
    
    private func subscribeToRealTimeUpdatesIfSupported(page: Int = 1) async {
        // Check if database supports real-time and we're not already subscribed
        guard instance.databaseService.supportsRealTime && !isSubscribedToRealTime else {
            return
        }
        
        do {
            try await instance.databaseService.subscribeToTableChanges(
                tabId: selectedTab.id,
                tableName: selectedTab.name,
                schema: selectedTab.databaseSchema,
                filter: currentActiveFilter,
                limit: 300,
                sortBy: sortColumn,
                ascending: sortAscending,
                page: page,
                onUpdate: { updatedResult in
                    DispatchQueue.main.async {
                        self.handleRealTimeUpdate(updatedResult)
                    }
                },
                onError: { error in
                    DispatchQueue.main.async {
                        self.handleRealTimeError(error)
                    }
                }
            )
            isSubscribedToRealTime = true
            debugLog("✅ Subscribed to real-time updates for table: \(selectedTab.name)")
        } catch {
            debugLog("❌ Failed to subscribe to real-time updates: \(error)")
        }
    }
    
    private func handleRealTimeUpdate(_ updatedResult: QueryResult) {
        receivedFirstRealtimeEvent = true

        // If this is the first event after a resubscribe (e.g., filter change),
        // treat it as a baseline (no highlights) and reset the flag.
        if skipNextRealtimeEvent {
            skipNextRealtimeEvent = false
            changeDetector.baseline(with: updatedResult)
            if cachedSchema == nil {
                Task {
                    if let schema = try await instance.databaseService.getSchema(for: selectedTab.name, databaseSchema: selectedTab.databaseSchema) {
                        await MainActor.run { self.cachedSchema = schema }
                    }
                }
            }
            // Update state with the new baseline data without highlighting
            if let currentSchema = cachedSchema {
                viewState = .loading
                viewState = .loaded(updatedResult, currentSchema)
            }
            cachedDocuments = updatedResult
            return
        }

        // Smart deduplication via TableChangeDetector
        let change: TableChangeDetector.ChangeResult
        if cachedDocuments == nil && changeDetector.lastHash == nil || skipNextRealtimeEvent {
            // First dataset: baseline without highlighting changes
            changeDetector.baseline(with: updatedResult)
            change = .init(changedFields: [], changedRows: [], changedCells: [:], isDifferent: true)
            skipNextRealtimeEvent = false
        } else {
            // Heuristic: exclusive mode if row count changes
            let oldCount = cachedDocuments?.rawRows.count ?? 0
            let newCount = updatedResult.rawRows.count
            if oldCount != newCount {
                change = changeDetector.detectExclusive(old: cachedDocuments, new: updatedResult)
            } else {
                change = changeDetector.detect(old: cachedDocuments, new: updatedResult)
            }
        }
        
        guard change.isDifferent else {
            debugLog("📊 Real-time update skipped - no changes detected for table: \(selectedTab.name)")
            return
        }
        
        // Ensure we have schema for display on first event
        if cachedSchema == nil {
            Task {
                if let schema = try await instance.databaseService.getSchema(for: selectedTab.name, databaseSchema: selectedTab.databaseSchema) {
                    await MainActor.run { self.cachedSchema = schema }
                }
            }
        }

        // Translate per-cell map to existing field/row sets expected by controller
        var fields = Set<String>()
        var rows = Set<Int>()
        for (rowIndex, cols) in change.changedCells {
            rows.insert(rowIndex)
            fields.formUnion(cols)
        }
        updatedFields = fields
        updatedRows = rows
        
        // Update view state to reflect the changes
        if let currentSchema = cachedSchema {
            viewState = .loading
            viewState = .loaded(updatedResult, currentSchema)
        }
        
        // Update cached documents
        cachedDocuments = updatedResult
        
        // Optimized reconciliation: only check changed cells
        modificationTracker.reconcile(changedCells: change.changedCells, in: updatedResult)
        
        // Clear highlights after a delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.50) {
            self.updatedFields.removeAll()
            self.updatedRows.removeAll()
        }
    }
    
    private func handleRealTimeError(_ error: Error) {
        debugLog("❌ Real-time subscription error: \(error)")
        // Reset subscription state so we can retry
        isSubscribedToRealTime = false
    }
    
    private func cancelRealTimeSubscription() {
        if isSubscribedToRealTime {
            instance.databaseService.cancelSubscription(forTabId: selectedTab.id)
            isSubscribedToRealTime = false
            debugLog("🛑 Cancelled real-time subscription for table: \(selectedTab.name)")
        }
    }
    
    private func updateFilterConditions() {
        // Check if tab filter properties have changed (indicates foreign key navigation)
        let tabFilterChanged = lastTabFilterColumn != selectedTab.filterColumn || 
                             lastTabFilterValue != selectedTab.filterValue
        
        if let filterColumn = selectedTab.filterColumn,
           let filterValue = selectedTab.filterValue {
            // Always update if tab filter has changed (foreign key navigation)
            // Otherwise, only update if we don't have manually added filters
            let hasManualFilters = filterConditions.count > 1 || 
                                 (filterConditions.count == 1 && !filterConditions[0].value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            
            if tabFilterChanged || !hasManualFilters {
                filterConditions = [FilterCondition(
                    conjunction: .whereClause,
                    field: filterColumn,
                    filterOperator: .equals,
                    value: filterValue
                )]
            }
        } else {
            // Only reset to default if we don't have manually added filters
            let hasManualFilters = filterConditions.count > 1 || 
                                 (filterConditions.count == 1 && !filterConditions[0].value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            
            if !hasManualFilters {
                filterConditions = [FilterCondition(conjunction: .whereClause, field: "", filterOperator: .equals, value: "")]
            }
        }
        
        // Update tracking variables
        lastTabFilterColumn = selectedTab.filterColumn
        lastTabFilterValue = selectedTab.filterValue
    }
    
    /// Unified loader: for real-time backends this subscribes; otherwise it fetches.
    private func loadOrSubscribe(forceFetch: Bool = false, fetchSchema: Bool = true, page: Int = 1, limit: Int = 300, filter: String? = nil) async {
        if instance.databaseService.supportsRealTime {
            // Update current filter and show loading if we're refetching
            currentActiveFilter = filter ?? currentActiveFilter
            if forceFetch || cachedDocuments == nil { await MainActor.run { viewState = .loading } }
            
            if fetchSchema && (cachedSchema == nil || cachedTabName != selectedTab.name) {
                do {
                    if let schema = try await instance.databaseService.getSchema(for: selectedTab.name, databaseSchema: selectedTab.databaseSchema) {
                        cachedSchema = schema
                    }
                } catch {
                    debugLog("Failed to fetch schema for \(selectedTab.name): \(error.localizedDescription)")
                }
            }
            cachedTabName = selectedTab.name
            cancelRealTimeSubscription()
            await subscribeToRealTimeUpdatesIfSupported(page: page)
            return
        }
        
        // Non real-time fallback: use existing fetcher
        await loadDocuments(forceFetch: forceFetch, fetchSchema: fetchSchema, page: page, limit: limit, filter: filter)
    }
    
    /// Load documents with options to force fetch and control schema fetching
    private func loadDocuments(forceFetch: Bool = false, fetchSchema: Bool = true, page: Int = 1, limit: Int = 300, filter: String? = nil) async {
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
            await MainActor.run {
                viewState = .loading
            }
            
            // Check if task was cancelled after setting loading state
            if Task.isCancelled { return }
            
            // Determine what to fetch
            let schemaToUse: DatabaseSchemaResult
            let documentsResult: QueryResult
            let databaseSchema = selectedTab.databaseSchema
            
            if fetchSchema && (cachedSchema == nil || cachedTabName != selectedTab.name) {
                // Fetch both schema and documents
                async let schemaTask = instance.databaseService.getSchema(for: selectedTab.name, databaseSchema: databaseSchema)
                async let documentsTask = instance.databaseService.findDocuments(
                    in: selectedTab.name,
                    databaseSchema: databaseSchema,
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
                
                let documents = try await instance.databaseService.findDocuments(
                    in: selectedTab.name,
                    databaseSchema: databaseSchema,
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
        await loadOrSubscribe(forceFetch: true, fetchSchema: true, page: 1, limit: 300, filter: currentActiveFilter)
    }
    
    /// Clear cache when needed (e.g., connection changes)
    func clearCache() {
        loadingTask?.cancel()
        cancelRealTimeSubscription()
        cachedSchema = nil
        cachedDocuments = nil
        cachedTabName = nil
        sortColumn = nil
        // Set default sort order based on database type
        sortAscending = instance.connection.databaseType == .convex ? false : true
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
