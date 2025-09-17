//
//  TableCoordinator.swift
//  Pluk
//
//  Created by Fauzaan on 7/10/25.
//

import Foundation
import AppKit
import Cocoa

class TableCoordinator: NSObject, NSTableViewDelegate, NSTableViewDataSource, TableModificationUndoDelegate, NSMenuDelegate {
    var rows: [[String: Any?]]
    var schema: DatabaseSchemaResult?
    var totalCount: Int
    var queryResult: QueryResult?
    
    private let containerView = NSView()
    private let scrollView = NSScrollView()
    let tableView = CustomTableView()
    
    private var columnWidthCache: [String: CGFloat] = [:]
    private var userModifiedWidths: [String: CGFloat] = [:]
    private var autoCalculatedColumns: Set<String> = []
//    private var lastDataHash: Int = 0
    private var knownColumns: Set<String> = []
    public var needsToSelectLastRow = false
    
    // Sorting state
    private var sortColumn: String? = nil
    private var sortAscending: Bool = true
    
    // Callback for database-level sorting
    var onSort: ((String, Bool) -> Void)?
    
    // Callback for deleting new rows
    var onDeleteNewRow: ((Int) -> Void)?
    
    // Callback for refreshing table data
    var onRefresh: (() -> Void)?
    
    // Callback for foreign key navigation
    var onForeignKeyNavigation: ((String, String, String) -> Void)? // (tableName, columnName, value)
    
    // Persistent storage
    public var tableName: String = ""
    private var currentSchemaSignature: String = ""
    private var isSettingWidthsProgrammatically = false
    
    private enum CellIdentifier {
        static let checkbox = NSUserInterfaceItemIdentifier("CheckboxCell")
        static let textCell = NSUserInterfaceItemIdentifier("TextCell")
        static let rowView = NSUserInterfaceItemIdentifier("CustomRowView")
        static let forignKeyCell = NSUserInterfaceItemIdentifier("ForeignKeyCell")
    }
    
    // Store modification tracker reference
    weak var modificationTracker: TableModificationTracker?
    
    // Menu item references for validation
    private weak var editMenuItem: NSMenuItem?
    private weak var deleteMenuItem: NSMenuItem?
    private weak var addRowMenuItem: NSMenuItem?
    private weak var refreshMenuItem: NSMenuItem?
    
    init(schema: DatabaseSchemaResult? = nil, queryResult: QueryResult?, tableName: String = "", onSort: ((String, Bool) -> Void)? = nil, modificationTracker: TableModificationTracker? = nil, onDeleteNewRow: ((Int) -> Void)? = nil, onRefresh: (() -> Void)? = nil, onForeignKeyNavigation: ((String, String, String) -> Void)? = nil) {
        self.schema = schema
        self.queryResult = queryResult
        self.tableName = tableName
        self.onSort = onSort
        self.modificationTracker = modificationTracker
        self.onDeleteNewRow = onDeleteNewRow
        self.onRefresh = onRefresh
        self.onForeignKeyNavigation = onForeignKeyNavigation
        
        if let queryResult = queryResult {
            self.rows = queryResult.rawRows
            self.totalCount = queryResult.totalCount
        } else {
            self.rows = []
            self.totalCount = 0
        }
        
        super.init()
        
        // Set up undo delegate
        self.modificationTracker?.undoDelegate = self
        
        NotificationCenter.default.addObserver(self, selector: #selector(handleDeleteKey(notification:)), name: .didRequestDelete, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(handleForeignKeyNavigation(notification:)), name: .foreignKeyNavigationRequested, object: nil)
    }
    
    @objc private func handleDeleteKey(notification: Notification) {
        guard let userInfo = notification.userInfo,
              let rows = userInfo["rows"] as? IndexSet,
              let notificationTableView = userInfo["tableView"] as? CustomTableView,
              notificationTableView === self.tableView else {
            return
        }
        
        for row in rows {
            if let rowModification = modificationTracker?.getRowModification(for: row),
               rowModification.type == .insert {
                onDeleteNewRow?(rowModification.rowIndex)
            } else {
                modificationTracker?.markAsDeleted(rowIndex: row)
            }
        }
        
        // Force all cells in the affected rows to update their appearance
        for row in rows {
            for columnIndex in 0..<tableView.numberOfColumns {
                if let cellView = tableView.view(atColumn: columnIndex, row: row, makeIfNecessary: false) as? TextCellView {
                    // Directly update the cell's deletion state
                    cellView.isMarkedForDeletion = true
                    cellView.needsDisplay = true
                }
            }
        }
        
        // Also reload the rows to ensure proper state
        tableView.reloadData(forRowIndexes: rows, columnIndexes: IndexSet(integersIn: 0..<tableView.numberOfColumns))
    }
    
    @objc private func handleForeignKeyNavigation(notification: Notification) {
        guard let userInfo = notification.userInfo,
              let constraintInfo = userInfo["constraintInfo"] as? ConstraintInfo,
              let currentValue = userInfo["currentValue"] as? String,
              let referencedTable = userInfo["referencedTable"] as? String else {
            debugLog("❌ Invalid foreign key navigation notification data")
            return
        }
        
        debugLog("🔗 Handling foreign key navigation to table: \(referencedTable) with value: \(currentValue)")
        
        guard let referencedColumn = constraintInfo.referencedColumns?.first else {
            return
        }
        
        // Call the foreign key navigation callback with table name, referenced column, and current value
        onForeignKeyNavigation?(referencedTable, referencedColumn, currentValue)
    }

    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    // MARK: - TableModificationUndoDelegate
    func willUndoModification(rowIndex: Int, columnName: String, fromValue: String, toValue: String) {
        debugLog("🔄 Will undo modification: Row \(rowIndex), Column \(columnName), \(fromValue) → \(toValue)")
    }
    
    func didUndoModification(rowIndex: Int, columnName: String, newValue: String) {
        debugLog("✅ Did undo modification: Row \(rowIndex), Column \(columnName) → \(newValue)")
        
        // Update the UI to reflect the undo
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            // Find the cell view and update its value
            if let cellView = self.findCellView(rowIndex: rowIndex, columnName: columnName) {
                debugLog("🔍 Updating cell view for undo - Row: \(rowIndex), Column: \(columnName), New Value: '\(newValue)'")
                cellView.resetModificationState()
                
                // Force a refresh of the cell's appearance
                cellView.needsDisplay = true
                cellView.needsLayout = true
            } else {
                debugLog("⚠️ Could not find cell view for Row: \(rowIndex), Column: \(columnName)")
            }
            
            // Note: We might not need to reload the entire row since we're updating the cell directly
            // But keep it as a fallback for now
            if rowIndex < self.tableView.numberOfRows {
                let rowIndexSet = IndexSet(integer: rowIndex)
                self.tableView.reloadData(forRowIndexes: rowIndexSet, columnIndexes: IndexSet(integersIn: 0..<self.tableView.numberOfColumns))
            }
        }
    }
    
