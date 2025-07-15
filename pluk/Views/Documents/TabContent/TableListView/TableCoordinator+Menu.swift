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
        // Get the currently selected cell (which was updated by right-click)
        guard let currentCell = tableView.getCurrentSelectedCell() else {
            return
        }
        
        let row = currentCell.row
        let column = currentCell.column
        
        guard row >= 0 && column >= 0 else {
            return
        }
        
        tableView.enterEditModeForCell(row: row, column: column)
    }
    
    @objc func deleteItem() {
        let selectedRows = tableView.selectedRowIndexes
        
        guard !selectedRows.isEmpty else {
            return
        }
        
        NotificationCenter.default.post(
            name: .didRequestDelete,
            object: self,
            userInfo: ["rows": selectedRows, "tableView": tableView]
        )
    }
}
