import AppKit
import SwiftUI

@Observable @MainActor
class TableDataController {

    let instance: ConnectionInstance
    let tab: DatabaseTab

    var viewState: TableListViewState = .loading
    var sortColumn: String?
    var sortAscending: Bool = true

    var cachedSchema: DatabaseSchemaResult?
    var cachedIndexes: [DatabaseIndexInfo]?
    var cachedDocuments: QueryResult?
    var cachedTabName: String?

    var loadingTask: Task<Void, Never>?

    var modificationTracker = TableModificationTracker()
    var schemaModificationTracker = SchemaModificationTracker()
    var isProcessingUpdates = false
    var isProcessingSchemaUpdates = false
    var needsToSelectLastRow = false

    var currentError: Error?
    var showingErrorAlert = false
    var showingViewStateError = false
    var viewStateErrorMessage = ""

    var filterConditions: [FilterCondition] = [FilterCondition(conjunction: .whereClause, field: "", filterOperator: .equals, value: "")]
    var currentActiveFilter: String?

    private var lastTabFilterColumn: String?
    private var lastTabFilterValue: String?

    var isSubscribedToRealTime = false
    var receivedFirstRealtimeEvent = false
    var skipNextRealtimeEvent = false
    var changeDetector = TableChangeDetector()
    var updatedFields: Set<String> = []
    var updatedRows: Set<Int> = []

    init(instance: ConnectionInstance, tab: DatabaseTab) {
        self.instance = instance
        self.tab = tab

        if instance.connection.databaseType == .convex {
            sortAscending = false
        }
    }

    func cancel() {
        loadingTask?.cancel()
        cancelRealTimeSubscription()
    }

    // MARK: - Computed Properties

    var currentQueryResult: QueryResult? {
        if case .loaded(let queryResult, _) = viewState {
            return queryResult
        }
        return cachedDocuments
    }

    var currentSchema: DatabaseSchemaResult? {
        if case .loaded(_, let schema) = viewState {
            return schema
        }
        return cachedSchema
    }

    // MARK: - Error Handling

    func showError(_ error: Error) {
        currentError = error
        showingErrorAlert = true
    }

    func handleViewStateChange() {
        if case .error(let message) = viewState {
            viewStateErrorMessage = message
            showingViewStateError = true
        }
    }

    private func forceViewStateRefresh(with result: QueryResult, schema: DatabaseSchemaResult) {
        viewState = .loading
        viewState = .loaded(result, schema)
    }

    // MARK: - Loading

    func loadDocumentsIfNeeded() async {
        let shouldFetch = cachedTabName != tab.name
            || cachedSchema == nil
            || cachedDocuments == nil
            || tab.forceFetch

        guard shouldFetch else {
            if let cachedDocuments, let cachedSchema {
                viewState = .loaded(cachedDocuments, cachedSchema)
            }
            if !isSubscribedToRealTime {
                await subscribeToRealTimeUpdatesIfSupported(page: 1)
            }
            return
        }

        if let databaseType = instance.databaseType {
            AnalyticsService.shared.trackTableViewed(databaseType: databaseType)
        }

        let initialFilter = generateInitialFilter()
        currentActiveFilter = initialFilter
        await loadOrSubscribe(forceFetch: true, fetchSchema: true, page: 1, limit: 300, filter: initialFilter)
        tab.forceFetch = false
    }

    func loadOrSubscribe(forceFetch: Bool = false, fetchSchema: Bool = true, page: Int = 1, limit: Int = 300, filter: String? = nil) async {
        if instance.databaseService.supportsRealTime {
            currentActiveFilter = filter ?? currentActiveFilter
            if forceFetch || cachedDocuments == nil { viewState = .loading }

            if fetchSchema && (forceFetch || cachedSchema == nil || cachedTabName != tab.name) {
                do {
                    if let schema = try await instance.databaseService.getSchema(for: tab.name, databaseSchema: tab.databaseSchema, forceFetch: forceFetch) {
                        cachedSchema = schema
                    }
                } catch {
                    debugLog("Failed to fetch schema for \(tab.name): \(error.localizedDescription)")
                }

                do {
                    if let indexes = try await instance.databaseService.getIndexes(for: tab.name, databaseSchema: tab.databaseSchema, forceFetch: forceFetch) {
                        cachedIndexes = indexes
                    }
                } catch {
                    debugLog("Failed to fetch indexes for \(tab.name): \(error.localizedDescription)")
                }
            }
            cachedTabName = tab.name
            cancelRealTimeSubscription()
            await subscribeToRealTimeUpdatesIfSupported(page: page)
            return
        }

        await loadDocuments(forceFetch: forceFetch, fetchSchema: fetchSchema, page: page, limit: limit, filter: filter)
    }

