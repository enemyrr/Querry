//
//  TableListViewController.swift
//  Pluk
//
//  Created by Fauzaan on 6/2/25.
//
import Foundation
import SwiftUI
import AppKit

struct TableListViewController: NSViewRepresentable {
    let schema: DatabaseSchemaResult?
    let queryResult: QueryResult?
    let tableName: String
    let cacheNamespace: String?
    let onSort: ((String, Bool) -> Void)? // Callback for sorting: (column, ascending)
    let modificationTracker: TableModificationTracker?
    let needsToSelectLastRow: Bool
    let onDeleteNewRow: ((Int) -> Void)? // Callback for deleting new rows
    let onForeignKeyNavigation: ((String, String, String) -> Void)? // Callback for foreign key navigation (tableName, columnName, value)
    let highlightedFields: Set<String>
    let highlightedRows: Set<Int>
    
    init(schema: DatabaseSchemaResult? = nil, queryResult: QueryResult?, tableName: String = "", cacheNamespace: String? = nil, onSort: ((String, Bool) -> Void)? = nil, modificationTracker: TableModificationTracker? = nil, needsToSelectLastRow: Bool = false, onDeleteNewRow: ((Int) -> Void)? = nil, onForeignKeyNavigation: ((String, String, String) -> Void)? = nil, highlightedFields: Set<String> = [], highlightedRows: Set<Int> = []) {
        self.schema = schema
        self.queryResult = queryResult
        self.tableName = tableName
        self.cacheNamespace = cacheNamespace
        self.onSort = onSort
        self.modificationTracker = modificationTracker
        self.needsToSelectLastRow = needsToSelectLastRow
        self.onDeleteNewRow = onDeleteNewRow
        self.onForeignKeyNavigation = onForeignKeyNavigation
        self.highlightedFields = highlightedFields
        self.highlightedRows = highlightedRows
    }
    
    func makeCoordinator() -> TableCoordinator {
        return TableCoordinator(schema: schema, queryResult: queryResult, tableName: tableName, onSort: onSort, modificationTracker: modificationTracker, onDeleteNewRow: onDeleteNewRow, onForeignKeyNavigation: onForeignKeyNavigation, highlightedFields: highlightedFields, highlightedRows: highlightedRows, cacheNamespace: cacheNamespace ?? "")
    }
    
    func makeNSView(context: Context) -> NSView {
        return context.coordinator.setupTableView()
    }
    
    func updateNSView(_ nsView: NSView, context: Context) {
        if needsToSelectLastRow {
            context.coordinator.needsToSelectLastRow = true
        }
        // Update data first, then apply highlighting
        context.coordinator.updateRows(queryResult, newSchema: schema)
        context.coordinator.updateHighlighting(fields: highlightedFields, rows: highlightedRows)
    }
    
    // Public method to set sorting state
    func setSortState(coordinator: Coordinator, column: String?, ascending: Bool) {
        coordinator.setSortState(column: column, ascending: ascending)
    }
}

extension Array {
    subscript(safe index: Index) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}
