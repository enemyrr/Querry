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
    private var knownColumns: Set<String> = []
    public var needsToSelectLastRow = false
    
    private var sortColumn: String?
    private var sortAscending = true
    
    // Callback for database-level sorting
    var onSort: ((String, Bool) -> Void)?
    
    // Callback for deleting new rows
    var onDeleteNewRow: ((Int) -> Void)?
    
    // Callback for refreshing table data
    var onRefresh: (() -> Void)?
    
    // Callback for foreign key navigation
    var onForeignKeyNavigation: ((String, String, String) -> Void)? // (tableName, columnName, value)

    // Callback for row selection
    var onRowSelected: (([String: QueryRowInfo]?) -> Void)?
    
    // Persistent storage
    public var tableName: String = ""

    // New: Cache namespacing to disambiguate across connections
    private let cacheNamespace: String
    
    private enum CellIdentifier {
        static let checkbox = NSUserInterfaceItemIdentifier("CheckboxCell")
        static let textCell = NSUserInterfaceItemIdentifier("TextCell")
        static let rowView = NSUserInterfaceItemIdentifier("CustomRowView")
        static let forignKeyCell = NSUserInterfaceItemIdentifier("ForeignKeyCell")
        static let enumCell = NSUserInterfaceItemIdentifier("EnumCell")
    }
    
    // Store modification tracker reference
    weak var modificationTracker: TableModificationTracker?

    // Reference to current tab for per-tab selection state
    weak var currentTab: DatabaseTab?

    // Menu item references for validation
    private weak var editMenuItem: NSMenuItem?
    private weak var deleteMenuItem: NSMenuItem?
    private weak var addRowMenuItem: NSMenuItem?
    private weak var refreshMenuItem: NSMenuItem?
    private weak var quickLookMenuItem: NSMenuItem?
    private weak var copyMenuItem: NSMenuItem?
    private weak var copyRowsAsMenuItem: NSMenuItem?
    
    // Real-time change highlighting
    var highlightedFields: Set<String> = []
    var highlightedRows: Set<Int> = []
    
    init(schema: DatabaseSchemaResult? = nil, queryResult: QueryResult?, tableName: String = "", onSort: ((String, Bool) -> Void)? = nil, modificationTracker: TableModificationTracker? = nil, onDeleteNewRow: ((Int) -> Void)? = nil, onRefresh: (() -> Void)? = nil, onForeignKeyNavigation: ((String, String, String) -> Void)? = nil, highlightedFields: Set<String> = [], highlightedRows: Set<Int> = [], cacheNamespace: String = "", onRowSelected: (([String: QueryRowInfo]?) -> Void)? = nil) {
        self.schema = schema
        self.queryResult = queryResult
        self.tableName = tableName
        self.onSort = onSort
        self.modificationTracker = modificationTracker
        self.onDeleteNewRow = onDeleteNewRow
        self.onRefresh = onRefresh
        self.onForeignKeyNavigation = onForeignKeyNavigation
        self.highlightedFields = highlightedFields
        self.highlightedRows = highlightedRows
        self.cacheNamespace = cacheNamespace
        self.onRowSelected = onRowSelected
        
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
        NotificationCenter.default.addObserver(self, selector: #selector(handleTableReloadData(notification:)), name: .tableReloadData, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(handleQuickLookRequest(notification:)), name: .cellQuickLookRequested, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(handleCopyKey(notification:)), name: .didRequestCopy, object: nil)
    }
    
    @objc private func handleTableReloadData(notification: Notification) {
        if let userInfo = notification.userInfo,
           let targetTableName = userInfo["tableName"] as? String,
           !targetTableName.isEmpty,
           targetTableName != self.tableName {
            return
        }
        Task { @MainActor [weak self] in
            self?.tableView.reloadData()
        }
    }

    @objc private func handleCopyKey(notification: Notification) {
        guard notification.userInfo?["tableView"] as? CustomTableView === tableView else { return }
        copyRowsAsPlainText()
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

        Task { @MainActor [weak self] in
            self?.onForeignKeyNavigation?(referencedTable, referencedColumn, currentValue)
        }
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

        Task { @MainActor [weak self] in
            guard let self else { return }

            if let cellView = self.findCellView(rowIndex: rowIndex, columnName: columnName) {
                debugLog("🔍 Updating cell view for undo - Row: \(rowIndex), Column: \(columnName), New Value: '\(newValue)'")
                cellView.resetModificationState()
                cellView.needsDisplay = true
                cellView.needsLayout = true
            } else {
                debugLog("⚠️ Could not find cell view for Row: \(rowIndex), Column: \(columnName)")
            }

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
    
    // MARK: - Real-time Change Highlighting
    
    func updateHighlighting(fields: Set<String>, rows: Set<Int>) {
        // Only update and reload if highlighting actually changed
        let fieldsChanged = self.highlightedFields != fields
        let rowsChanged = self.highlightedRows != rows
        
        if fieldsChanged || rowsChanged {
            self.highlightedFields = fields
            self.highlightedRows = rows
            
            Task { @MainActor in
                if !rows.isEmpty {
                    let indexSet = IndexSet(rows)
                    self.tableView.reloadData(forRowIndexes: indexSet, columnIndexes: IndexSet(0..<self.tableView.numberOfColumns))
                } else if fieldsChanged {
                    self.tableView.reloadData()
                }
            }
        }
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
        
        // Update ALL references
        self.queryResult = newQueryResult
        self.schema = newSchema
        
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
        
        
        Task { @MainActor [weak self] in
            guard let self else { return }

            if let previousSelectedRow, previousSelectedRow >= self.totalCount {
                debugLog("🔄 Previously selected row \(previousSelectedRow) is out of bounds (new count: \(self.totalCount)). Clearing selection.")
                self.tableView.clearAllSelection()
            }

            if newColumnCount != oldColumnCount {
                self.rebuildTableStructure()
            } else {
                self.tableView.reloadData()
            }

            if self.needsToSelectLastRow {
                self.scrollToBottomAndSelectFirstCell()
            }

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
        // Don't update headers if table view is being deallocated
        guard tableView.window != nil else { return }

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
        Task { @MainActor in
            self.needsToSelectLastRow = false
            let numberOfRows = self.tableView.numberOfRows
            guard numberOfRows > 0 else { return }

            let lastRowIndex = numberOfRows - 1
            self.tableView.scrollRowToVisible(lastRowIndex)

            if self.tableView.numberOfColumns > 0 {
                self.tableView.window?.makeFirstResponder(self.tableView)
                self.tableView.editColumn(0, row: lastRowIndex, with: nil, select: true)
                self.tableView.selectCell(row: lastRowIndex, column: 0)
            }
        }
    }
    
    private func createColumn(identifier: String, title: String, dataType: String?, icon: NSImage?) {
        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier(identifier))
        column.title = title

        // Use cached width if available
        if let cachedWidth = columnWidthCache[identifier] {
            debugLog("📏 Using cached width for '\(identifier)': \(cachedWidth)")
            column.width = cachedWidth
            column.minWidth = 10
            column.maxWidth = CGFloat.greatestFiniteMagnitude
        }

        // Add custom header
        let customHeaderCell = CustomTableHeaderCell(textCell: identifier)
        var tooltip: String? = nil
        var isForeignKey: Bool = false
        if let schema = schema, let columnInfo = schema.column(named: identifier) {
            var relationText: String?
            if let fkConstraint = columnInfo.constraints.first(where: { $0.type == .foreignKey }) {
                isForeignKey = true
                let localColumn = identifier
                let refSchema = fkConstraint.referencedSchema
                let refTable = fkConstraint.referencedTable
                let refColumn = fkConstraint.referencedColumns?.first
                var target = ""
                if let refTable = refTable {
                    if let refSchema = refSchema, !refSchema.isEmpty {
                        target = "\(refSchema).\(refTable)"
                    } else {
                        target = refTable
                    }
                    if let refColumn = refColumn, !refColumn.isEmpty {
                        target += ".\(refColumn)"
                    }
                }
                if !target.isEmpty {
                    relationText = "Foreign key relation: \(localColumn) → \(target)"
                }
            }
            if let relationText = relationText {
                tooltip = relationText
            } else if let dt = dataType, !dt.isEmpty {
                tooltip = dt
            }
        } else {
            tooltip = dataType
        }
        customHeaderCell.configure(title: title, fieldType: dataType, tooltip: tooltip, isForeignKey: isForeignKey)
        column.headerCell = customHeaderCell
        
        let sortDescriptor = NSSortDescriptor(key: column.title, ascending: true, selector: #selector(NSString.localizedCaseInsensitiveCompare(_:)))
        column.sortDescriptorPrototype = sortDescriptor
        
        tableView.addTableColumn(column)
        
        tableView.target = self
        tableView.doubleAction = #selector(tableViewDoubleClick(_:))
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
        
        // Calculate optimal widths for initial setup
        if let queryResult = queryResult {
            preCalculateOptimalColumnWidths(for: columnsToUse, queryResult: queryResult)
        }

        // Create columns with optimal widths
        for columnInfo in columnsToUse {
            createColumn(
                identifier: columnInfo.name,
                title: columnInfo.name,
                dataType: columnInfo.dataType,
                icon: nil
            )
        }
        
        // Enable column resizing and auto-save
        tableView.allowsColumnResizing = true
        tableView.allowsColumnReordering = true
        tableView.columnAutoresizingStyle = .noColumnAutoresizing

        // Use NSTableView's built-in autosave with connection-specific namespace
        let autosaveName = "\(cacheNamespace.isEmpty ? "global" : cacheNamespace)_\(tableName)"
        tableView.autosaveName = autosaveName
        tableView.autosaveTableColumns = true

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

        // Quick Look menu item
        let quickLookItem = NSMenuItem(title: "Quick Look", action: #selector(quickLookItem), keyEquivalent: "\r")
        quickLookItem.keyEquivalentModifierMask = [.command]
        quickLookItem.target = self
        menu.addItem(quickLookItem)
        self.quickLookMenuItem = quickLookItem

        // Separator
        menu.addItem(NSMenuItem.separator())
        
        // Delete menu item
        let deleteItem = NSMenuItem(title: "Delete", action: #selector(deleteItem), keyEquivalent: "\u{8}")
        deleteItem.keyEquivalentModifierMask = []
        deleteItem.target = self
        menu.addItem(deleteItem)
        self.deleteMenuItem = deleteItem

        // Separator
        menu.addItem(NSMenuItem.separator())

        // Copy menu item (plain text copy with Cmd+C shortcut)
        let copyItem = NSMenuItem(title: "Copy", action: #selector(copyRowsAsPlainText), keyEquivalent: "c")
        copyItem.keyEquivalentModifierMask = [.command]
        copyItem.target = self
        menu.addItem(copyItem)
        self.copyMenuItem = copyItem

        // Copy Rows As submenu
        let copyRowsAsItem = NSMenuItem(title: "Copy Rows As", action: nil, keyEquivalent: "")
        let copyRowsSubmenu = NSMenu()

        let plainTextItem = NSMenuItem(title: "Plain Text", action: #selector(copyRowsAsPlainText), keyEquivalent: "")
        plainTextItem.target = self
        copyRowsSubmenu.addItem(plainTextItem)

        let jsonItem = NSMenuItem(title: "JSON", action: #selector(copyRowsAsJSON), keyEquivalent: "")
        jsonItem.target = self
        copyRowsSubmenu.addItem(jsonItem)

        let htmlItem = NSMenuItem(title: "HTML", action: #selector(copyRowsAsHTML), keyEquivalent: "")
        htmlItem.target = self
        copyRowsSubmenu.addItem(htmlItem)

        let markdownItem = NSMenuItem(title: "Markdown Table", action: #selector(copyRowsAsMarkdown), keyEquivalent: "")
        markdownItem.target = self
        copyRowsSubmenu.addItem(markdownItem)

        copyRowsSubmenu.addItem(NSMenuItem.separator())

        let csvItem = NSMenuItem(title: "CSV", action: #selector(copyRowsAsCSV), keyEquivalent: "")
        csvItem.target = self
        copyRowsSubmenu.addItem(csvItem)

        let csvHeaderItem = NSMenuItem(title: "CSV with Header", action: #selector(copyRowsAsCSVWithHeader), keyEquivalent: "")
        csvHeaderItem.target = self
        copyRowsSubmenu.addItem(csvHeaderItem)

        copyRowsSubmenu.addItem(NSMenuItem.separator())

        let insertItem = NSMenuItem(title: "INSERT Statement", action: #selector(copyRowsAsInsertStatement), keyEquivalent: "")
        insertItem.target = self
        copyRowsSubmenu.addItem(insertItem)

        copyRowsAsItem.submenu = copyRowsSubmenu
        menu.addItem(copyRowsAsItem)
        self.copyRowsAsMenuItem = copyRowsAsItem

        menu.delegate = self
        menu.autoenablesItems = false
        tableView.menu = menu

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
        // When rebuilding, clear cache
        columnWidthCache.removeAll()
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
    
    private func preCalculateOptimalColumnWidths(for columnsToUse: [(name: String, dataType: String?)], queryResult: QueryResult) {
        // Pre-computed font attributes for performance
        let headerFont = NSFont.systemFont(ofSize: 12, weight: .medium)
        let contentFont = NSFont.systemFont(ofSize: 12)
        let headerAttributes = [NSAttributedString.Key.font: headerFont]
        let contentAttributes = [NSAttributedString.Key.font: contentFont]

        // Calculate optimal width for each column
        for columnInfo in columnsToUse {
            let columnIdentifier = columnInfo.name

            // Skip if already calculated
            if columnWidthCache[columnIdentifier] != nil {
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

            let optimalWidth = max(headerWidth, maxContentWidth)
            columnWidthCache[columnIdentifier] = optimalWidth
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

        // Only recalculate for new columns that don't have cached widths
        let currentColumnNames = Set(columnsToProcess.map { $0.name })
        let newColumns = currentColumnNames.subtracting(knownColumns)

        // Find columns that need width calculation
        let columnsNeedingCalculation = columnsToProcess.filter { columnInfo in
            let columnName = columnInfo.name
            return newColumns.contains(columnName) && columnWidthCache[columnName] == nil
        }

        if !columnsNeedingCalculation.isEmpty {
            preCalculateOptimalColumnWidths(for: columnsNeedingCalculation, queryResult: queryResult)

            // Apply new widths only to newly calculated columns
            for tableColumn in tableView.tableColumns {
                let columnId = tableColumn.identifier.rawValue
                if columnsNeedingCalculation.contains(where: { $0.name == columnId }),
                   let newWidth = columnWidthCache[columnId] {
                    tableColumn.width = newWidth
                    tableColumn.minWidth = 10
                    tableColumn.maxWidth = CGFloat.greatestFiniteMagnitude
                }
            }
        }

        // Always update knownColumns to current state
        knownColumns = currentColumnNames
    }
    
    // MARK: - NSTableViewDataSource
    func numberOfRows(in tableView: NSTableView) -> Int {
        return self.totalCount
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

        // Return cached width if available
        if let cachedWidth = columnWidthCache[columnIdentifier] {
            return cachedWidth
        }

        // Fallback: basic calculation
        let headerFont = NSFont.systemFont(ofSize: 12, weight: .medium)
        let headerAttributes = [NSAttributedString.Key.font: headerFont]
        let headerWidth = (tableColumn.title as NSString).size(withAttributes: headerAttributes).width + 50

        return max(100, headerWidth) // Minimum reasonable width
    }

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
            debugLog("⚠️ TableCoordinator: No data for row \(row), column \(columnName)")
            return nil
        }

        if highlightedRows.contains(row) && highlightedFields.contains(columnName) {
            debugLog("💡 TableCoordinator: Rendering highlighted cell [\(row), \(columnName)] = \(queryRowInfo.value ?? "nil")")
        }

        guard let columnInfo = queryResult.column(named: columnName) else {
            return nil
        }

        let schemaColumn = schema?.column(named: columnName)
        let isReadOnly = schemaColumn?.isReadOnly ?? false
        let isNullable = schemaColumn?.isNullable.uppercased() == "YES"

        if let schemaColumn = schemaColumn,
           schemaColumn.isEnum,
           let enumValues = schemaColumn.enumValues {
            return configureEnumCell(
                tableView: tableView,
                value: (queryRowInfo.value as? String) ?? "",
                enumValues: enumValues,
                row: row,
                columnName: columnName,
                dataType: columnInfo.dataType,
                isReadOnly: isReadOnly,
                isNullable: isNullable
            )
        }

        let cellIdentifier = getCellIdentifier(for: columnInfo.dataType)

        var cellView = tableView.makeView(withIdentifier: cellIdentifier, owner: self) as? TextCellView

        if cellView == nil {
            cellView = createCellView(for: columnInfo.dataType)
            cellView?.identifier = cellIdentifier
        } else {
            cellView?.prepareForReuse()
        }

        let foreignKeyConstraint = schemaColumn?.constraints.first { $0.type == .foreignKey }

        let isHighlightedField = highlightedFields.contains(columnName)
        let isHighlightedRow = highlightedRows.contains(row)
        let shouldHighlight = isHighlightedField && isHighlightedRow

        cellView?.configure(queryRowInfo: queryRowInfo,
                            columnInfo: columnInfo,
                            rowIndex: row,
                            modificationTracker: modificationTracker,
                            constraintInfo: foreignKeyConstraint,
                            tableName: tableName,
                            shouldHighlight: shouldHighlight,
                            isReadOnly: isReadOnly
        )

        return cellView
    }

    private func configureEnumCell(
        tableView: NSTableView,
        value: String,
        enumValues: [String],
        row: Int,
        columnName: String,
        dataType: String,
        isReadOnly: Bool,
        isNullable: Bool
    ) -> NSView? {
        var cellView = tableView.makeView(withIdentifier: CellIdentifier.enumCell, owner: self) as? EnumCellView

        if cellView == nil {
            cellView = EnumCellView()
            cellView?.identifier = CellIdentifier.enumCell
        } else {
            cellView?.prepareForReuse()
        }

        cellView?.configure(
            value: value,
            enumValues: enumValues,
            rowIndex: row,
            columnName: columnName,
            dataType: dataType,
            modificationTracker: modificationTracker,
            tableName: tableName,
            isReadOnly: isReadOnly,
            isNullable: isNullable
        )

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
    
    
    // MARK: - NSMenuDelegate
    
    func menuNeedsUpdate(_ menu: NSMenu) {
        // Use actual right-click location for menu validation
        let rightClickLocation = tableView.getRightClickedCell()
        let rightClickedRow = rightClickLocation.row
        let rightClickedColumn = rightClickLocation.column
        let hasValidRow = rightClickedRow >= 0
        let hasValidCell = hasValidRow && rightClickedColumn >= 0
        let hasData = totalCount > 0
        let hasSelectedRows = !tableView.selectedRowIndexes.isEmpty

        debugLog("Menu validation - rightClickedRow: \(rightClickedRow), rightClickedColumn: \(rightClickedColumn), hasValidRow: \(hasValidRow), hasValidCell: \(hasValidCell), hasData: \(hasData)")

        // Update using stored references
        editMenuItem?.isEnabled = hasValidCell
        deleteMenuItem?.isEnabled = hasValidRow && hasData
        addRowMenuItem?.isEnabled = true
        refreshMenuItem?.isEnabled = true
        quickLookMenuItem?.isEnabled = hasValidCell
        copyMenuItem?.isEnabled = hasSelectedRows && hasData
        copyRowsAsMenuItem?.isEnabled = hasSelectedRows && hasData

        // Also update via loop as backup
        for item in menu.items {
            guard let action = item.action else {
                // Handle "Copy Rows As" submenu (has no action, only submenu)
                if item.title == "Copy Rows As" {
                    item.isEnabled = hasSelectedRows && hasData
                }
                continue
            }

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

            case #selector(quickLookItem):
                item.isEnabled = hasValidCell
                debugLog("Quick Look item enabled: \(item.isEnabled)")

            default:
                break
            }
        }
    }
    
    func menuWillOpen(_ menu: NSMenu) {
        debugLog("Menu will open - calling menuNeedsUpdate")
        menuNeedsUpdate(menu)
    }

    // MARK: - Row Selection

    func tableViewSelectionDidChange(_ notification: Notification) {
        let selectedRow = tableView.selectedRow

        Task { @MainActor [weak self] in
            guard let self else { return }

            if selectedRow >= 0, let queryResult = self.queryResult, selectedRow < queryResult.rows.count {
                let rowData = queryResult.rows[selectedRow]
                self.onRowSelected?(rowData)
                self.currentTab?.selectedRowIndex = selectedRow
                self.currentTab?.selectedColumnOrder = queryResult.columns.map { $0.name }
                if selectedRow < queryResult.rawRows.count {
                    self.currentTab?.selectedRawRowData = queryResult.rawRows[selectedRow]
                }
            } else {
                self.onRowSelected?(nil)
                self.currentTab?.selectedRowIndex = nil
                self.currentTab?.selectedColumnOrder = nil
                self.currentTab?.selectedRawRowData = nil
            }
        }
    }
}