    func loadDocuments(forceFetch: Bool = false, fetchSchema: Bool = true, page: Int = 1, limit: Int = 300, filter: String? = nil) async {
        guard !Task.isCancelled else { return }

        if !forceFetch,
           cachedTabName == tab.name,
           let cachedDocuments,
           let cachedSchema {
            viewState = .loaded(cachedDocuments, cachedSchema)
            return
        }

        do {
            viewState = .loading

            guard !Task.isCancelled else { return }

            let schemaToUse: DatabaseSchemaResult
            let documentsResult: QueryResult
            let databaseSchema = tab.databaseSchema

            if fetchSchema && (forceFetch || cachedSchema == nil || cachedTabName != tab.name) {
                async let schemaTask = instance.databaseService.getSchema(for: tab.name, databaseSchema: databaseSchema, forceFetch: forceFetch)
                async let indexesTask = instance.databaseService.getIndexes(for: tab.name, databaseSchema: databaseSchema, forceFetch: forceFetch)
                async let documentsTask = instance.databaseService.findDocuments(
                    in: tab.name,
                    databaseSchema: databaseSchema,
                    filter: filter ?? "",
                    skip: (page - 1) * limit,
                    limit: limit,
                    sortBy: sortColumn,
                    ascending: sortAscending
                )

                let (schema, indexes, documents) = try await (schemaTask, indexesTask, documentsTask)

                guard !Task.isCancelled else { return }

                guard let schema else {
                    viewState = .error("Could not load schema")
                    return
                }

                schemaToUse = schema
                documentsResult = documents

                cachedSchema = schema
                cachedIndexes = indexes
            } else {
                guard let schema = cachedSchema else {
                    viewState = .error("No cached schema available")
                    return
                }

                let documents = try await instance.databaseService.findDocuments(
                    in: tab.name,
                    databaseSchema: databaseSchema,
                    filter: filter ?? "",
                    skip: (page - 1) * limit,
                    limit: limit,
                    sortBy: sortColumn,
                    ascending: sortAscending
                )

                guard !Task.isCancelled else { return }

                schemaToUse = schema
                documentsResult = documents
            }

            guard !Task.isCancelled else { return }

            cachedDocuments = documentsResult
            cachedTabName = tab.name

            updateTabSchemaDeviation(hasColumnMismatch(queryResult: documentsResult, schema: schemaToUse))

            viewState = .loaded(documentsResult, schemaToUse)
        } catch {
            debugLog(error.localizedDescription)
            viewState = .error(error.localizedDescription)
        }
    }

    func refreshData() async {
        await loadOrSubscribe(forceFetch: true, fetchSchema: true, page: 1, limit: 300, filter: currentActiveFilter)
    }

    func clearCache() {
        loadingTask?.cancel()
        cancelRealTimeSubscription()
        cachedSchema = nil
        cachedDocuments = nil
        cachedTabName = nil
        sortColumn = nil
        sortAscending = instance.connection.databaseType != .convex
        viewState = .loading
    }

    private func extractRowId(from row: [String: Any?], columns: [QueryColumnInfo]) -> Any? {
        if let idValue = row["_id"] ?? row["id"] {
            return idValue
        }
        guard let firstColumn = columns.first else { return nil }
        return row[firstColumn.name] as Any?
    }

    // MARK: - Schema Modifications

