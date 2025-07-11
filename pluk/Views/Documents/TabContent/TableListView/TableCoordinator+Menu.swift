//
//  TableCoordinator+Menu.swift
//  Pluk
//
//  Created by Fauzaan on 7/10/25.
//

import Foundation
import AppKit
import Combine

// MARK: - Menu Actions Extension
extension TableCoordinator {
    
    @objc func refreshCurrentTable() {
        NotificationCenter.default.post(
            name: .tableRefresh,
            object: nil,
            userInfo: ["tableName": tableName]
        )
    }
    
    @objc func addRow() {
        NotificationCenter.default.post(
            name: .addNewRecord,
            object: self,
            userInfo: ["tableName": tableName]
        )
    }
    
    @objc func editItem() {
        // Get the currently selected row and column
        let selectedRow = tableView.selectedRow
        let selectedColumn = tableView.selectedColumn
        
        guard selectedRow >= 0 && selectedColumn >= 0 else {
            return
        }
        
        // Start editing the selected cell
        tableView.editColumn(selectedColumn, row: selectedRow, with: nil, select: true)
    }
    
    @objc func deleteItem() {
        let selectedRows = tableView.selectedRowIndexes
        
        guard !selectedRows.isEmpty else {
            return
        }
        
        
        NotificationCenter.default.post(
            name: .didRequestDelete,
            object: self,
            userInfo: ["rows": selectedRows, "tableView": self]
        )
    }
}