    private func findCellView(rowIndex: Int, columnName: String) -> TextCellView? {
        guard rowIndex < tableView.numberOfRows else { return nil }
        
        for columnIndex in 0..<tableView.numberOfColumns {
            let column = tableView.tableColumns[columnIndex]
            if column.identifier.rawValue == columnName {
                return tableView.view(atColumn: columnIndex, row: rowIndex, makeIfNecessary: false) as? TextCellView
            }
        }
        return nil
    }
    
    @objc private func handleUndo() -> Bool {
        guard let modificationTracker = modificationTracker else { return false }
        return modificationTracker.undo()
    }
    
    
    func setupTableView() -> NSView {
        setupUI()
        setupTable()
        return containerView
    }
    
    func updateRows(_ newQueryResult: QueryResult?, newSchema: DatabaseSchemaResult? = nil) {
        // Get the current selection BEFORE updating the data
        let previousSelectedRow = self.tableView.getCurrentSelectedCell()?.row
        
        let oldRowCount = self.totalCount
        
        // Calculate old column count (prioritize QueryResult columns over schema)
        let oldColumnCount: Int
        if let currentQueryResult = self.queryResult, !currentQueryResult.columns.isEmpty {
            oldColumnCount = currentQueryResult.columns.count
        } else {
            oldColumnCount = self.schema?.columns.count ?? 0
        }
        
        debugLog("oldRowCount: \(oldRowCount), oldColumnCount: \(oldColumnCount)")
        
        // Check if data has significantly changed for cache invalidation
//        let oldDataHash = self.lastDataHash
//        let newDataHash = calculateDataHash(queryResult: newQueryResult, schema: newSchema)
        
        // Update ALL references
        self.queryResult = newQueryResult
        self.schema = newSchema
//        self.lastDataHash = newDataHash
        
        if let newQueryResult = newQueryResult {
            self.rows = newQueryResult.rawRows
            self.totalCount = newQueryResult.totalCount
        } else {
            self.rows = []
            self.totalCount = 0
        }
        
        // Calculate new column count (prioritize QueryResult columns over schema)
        let newColumnCount: Int
        if let newQueryResult = newQueryResult, !newQueryResult.columns.isEmpty {
            newColumnCount = newQueryResult.columns.count
        } else {
            newColumnCount = newSchema?.columns.count ?? 0
        }
        
        // Invalidate column width cache if data changed significantly
        // FIX: Instead of revalidating all columns only revalidate the new column:
        // if oldDataHash != newDataHash {
        //    invalidateColumnWidthCache()
        // }
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            // Validate previous selection
            if let previousSelectedRow = previousSelectedRow {
                if previousSelectedRow >= self.totalCount {
                    // The previously selected row no longer exists. Clear selection.
                    debugLog("🔄 Previously selected row \(previousSelectedRow) is out of bounds (new count: \(self.totalCount)). Clearing selection.")
                    self.tableView.clearAllSelection()
                }
            }
            
            // Check if table structure changed (columns added/removed/changed)
            if newColumnCount != oldColumnCount {
                self.rebuildTableStructure()
            } else {
                self.tableView.reloadData()
            }
            
            if self.needsToSelectLastRow {
                self.scrollToBottomAndSelectFirstCell()
            }
            
            // Recalculate column widths if data changed significantly
            if let queryResult = self.queryResult {
                self.recalculateColumnWidthsIfNeeded(queryResult: queryResult)
            }
        }
    }
    
    func tableView(_ tableView: NSTableView, sortDescriptorsDidChange oldDescriptors: [NSSortDescriptor]) {
        // Get the first (primary) sort descriptor
        guard let sortDescriptor = tableView.sortDescriptors.first else { return }
        
        // Find the column whose sortDescriptorPrototype matches
        for column in tableView.tableColumns {
            if let prototype = column.sortDescriptorPrototype,
               prototype.key == sortDescriptor.key {
                let columnTitle = column.title
                debugLog("✅ Received sort notification for column: \(columnTitle)")
                sortTableData(by: columnTitle)
                break
            }
        }
    }
    
    
    private func sortTableData(by columnTitle: String) {
        // 3-state sorting: ascending → descending → none
        if sortColumn == columnTitle {
            if sortAscending {
                // Current: ascending → Next: descending
                sortAscending = false
                debugLog("🔽 Sorting \(columnTitle) DESCENDING")
            } else {
                // Current: descending → Next: none (reset sort)
                sortColumn = nil
                sortAscending = true // Reset to default for next time
                debugLog("🚫 Clearing sort for \(columnTitle)")
            }
        } else {
            // Different column clicked → Start with ascending
            sortColumn = columnTitle
            sortAscending = true
            debugLog("🔼 Sorting \(columnTitle) ASCENDING")
        }
        // Update table headers to show sort indicators
        updateTableHeaders()
        
        // Trigger database-level sorting via callback
        if let sortColumn = sortColumn {
            onSort?(sortColumn, sortAscending)
        } else {
            // No sorting - pass empty string or special value to indicate no sort
            onSort?("", true) // You might want to modify the callback signature to handle this better
        }
    }
    
    private func updateTableHeaders() {
        for tableColumn in tableView.tableColumns {
            let columnId = tableColumn.identifier.rawValue
            if let headerCell = tableColumn.headerCell as? CustomTableHeaderCell {
                let isCurrentSortColumn = (sortColumn == columnId)
                headerCell.updateSortIndicator(isActive: isCurrentSortColumn, ascending: sortAscending)
            }
        }
    }
    
    // Public method to set sorting state from parent view
    func setSortState(column: String?, ascending: Bool) {
        sortColumn = column
        sortAscending = ascending
        updateTableHeaders()
    }
    
    func scrollToBottomAndSelectFirstCell() {
        DispatchQueue.main.async {
            self.needsToSelectLastRow = false
            let numberOfRows = self.tableView.numberOfRows
            if numberOfRows > 0 {
                let lastRowIndex = numberOfRows - 1
                self.tableView.scrollRowToVisible(lastRowIndex)
                
                // Select the first cell of the last row
                let firstColumnIndex = 0 // Assuming there's always at least one column
                if self.tableView.numberOfColumns > firstColumnIndex {
                    // Make the table view the first responder to show the selection and allow editing
                    self.tableView.window?.makeFirstResponder(self.tableView)
                    // Start editing the cell
                    self.tableView.editColumn(firstColumnIndex, row: lastRowIndex, with: nil, select: true)
                    self.tableView.selectCell(row: lastRowIndex, column: firstColumnIndex)
                }
            }
        }
    }
    
    private func createColumn(identifier: String, title: String, dataType: String?, icon: NSImage?) {
        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier(identifier))
        column.title = title
        
        // Set flag to prevent resize notifications during programmatic setup
        isSettingWidthsProgrammatically = true
        
        // Priority: User modified width > Auto-calculated width > Default
        if let userWidth = userModifiedWidths[identifier] {
            // Always respect user's manual resize
            debugLog("📏 Using user-modified width for '\(identifier)': \(userWidth)")
            column.width = userWidth
            column.minWidth = 10 // Allow user flexibility
            column.maxWidth = CGFloat.greatestFiniteMagnitude
        } else if let cachedWidth = columnWidthCache[identifier] {
            // Use auto-calculated width
            debugLog("📏 Using auto-calculated width for '\(identifier)': \(cachedWidth)")
            column.width = cachedWidth
            column.minWidth = 10 // Allow user flexibility
            column.maxWidth = CGFloat.greatestFiniteMagnitude
        } else {
            // Fallback to default sizing
            debugLog("📏 Using default sizing for '\(identifier)'")
            column.sizeToFit()
        }
        
        //             Add custom header
        let customHeaderCell = CustomTableHeaderCell(textCell: identifier)
        customHeaderCell.configure(title: title, fieldType: dataType)
        column.headerCell = customHeaderCell
        
        let sortDescriptor = NSSortDescriptor(key: column.title, ascending: true, selector: #selector(NSString.localizedCaseInsensitiveCompare(_:)))
        column.sortDescriptorPrototype = sortDescriptor
        
        tableView.addTableColumn(column)
        
        tableView.target = self
        tableView.doubleAction = #selector(tableViewDoubleClick(_:))
        
        // Reset flag after adding column
        isSettingWidthsProgrammatically = false
    }
    
    @objc func tableViewDoubleClick(_ sender:AnyObject) {
        if let cellLocation = tableView.getCurrentSelectedCell() {
            tableView.enterEditModeForCell(row: cellLocation.row, column: cellLocation.column)
        }
    }
    
    private func setupUI() {
        containerView.wantsLayer = true
        
        // Scroll view setup
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder
        scrollView.drawsBackground = false
        scrollView.backgroundColor = NSColor.clear
        
        scrollView.documentView = tableView
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        
        // FIXED: Use scrollerInsets to keep scrollbars at screen edges
        // while contentInsets provides the content padding
        scrollView.automaticallyAdjustsContentInsets = false
        scrollView.contentInsets = NSEdgeInsets(top: 0, left: 0, bottom: 100, right: 0)
        scrollView.scrollerInsets = NSEdgeInsets(top: 0, left: 0, bottom: -100, right: 0)
        
        containerView.addSubview(scrollView)
        
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: containerView.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor)
        ])
    }
    
    private func setupTable() {
        // Use QueryResult columns if available (for raw queries), otherwise fall back to schema
        let columnsToUse: [(name: String, dataType: String?)]
        
        if let queryResult = queryResult, !queryResult.columns.isEmpty {
            // Use columns from QueryResult (handles raw queries with different column structure)
            columnsToUse = queryResult.columns.map { ($0.name, $0.dataType) }
        } else if let schema = schema {
            // Fall back to schema columns for standard table queries
            columnsToUse = schema.columns.map { ($0.columnName, $0.dataType) }
        } else {
            // No columns available
            return
        }
        
        // Generate schema signature for this table
        let newSchemaSignature = generateSchemaSignature(columns: columnsToUse)
        
        // Check if we have a cached schema for this table
        let persistentSchema = loadPersistentSchema(for: tableName)
        
        if let cachedSchema = persistentSchema,
           cachedSchema.schemaSignature == newSchemaSignature {
            // Schema matches - restore cached widths and order
            restoreCachedColumnConfiguration(cachedSchema, columnsToUse: columnsToUse)
        } else {
            // Schema changed or first time - calculate optimal widths
            if let queryResult = queryResult {
                preCalculateOptimalColumnWidths(for: columnsToUse, queryResult: queryResult)
            }
            
            // Create and save new schema cache
            let newCachedSchema = createSchemaCache(signature: newSchemaSignature, columns: columnsToUse)
            savePersistentSchema(newCachedSchema, for: tableName)
        }
        
        currentSchemaSignature = newSchemaSignature
        
        // Create columns with appropriate widths and order
        let orderedColumns = getOrderedColumns(columnsToUse)
        for columnInfo in orderedColumns {
            createColumn(
                identifier: columnInfo.name,
                title: columnInfo.name,
                dataType: columnInfo.dataType,
                icon: nil
            )
        }
        
        // Enable column resizing
        tableView.allowsColumnResizing = true
        tableView.allowsColumnReordering = true
        tableView.columnAutoresizingStyle = .noColumnAutoresizing
        
        // Enable column selection only
        tableView.allowsColumnSelection = true
        tableView.allowsMultipleSelection = true
        tableView.allowsEmptySelection = true
        
        // Set data source and delegate
        tableView.dataSource = self
        tableView.delegate = self
        
        // Set up undo handler for keyboard shortcuts
        tableView.undoHandler = { [weak self] in
            return self?.handleUndo() ?? false
        }
        
        /// Setup right click:
        let menu = NSMenu()
        
        // Refresh menu item
        let refreshItem = NSMenuItem(title: "Refresh", action: #selector(refreshCurrentTable), keyEquivalent: "r")
        refreshItem.keyEquivalentModifierMask = [.command]
        refreshItem.target = self
        menu.addItem(refreshItem)
        self.refreshMenuItem = refreshItem
        
        // Separator
        menu.addItem(NSMenuItem.separator())
        
        // Add row menu item
        let addRowItem = NSMenuItem(title: "Add Row", action: #selector(addRow), keyEquivalent: "i")
        addRowItem.keyEquivalentModifierMask = [.command]
        addRowItem.target = self
        menu.addItem(addRowItem)
        self.addRowMenuItem = addRowItem
        
        // Edit menu item
        let editItem = NSMenuItem(title: "Edit", action: #selector(editItem), keyEquivalent: "\r")
        editItem.target = self
        menu.addItem(editItem)
        self.editMenuItem = editItem
        
        // Separator
        menu.addItem(NSMenuItem.separator())
        
        // Delete menu item
        let deleteItem = NSMenuItem(title: "Delete", action: #selector(deleteItem), keyEquivalent: "\u{8}")
        deleteItem.keyEquivalentModifierMask = []
        deleteItem.target = self
        menu.addItem(deleteItem)
        self.deleteMenuItem = deleteItem
        
        menu.delegate = self
        menu.autoenablesItems = false
        tableView.menu = menu
        
        // Set up column resize and reorder notifications
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(columnDidResize(_:)),
            name: NSTableView.columnDidResizeNotification,
            object: tableView
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(columnDidMove(_:)),
            name: NSTableView.columnDidMoveNotification,
            object: tableView
        )
        
        tableView.rowSizeStyle = .custom
        
        // Table view setup
        tableView.style = .plain
        tableView.backgroundColor = NSColor.clear
        tableView.usesAutomaticRowHeights = false
        
        // Remove intercell spacing to eliminate padding between columns
        tableView.intercellSpacing = NSSize(width: 0, height: 0)
        
        // Create custom header view
        let customHeaderView = CustomTableHeaderView(frame: NSRect(x: 0, y: 0, width: tableView.bounds.width, height: 32))

        let visualEffectView = NSVisualEffectView()
        visualEffectView.frame = customHeaderView.bounds
        visualEffectView.material = .contentBackground
        visualEffectView.blendingMode = .withinWindow
        visualEffectView.state = .active
        visualEffectView.autoresizingMask = [.width, .height]

        visualEffectView.wantsLayer = true
        visualEffectView.layer?.zPosition = -1000

        customHeaderView.addSubview(visualEffectView)

        tableView.headerView = customHeaderView
    }
    
    
    private func rebuildTableStructure() {
        // When rebuilding, preserve user modifications but clear auto-calculated cache
        columnWidthCache.removeAll()
        autoCalculatedColumns.removeAll()
        knownColumns.removeAll()
        
        // Remove all existing columns
        while tableView.tableColumns.count > 0 {
            tableView.removeTableColumn(tableView.tableColumns[0])
        }
        
        // Rebuild columns based on current data
        setupTable()
        
        // Reload all data
        tableView.reloadData()
    }
    
    private func calculateDataHash(queryResult: QueryResult?, schema: DatabaseSchemaResult?) -> Int {
        var hasher = Hasher()
        
        // Hash basic properties
        hasher.combine(queryResult?.totalCount ?? 0)
        hasher.combine(queryResult?.columns.count ?? 0)
        hasher.combine(schema?.columns.count ?? 0)
        
        // Hash column names for structure changes
        if let columns = queryResult?.columns {
            for column in columns {
                hasher.combine(column.name)
                hasher.combine(column.dataType)
            }
        } else if let schemaColumns = schema?.columns {
            for column in schemaColumns {
                hasher.combine(column.columnName)
                hasher.combine(column.dataType)
            }
        }
        
        return hasher.finalize()
    }
    
    private func invalidateColumnWidthCache() {
        columnWidthCache.removeAll()
    }
    
    private func preCalculateOptimalColumnWidths(for columnsToUse: [(name: String, dataType: String?)], queryResult: QueryResult) {
        // Pre-computed font attributes for performance
        let headerFont = NSFont.systemFont(ofSize: 12, weight: .medium)
        let contentFont = NSFont.systemFont(ofSize: 12)
        let headerAttributes = [NSAttributedString.Key.font: headerFont]
        let contentAttributes = [NSAttributedString.Key.font: contentFont]
        
        // Calculate optimal width for each column (only if not user-modified)
        for columnInfo in columnsToUse {
            let columnIdentifier = columnInfo.name
            
            // Skip if user has manually resized this column
            if userModifiedWidths[columnIdentifier] != nil {
                continue
            }
            
            // Skip if already auto-calculated and not a new column
            if autoCalculatedColumns.contains(columnIdentifier) && columnWidthCache[columnIdentifier] != nil {
                continue
            }
            
            // Calculate header width
            let headerWidth = (columnInfo.name as NSString).size(withAttributes: headerAttributes).width + 45
            
            // Smart sampling for content width
            let sampleSize = determineSampleSize(totalRows: self.totalCount)
            let sampleIndices = generateSampleIndices(totalRows: self.totalCount, sampleSize: sampleSize)
            
            var maxContentWidth: CGFloat = 0
            
            // Efficiently calculate max content width
            for rowIndex in sampleIndices {
                if let value = queryResult.value(row: rowIndex, column: columnIdentifier) {
                    let contentString = formatValueForWidthCalculation(value.value)
                    
                    // Quick estimation first
                    if contentString.count > 300 {
                        maxContentWidth = 400
                    } else {
                        // Accurate measurement for shorter strings
                        let contentWidth = (contentString as NSString).size(withAttributes: contentAttributes).width + 30
                        maxContentWidth = max(maxContentWidth, contentWidth)
                    }
                }
            }
            
            debugLog("\(columnsToUse): \(maxContentWidth): headerWidth: \(headerWidth): optimalWidth: \(maxContentWidth)")
            let optimalWidth = max(headerWidth, maxContentWidth)
            
            // Cache the result and mark as auto-calculated
            columnWidthCache[columnIdentifier] = optimalWidth
            autoCalculatedColumns.insert(columnIdentifier)
        }
    }
    
    private func recalculateColumnWidthsIfNeeded(queryResult: QueryResult) {
        // Get current columns
        let columnsToProcess: [(name: String, dataType: String?)]
        if !queryResult.columns.isEmpty {
            columnsToProcess = queryResult.columns.map { ($0.name, $0.dataType) }
        } else if let schema = schema {
            columnsToProcess = schema.columns.map { ($0.columnName, $0.dataType) }
        } else {
            return
        }
        
        // Only recalculate for new columns, not existing ones
        let currentColumnNames = Set(columnsToProcess.map { $0.name })
        let newColumns = currentColumnNames.subtracting(knownColumns)
        
        if !newColumns.isEmpty {
            let newColumnsToProcess = columnsToProcess.filter { newColumns.contains($0.name) }
            preCalculateOptimalColumnWidths(for: newColumnsToProcess, queryResult: queryResult)
            
            // Apply new widths only to new columns
            isSettingWidthsProgrammatically = true
            for tableColumn in tableView.tableColumns {
                let columnId = tableColumn.identifier.rawValue
                if newColumns.contains(columnId), let newWidth = columnWidthCache[columnId] {
                    tableColumn.width = newWidth
                    tableColumn.minWidth = 10
                    tableColumn.maxWidth = CGFloat.greatestFiniteMagnitude
                }
            }
            isSettingWidthsProgrammatically = false
            
            // Update known columns
            knownColumns = currentColumnNames
        }
    }
    
    // MARK: - NSTableViewDataSource
    func numberOfRows(in tableView: NSTableView) -> Int {
        return self.totalCount
    }
    
    
    @objc private func columnDidResize(_ notification: Notification) {
        guard let _ = notification.object as? NSTableView,
              let userInfo = notification.userInfo,
              let column = userInfo["NSTableColumn"] as? NSTableColumn else {
            return
        }
        
        // Ignore programmatic width changes during setup
        guard !isSettingWidthsProgrammatically else {
            return
        }
        
        let columnIdentifier = column.identifier.rawValue
        let newWidth = column.width
        
        // Store user's manual resize - this takes precedence over auto-calculation
        userModifiedWidths[columnIdentifier] = newWidth
        columnWidthCache[columnIdentifier] = newWidth
        
        // Remove from auto-calculated set since user has now manually set it
        autoCalculatedColumns.remove(columnIdentifier)
        
        // Update persistent cache immediately
        updatePersistentColumnWidth(columnIdentifier, width: newWidth)
        
        debugLog("Column '\(columnIdentifier)' manually resized to width: \(newWidth)")
    }
    
    // Row view recycling
    func tableView(_ tableView: NSTableView, rowViewForRow row: Int) -> NSTableRowView? {
        // Try to reuse existing row view
        var rowView = tableView.makeView(withIdentifier: CellIdentifier.rowView, owner: self) as? CustomTableRowView
        
        if rowView == nil {
            // Create new row view if none available for reuse
            rowView = CustomTableRowView()
            rowView?.identifier = CellIdentifier.rowView
        }
        
        return rowView
    }
    
    func tableView(_ tableView: NSTableView, sizeToFitWidthOfColumn column: Int) -> CGFloat {
        guard let tableColumn = tableView.tableColumns[safe: column] else {
            return 100 // Default width
        }
        
        let columnIdentifier = tableColumn.identifier.rawValue
        
        // Return cached width (should already be calculated)
        if let cachedWidth = columnWidthCache[columnIdentifier] {
            return cachedWidth
        }
        
        // Fallback: basic calculation if cache miss
        let headerFont = NSFont.systemFont(ofSize: 12, weight: .medium)
        let headerAttributes = [NSAttributedString.Key.font: headerFont]
        let headerWidth = (tableColumn.title as NSString).size(withAttributes: headerAttributes).width + 50
        
        return max(100, headerWidth) // Minimum reasonable width
    }
    
    // Moved calculation logic to preCalculateOptimalColumnWidths method
    
    private func determineSampleSize(totalRows: Int) -> Int {
        switch totalRows {
        case 0...50:
            return totalRows // Sample all for small datasets
        case 51...500:
            return min(50, totalRows) // Sample up to 50 for medium datasets
        case 501...5000:
            return min(100, totalRows) // Sample up to 100 for large datasets
        default:
            return min(200, totalRows) // Sample up to 200 for very large datasets
        }
    }
    
    private func generateSampleIndices(totalRows: Int, sampleSize: Int) -> [Int] {
        guard totalRows > sampleSize else {
            return Array(0..<totalRows)
        }
        
        var indices: Set<Int> = []
        
        // Always include first few rows
        for i in 0..<min(5, sampleSize / 4, totalRows) {
            indices.insert(i)
        }
        
        // Always include last few rows
        for i in max(0, totalRows - min(5, sampleSize / 4))..<totalRows {
            indices.insert(i)
        }
        
        // Add random sampling for the middle
        let remainingSamples = sampleSize - indices.count
        let middleStart = min(5, sampleSize / 4)
        let middleEnd = max(0, totalRows - min(5, sampleSize / 4))
        
        for _ in 0..<remainingSamples {
            if middleStart < middleEnd {
                let randomIndex = Int.random(in: middleStart..<middleEnd)
                indices.insert(randomIndex)
            }
        }
        
        return Array(indices).sorted()
    }
    
    private func formatValueForWidthCalculation(_ value: Any?) -> String {
        guard let value = value else { return "(NULL)" }
        
        if let stringValue = value as? String {
            // 50-100 chars is usually enough for width calculation
            return stringValue.count > 50 ? String(stringValue.prefix(50)) + "..." : stringValue
        }
        
        return String(describing: value)
    }
    
    private func estimateWidth(_ text: String, font: NSFont) -> CGFloat {
        let avgCharWidth = font.maximumAdvancement.width * 0.6 // rough estimate
        return CGFloat(text.count) * avgCharWidth + 24
    }
    
    private func calculateMaxReasonableWidth() -> CGFloat {
        // Base max width on screen/table size
        let screenWidth = NSScreen.main?.frame.width ?? 1920
        let tableWidth = tableView.frame.width > 0 ? tableView.frame.width : screenWidth * 0.8
        
        // Don't let any single column take more than 1/3 of the table width
        return min(400, tableWidth / 3)
    }
    
    
    func tableView(_ tableView: NSTableView, heightOfRow row: Int) -> CGFloat {
        return 28
    }
    
    // MARK: - NSTableViewDelegate
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard let tableColumn = tableColumn,
              let queryResult = queryResult else {
            return nil
        }
        
        let columnName = tableColumn.identifier.rawValue
        guard let queryRowInfo = queryResult.value(row: row, column: columnName) else {
            return nil
        }

        guard let columnInfo = queryResult.column(named: columnName) else {
            return nil
        }
        
        // Determine cell type based on data type
        let cellIdentifier = getCellIdentifier(for: columnInfo.dataType)
        
        var cellView = tableView.makeView(withIdentifier: cellIdentifier, owner: self) as? TextCellView
        
        if cellView == nil {
            cellView = createCellView(for: columnInfo.dataType)
            cellView?.identifier = cellIdentifier
        } else {
            cellView?.prepareForReuse()
        }
        
        // Get foreign key constraint info from schema if available
        let foreignKeyConstraint = schema?.column(named: columnName)?.constraints.first { $0.type == .foreignKey }
        
        cellView?.configure(queryRowInfo: queryRowInfo,
                            columnInfo: columnInfo,
                            rowIndex: row,
                            modificationTracker: modificationTracker,
                            constraintInfo: foreignKeyConstraint,
                            tableName: tableName)
        
        return cellView
    }
    
    private func getCellIdentifier(for dataType: String) -> NSUserInterfaceItemIdentifier {
        switch dataType {
        case "text":
            return CellIdentifier.textCell
        case "interger":
            return CellIdentifier.textCell
            //            case .datetime, .timestamp:
            //                return CellIdentifier.dateCell
            //            case .boolean:
            //                return CellIdentifier.booleanCell
        default:
            return CellIdentifier.textCell
        }
    }
    
    
    private func createCellView(for dataType: String) -> TextCellView {
        switch dataType {
        case "text":
            return TextCellView()
        case "interger":
            return TextCellView()
            //            case .datetime, .timestamp:
            //                return DateCellView()
            //            case .boolean:
            //                return BooleanCellView()
        default:
            return TextCellView()
        }
    }
    
    
    @objc private func columnDidMove(_ notification: Notification) {
        // Update persistent cache with new column order
        saveCurrentColumnOrder()
        debugLog("Column order changed - updating persistent cache")
    }
    
    // MARK: - Persistent Storage Methods
    
    private struct PersistentColumnSchema: Codable {
        let schemaSignature: String
        let columnWidths: [String: CGFloat]
        let columnOrder: [String]
        let lastModified: Date
    }
    
    private func generateSchemaSignature(columns: [(name: String, dataType: String?)]) -> String {
        // Create a signature based on column names and types
        let signature = columns.map { "\($0.name):\($0.dataType ?? "unknown")" }.joined(separator: "|")
        return signature.data(using: .utf8)?.base64EncodedString() ?? ""
    }
    
    private func loadPersistentSchema(for tableName: String) -> PersistentColumnSchema? {
        let key = "TableColumnSchema_\(tableName)"
        guard let data = UserDefaults.standard.data(forKey: key) else {
            return nil
        }
        
        do {
            let decoder = Foundation.JSONDecoder()
            let persistentSchema = try decoder.decode(PersistentColumnSchema.self, from: data)
            return persistentSchema
        } catch {
            debugLog("Failed to decode persistent schema for table '\(tableName)': \(error)")
            return nil
        }
    }
    
    private func savePersistentSchema(_ schema: PersistentColumnSchema, for tableName: String) {
        let key = "TableColumnSchema_\(tableName)"
        if let data = try? JSONEncoder().encode(schema) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }
    
    private func createSchemaCache(signature: String, columns: [(name: String, dataType: String?)]) -> PersistentColumnSchema {
        let widths = columnWidthCache.isEmpty ? [:] : columnWidthCache
        let order = columns.map { $0.name }
        
        return PersistentColumnSchema(
            schemaSignature: signature,
            columnWidths: widths,
            columnOrder: order,
            lastModified: Date()
        )
    }
    
    private func restoreCachedColumnConfiguration(_ cachedSchema: PersistentColumnSchema, columnsToUse: [(name: String, dataType: String?)]) {
        // Restore column widths to both caches
        columnWidthCache = cachedSchema.columnWidths
        userModifiedWidths = cachedSchema.columnWidths // These are user preferences from persistent storage
        
        // Mark all cached columns as having saved preferences
        for columnName in cachedSchema.columnWidths.keys {
            autoCalculatedColumns.insert(columnName)
        }
        
        debugLog("Restored persistent schema for table '\(tableName)' with \(cachedSchema.columnWidths.count) cached column widths")
    }
    
    private func getOrderedColumns(_ columnsToUse: [(name: String, dataType: String?)]) -> [(name: String, dataType: String?)] {
        // Try to get saved column order
        if let cachedSchema = loadPersistentSchema(for: tableName),
           cachedSchema.schemaSignature == currentSchemaSignature {
            
            // Reorder columns based on saved order
            var orderedColumns: [(name: String, dataType: String?)] = []
            let columnMap = Dictionary(uniqueKeysWithValues: columnsToUse.map { ($0.name, $0) })
            
            // Add columns in saved order
            for columnName in cachedSchema.columnOrder {
                if let column = columnMap[columnName] {
                    orderedColumns.append(column)
                }
            }
            
            // Add any new columns that weren't in the saved order
            for column in columnsToUse {
                if !cachedSchema.columnOrder.contains(column.name) {
                    orderedColumns.append(column)
                }
            }
            
            return orderedColumns
        }
        
        // Return original order if no cached order available
        return columnsToUse
    }
    
    private func saveCurrentColumnOrder() {
        let currentOrder = tableView.tableColumns.map { $0.identifier.rawValue }
        
        guard let cachedSchema = loadPersistentSchema(for: tableName) else {
            return
        }
        
        // Update the cached schema with new order
        let updatedSchema = PersistentColumnSchema(
            schemaSignature: cachedSchema.schemaSignature,
            columnWidths: cachedSchema.columnWidths,
            columnOrder: currentOrder,
            lastModified: Date()
        )
        
        savePersistentSchema(updatedSchema, for: tableName)
    }
    
    private func updatePersistentColumnWidth(_ columnIdentifier: String, width: CGFloat) {
        guard let cachedSchema = loadPersistentSchema(for: tableName) else {
            // Create new schema if none exists
            let newSchema = createSchemaCache(signature: currentSchemaSignature, columns: [])
            var updatedWidths = newSchema.columnWidths
            updatedWidths[columnIdentifier] = width
            
            let updatedSchema = PersistentColumnSchema(
                schemaSignature: newSchema.schemaSignature,
                columnWidths: updatedWidths,
                columnOrder: newSchema.columnOrder,
                lastModified: Date()
            )
            
            savePersistentSchema(updatedSchema, for: tableName)
            return
        }
        
        // Update existing schema
        var updatedWidths = cachedSchema.columnWidths
        updatedWidths[columnIdentifier] = width
        
        let updatedSchema = PersistentColumnSchema(
            schemaSignature: cachedSchema.schemaSignature,
            columnWidths: updatedWidths,
            columnOrder: cachedSchema.columnOrder,
            lastModified: Date()
        )
        
        savePersistentSchema(updatedSchema, for: tableName)
    }
    
    // MARK: - NSMenuDelegate
    
    func menuNeedsUpdate(_ menu: NSMenu) {
        // Use actual right-click location for menu validation
        let rightClickLocation = tableView.getRightClickedCell()
        let rightClickedRow = rightClickLocation.row
        let rightClickedColumn = rightClickLocation.column
        let hasValidRow = rightClickedRow >= 0
        let hasValidCell = hasValidRow && rightClickedColumn >= 0
        let hasData = totalCount > 0
        
        debugLog("Menu validation - rightClickedRow: \(rightClickedRow), rightClickedColumn: \(rightClickedColumn), hasValidRow: \(hasValidRow), hasValidCell: \(hasValidCell), hasData: \(hasData)")
        
        // Update using stored references
        editMenuItem?.isEnabled = hasValidCell
        deleteMenuItem?.isEnabled = hasValidRow && hasData
        addRowMenuItem?.isEnabled = true
        refreshMenuItem?.isEnabled = true
        
        // Also update via loop as backup
        for item in menu.items {
            guard let action = item.action else { continue }
            
            switch action {
            case #selector(editItem):
                item.isEnabled = hasValidCell
                debugLog("Edit item enabled: \(item.isEnabled)")
                
            case #selector(deleteItem):
                item.isEnabled = hasValidRow && hasData
                debugLog("Delete item enabled: \(item.isEnabled)")
                
            case #selector(addRow):
                item.isEnabled = true
                
            case #selector(refreshCurrentTable):
                item.isEnabled = true
                
            default:
                break
            }
        }
    }
    
    func menuWillOpen(_ menu: NSMenu) {
        debugLog("Menu will open - calling menuNeedsUpdate")
        menuNeedsUpdate(menu)
    }
}