    func commitSchemaModifications() async {
        let validationErrors = schemaModificationTracker.validateModifications()
        guard validationErrors.isEmpty else {
            currentError = DatabaseError.operationFailed(validationErrors.joined(separator: "\n"))
            showingErrorAlert = true
            return
        }

        debugLog("💾 Saving \(schemaModificationTracker.totalModificationCount) schema modifications...")

        do {
            guard let driver = instance.databaseService.driver else {
                throw DatabaseError.operationFailed("No active database driver")
            }

            let service = SchemaModificationService(databaseDriver: driver)

            try await service.executeModifications(
                tableName: tab.name,
                schema: tab.databaseSchema,
                modifications: schemaModificationTracker
            )

            schemaModificationTracker.clearAll()

            await loadOrSubscribe(forceFetch: true, fetchSchema: true, page: 1, limit: 300, filter: currentActiveFilter)

            debugLog("✅ Schema modifications saved successfully")
        } catch {
            currentError = error
            showingErrorAlert = true
        }
    }

    // MARK: - Data Modifications

    func commitModifications() async {
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
                    try await instance.databaseService.createDocument(in: tab.name, databaseSchema: tab.databaseSchema, document: newDocument)
                    debugLog("✅ Inserted new row at index \(rowModification.rowIndex)")

                case .update:
                    guard let currentQueryResult,
                          rowModification.rowIndex < currentQueryResult.rawRows.count else {
                        debugLog("❌ Invalid row index: \(rowModification.rowIndex)")
                        continue
                    }

                    let originalRow = currentQueryResult.rawRows[rowModification.rowIndex]

                    var updateData: [String: Any] = [:]
                    for (columnName, cellMod) in rowModification.cellModifications where cellMod.hasChanged {
                        updateData[columnName] = cellMod.newValue
                    }

                    guard let id = extractRowId(from: originalRow, columns: currentQueryResult.columns) else {
                        debugLog("❌ Could not find row identifier for row \(rowModification.rowIndex)")
                        continue
                    }

                    try await instance.databaseService.updateDocument(
                        in: tab.name,
                        databaseSchema: tab.databaseSchema,
                        id: id,
                        data: updateData
                    )

                    debugLog("✅ Updated row \(rowModification.rowIndex) with \(updateData.count) changes")

                case .delete:
                    guard let currentQueryResult,
                          rowModification.rowIndex < currentQueryResult.rawRows.count else {
                        debugLog("❌ Invalid row index: \(rowModification.rowIndex)")
                        continue
                    }

                    let originalRow = currentQueryResult.rawRows[rowModification.rowIndex]

                    guard let id = extractRowId(from: originalRow, columns: currentQueryResult.columns) else {
                        debugLog("❌ Could not find row identifier for row \(rowModification.rowIndex)")
                        continue
                    }

                    try await instance.databaseService.deleteDocument(in: tab.name, databaseSchema: tab.databaseSchema, id: id)
                    debugLog("✅ Deleted row at index \(rowModification.rowIndex)")
                }
            } catch {
                showError(error)
                return
            }
        }

        modificationTracker.resetAllModifications()

        if !instance.databaseService.supportsRealTime {
            await loadDocuments(forceFetch: true, fetchSchema: false, page: 1, limit: 300, filter: currentActiveFilter)
        }

        debugLog("✅ All modifications saved successfully")
    }

    // MARK: - New Record

    func handleNewRecord() {
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

        let updatedResult = QueryResult(
            columns: queryColumns(from: schema),
            rows: updatedProcessedRows,
            totalCount: currentResult.totalCount + 1,
            rawRows: updatedRawRows
        )

        cachedDocuments = updatedResult

        if let cachedSchema {
            viewState = .loaded(updatedResult, cachedSchema)
        }

        needsToSelectLastRow = true
    }

    func handlePasteRows() {
        guard let schema = cachedSchema, let currentResult = cachedDocuments else { return }
        guard let clipboardString = NSPasteboard.general.string(forType: .string),
              !clipboardString.isEmpty else { return }

        let parsedRows = parseClipboardContent(clipboardString, schema: schema)
        guard !parsedRows.isEmpty else { return }

        var updatedRawRows = currentResult.rawRows
        var updatedProcessedRows = currentResult.rows

        for rowData in parsedRows {
            let newIndex = updatedRawRows.count

            var rawRow: [String: Any] = [:]
            var processedRow = [String: QueryRowInfo]()

            for column in schema.columns {
                let value = rowData[column.columnName].flatMap { $0 }

                if let value {
                    rawRow[column.columnName] = value
                }

                processedRow[column.columnName] = QueryRowInfo(
                    value: value,
                    dataType: column.dataType,
                    format: column.formatType
                )
            }

            modificationTracker.markAsNewRow(rowIndex: newIndex, initialData: rawRow)
            updatedRawRows.append(rawRow)
            updatedProcessedRows.append(processedRow)
        }

        let updatedResult = QueryResult(
            columns: queryColumns(from: schema),
            rows: updatedProcessedRows,
            totalCount: currentResult.totalCount + parsedRows.count,
            rawRows: updatedRawRows
        )

        cachedDocuments = updatedResult
        needsToSelectLastRow = true

        if let cachedSchema {
            forceViewStateRefresh(with: updatedResult, schema: cachedSchema)
        }

        debugLog("✅ Pasted \(parsedRows.count) row(s)")
    }

    // MARK: - Discard Changes

    func handleDiscardChanges() {
        needsToSelectLastRow = false

        guard let currentResult = cachedDocuments else {
            modificationTracker.resetAllModifications(of: .update, .insert)
            return
        }

        let insertIndices = modificationTracker.allModifications
            .filter { $0.type == .insert }
            .map { $0.rowIndex }
            .sorted(by: >)

        var updatedRawRows = currentResult.rawRows
        var updatedProcessedRows = currentResult.rows

        for index in insertIndices where index < updatedRawRows.count && index < updatedProcessedRows.count {
            updatedRawRows.remove(at: index)
            updatedProcessedRows.remove(at: index)
        }

        modificationTracker.resetAllModifications(of: .update, .insert)

        let updatedResult = QueryResult(
            columns: currentResult.columns,
            rows: updatedProcessedRows,
            totalCount: currentResult.totalCount - insertIndices.count,
            rawRows: updatedRawRows
        )

        cachedDocuments = updatedResult

        if let currentSchema = cachedSchema {
            forceViewStateRefresh(with: updatedResult, schema: currentSchema)
        }

        NotificationCenter.default.post(
            name: .tableReloadData,
            object: nil,
            userInfo: ["tableName": tab.name]
        )

        debugLog("✅ Discarded changes, removed \(insertIndices.count) inserted row(s)")
    }

    // MARK: - Delete / Undo Row

    private func removeRow(at index: Int) -> QueryResult? {
        guard let currentResult = cachedDocuments,
              currentResult.rawRows.indices.contains(index) else {
            return nil
        }

        var rawRows = currentResult.rawRows
        var processedRows = currentResult.rows
        rawRows.remove(at: index)
        processedRows.remove(at: index)

        let updatedResult = QueryResult(
            columns: currentResult.columns,
            rows: processedRows,
            totalCount: currentResult.totalCount - 1,
            rawRows: rawRows
        )

        cachedDocuments = updatedResult
        return updatedResult
    }

    func deleteNewlyAddedRecord(atIndex index: Int) {
        modificationTracker.deleteRow(rowIndex: index)

        guard let updatedResult = removeRow(at: index) else {
            debugLog("❌ Invalid index for deletion: \(index)")
            return
        }

        if let cachedSchema {
            viewState = .loaded(updatedResult, cachedSchema)
        }

        debugLog("✅ Deleted new record at index \(index)")
    }

    func undoRowInsert(atIndex index: Int) {
        guard let updatedResult = removeRow(at: index) else {
            debugLog("❌ Invalid index for undo row insert: \(index)")
            return
        }

        needsToSelectLastRow = false

        if let cachedSchema {
            forceViewStateRefresh(with: updatedResult, schema: cachedSchema)
        }

        NotificationCenter.default.post(
            name: .tableReloadData,
            object: nil,
            userInfo: ["tableName": tab.name]
        )

        debugLog("✅ Undid row insert at index \(index)")
    }

    // MARK: - New Field (Schema)

    func handleNewField() {
        let newColumn = DatabaseSchemaInfo(
            ordinalPosition: (cachedSchema?.columns.count ?? 0) + 1,
            columnName: generateUniqueColumnName(),
            dataType: "",
            formatType: "character varying",
            typeOid: 1043,
            isNullable: "YES",
            columnDefault: nil
        )

        schemaModificationTracker.trackColumnAddition(newColumn)

        NotificationCenter.default.post(
            name: .tableReloadData,
            object: nil,
            userInfo: ["autoEditLastRow": true]
        )
    }

    func generateUniqueColumnName() -> String {
        let existingNames = Set((cachedSchema?.columns ?? []).map { $0.columnName })
        var counter = 1
        var name = "new_column"
        while existingNames.contains(name) || schemaModificationTracker.isColumnNew(name) {
            name = "new_column_\(counter)"
            counter += 1
        }
        return name
    }

    // MARK: - Clipboard Parsing

    func parseClipboardContent(_ content: String, schema: DatabaseSchemaResult) -> [[String: Any?]] {
        if let jsonRows = parseJSONClipboard(content, schema: schema), !jsonRows.isEmpty {
            return jsonRows
        }
        return parseTSVClipboard(content, schema: schema)
    }

    private func parseJSONClipboard(_ content: String, schema: DatabaseSchemaResult) -> [[String: Any?]]? {
        guard let data = content.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) else {
            return nil
        }

        let jsonArray: [[String: Any]]
        if let array = json as? [[String: Any]] {
            jsonArray = array
        } else if let single = json as? [String: Any] {
            jsonArray = [single]
        } else {
            return nil
        }

        var result: [[String: Any?]] = []
        for jsonRow in jsonArray {
            var rowData: [String: Any?] = [:]
            for column in schema.columns {
                if let value = jsonRow[column.columnName], !(value is NSNull) {
                    rowData[column.columnName] = value
                } else {
                    rowData[column.columnName] = nil
                }
            }
            result.append(rowData)
        }
        return result
    }

    private func parseTSVClipboard(_ content: String, schema: DatabaseSchemaResult) -> [[String: Any?]] {
        let lines = content.components(separatedBy: .newlines).filter { !$0.isEmpty }
        guard !lines.isEmpty else { return [] }

        let columns = schema.columns
        var result: [[String: Any?]] = []

        for line in lines {
            let values = line.components(separatedBy: "\t")
            var rowData: [String: Any?] = [:]

            for (index, column) in columns.enumerated() {
                if index < values.count {
                    let value = values[index]
                    if value.isEmpty || value.uppercased() == "NULL" {
                        rowData[column.columnName] = nil
                    } else {
                        rowData[column.columnName] = value
                    }
                } else {
                    rowData[column.columnName] = nil
                }
            }
            result.append(rowData)
        }

        return result
    }

    // MARK: - Filter

    func updateFilterConditions() {
        let tabFilterChanged = lastTabFilterColumn != tab.filterColumn
            || lastTabFilterValue != tab.filterValue
        let hasManualFilters = filterConditions.count > 1
            || (filterConditions.count == 1 && !filterConditions[0].value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

        if let filterColumn = tab.filterColumn,
           let filterValue = tab.filterValue {
            if tabFilterChanged || !hasManualFilters {
                filterConditions = [FilterCondition(
                    conjunction: .whereClause,
                    field: filterColumn,
                    filterOperator: .equals,
                    value: filterValue
                )]
            }
        } else if !hasManualFilters {
            filterConditions = [FilterCondition(conjunction: .whereClause, field: "", filterOperator: .equals, value: "")]
        }

        lastTabFilterColumn = tab.filterColumn
        lastTabFilterValue = tab.filterValue
    }

    func generateInitialFilter() -> String? {
        guard let filterColumn = tab.filterColumn,
              let filterValue = tab.filterValue else {
            return nil
        }

        let conditions = [FilterCondition(
            conjunction: .whereClause,
            field: filterColumn,
            filterOperator: .equals,
            value: filterValue
        )]

        return instance.databaseService.generateFilterQuery(from: conditions, tableName: tab.name, databaseSchema: tab.databaseSchema)
    }

    // MARK: - Real-time Subscriptions

    func subscribeToRealTimeUpdatesIfSupported(page: Int = 1) async {
        guard instance.databaseService.supportsRealTime && !isSubscribedToRealTime else {
            return
        }

        do {
            try await instance.databaseService.subscribeToTableChanges(
                tabId: tab.id,
                tableName: tab.name,
                schema: tab.databaseSchema,
                filter: currentActiveFilter,
                limit: 300,
                sortBy: sortColumn,
                ascending: sortAscending,
                page: page,
                onUpdate: { [weak self] updatedResult in
                    Task { @MainActor in
                        self?.handleRealTimeUpdate(updatedResult)
                    }
                },
                onError: { [weak self] error in
                    Task { @MainActor in
                        self?.handleRealTimeError(error)
                    }
                }
            )
            isSubscribedToRealTime = true
            debugLog("✅ Subscribed to real-time updates for table: \(tab.name)")
        } catch {
            debugLog("❌ Failed to subscribe to real-time updates: \(error)")
        }
    }

    func handleRealTimeUpdate(_ updatedResult: QueryResult) {
        receivedFirstRealtimeEvent = true

        if skipNextRealtimeEvent {
            skipNextRealtimeEvent = false
            changeDetector.baseline(with: updatedResult)
            fetchSchemaIfNeeded()
            if let currentSchema = cachedSchema {
                forceViewStateRefresh(with: updatedResult, schema: currentSchema)
            }
            cachedDocuments = updatedResult
            return
        }

        let change: TableChangeDetector.ChangeResult
        if cachedDocuments == nil && changeDetector.lastHash == nil {
            changeDetector.baseline(with: updatedResult)
            change = .init(changedFields: [], changedRows: [], changedCells: [:], isDifferent: true)
        } else {
            let oldCount = cachedDocuments?.rawRows.count ?? 0
            let newCount = updatedResult.rawRows.count
            if oldCount != newCount {
                change = changeDetector.detectExclusive(old: cachedDocuments, new: updatedResult)
            } else {
                change = changeDetector.detect(old: cachedDocuments, new: updatedResult)
            }
        }

        guard change.isDifferent else {
            debugLog("📊 Real-time update skipped - no changes detected for table: \(tab.name)")
            return
        }

        fetchSchemaIfNeeded()

        var fields = Set<String>()
        var rows = Set<Int>()
        for (rowIndex, cols) in change.changedCells {
            rows.insert(rowIndex)
            fields.formUnion(cols)
        }
        updatedFields = fields
        updatedRows = rows

        if let currentSchema = cachedSchema {
            forceViewStateRefresh(with: updatedResult, schema: currentSchema)
        }

        cachedDocuments = updatedResult

        modificationTracker.reconcile(changedCells: change.changedCells, in: updatedResult)

        Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(500))
            self?.updatedFields.removeAll()
            self?.updatedRows.removeAll()
        }
    }

    private func fetchSchemaIfNeeded() {
        guard cachedSchema == nil else { return }
        Task {
            if let schema = try await instance.databaseService.getSchema(for: tab.name, databaseSchema: tab.databaseSchema) {
                await MainActor.run { self.cachedSchema = schema }
            }
        }
    }

    private func handleRealTimeError(_ error: Error) {
        debugLog("❌ Real-time subscription error: \(error)")
        isSubscribedToRealTime = false
    }

    func cancelRealTimeSubscription() {
        guard isSubscribedToRealTime else { return }
        instance.databaseService.cancelSubscription(forTabId: tab.id)
        isSubscribedToRealTime = false
        debugLog("🛑 Cancelled real-time subscription for table: \(tab.name)")
    }

    // MARK: - Helpers

    private func hasColumnMismatch(queryResult: QueryResult?, schema: DatabaseSchemaResult?) -> Bool {
        guard let queryResult, let schema, !queryResult.columns.isEmpty else {
            return false
        }
        let queryColumnNames = Set(queryResult.columns.map(\.name))
        let schemaColumnNames = Set(schema.columns.map(\.columnName))
        return queryColumnNames != schemaColumnNames
    }

    private func queryColumns(from schema: DatabaseSchemaResult) -> [QueryColumnInfo] {
        schema.columns.enumerated().map { index, column in
            QueryColumnInfo(
                name: column.columnName,
                dataType: column.dataType,
                format: column.formatType,
                index: index
            )
        }
    }

    private func updateTabSchemaDeviation(_ hasDeviation: Bool) {
        if let tabIndex = instance.tabs.firstIndex(where: { $0.id == tab.id }) {
            instance.tabs[tabIndex].hasSchemaDeviation = hasDeviation
        }
    }

    // MARK: - Notification Handling

    func handleMarkRowAsDeleted(rowIndex: Int, tableName: String) {
        guard tableName == tab.name else { return }

        modificationTracker.markAsDeleted(rowIndex: rowIndex)

        NotificationCenter.default.post(
            name: .tableReloadData,
            object: nil,
            userInfo: ["tableName": tableName]
        )
    }
}
