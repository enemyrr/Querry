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
    let onSort: ((String, Bool) -> Void)? // Callback for sorting: (column, ascending)
    let modificationTracker: TableModificationTracker?
    let scrollToBottom: Bool
    let onDeleteNewRow: ((Int) -> Void)? // Callback for deleting new rows
    
    init(schema: DatabaseSchemaResult? = nil, queryResult: QueryResult?, tableName: String = "", onSort: ((String, Bool) -> Void)? = nil, modificationTracker: TableModificationTracker? = nil, scrollToBottom: Bool = false, onDeleteNewRow: ((Int) -> Void)? = nil) {
        self.schema = schema
        self.queryResult = queryResult
        self.tableName = tableName
        self.onSort = onSort
        self.modificationTracker = modificationTracker
        self.scrollToBottom = scrollToBottom
        self.onDeleteNewRow = onDeleteNewRow
    }
    
    func makeCoordinator() -> TableCoordinator {
        return TableCoordinator(schema: schema, queryResult: queryResult, tableName: tableName, onSort: onSort, modificationTracker: modificationTracker, onDeleteNewRow: onDeleteNewRow)
    }
    
    func makeNSView(context: Context) -> NSView {
        return context.coordinator.setupTableView()
    }
    
    func updateNSView(_ nsView: NSView, context: Context) {
        if scrollToBottom {
            context.coordinator.needsToSelectLastRow = true
        }
        context.coordinator.updateRows(queryResult, newSchema: schema)
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
