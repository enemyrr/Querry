//
//  ModificationTracker.swift
//  Pluk
//
//  Created by Fauzaan on 06/22/25.
//
import Foundation
import SwiftUI

// MARK: - Cell Modification Model
struct CellModification {
    let rowIndex: Int
    let columnName: String
    let originalValue: String
    let newValue: String
    let dataType: String
    
    var hasChanged: Bool {
        return originalValue != newValue
    }
}

// MARK: - Row Modification Model
struct RowModification {
    let rowIndex: Int
    var cellModifications: [String: CellModification] = [:]
    
    var hasModifications: Bool {
        return cellModifications.values.contains { $0.hasChanged }
    }
    
    var modifiedColumns: [String] {
        return cellModifications.compactMap { key, value in
            value.hasChanged ? key : nil
        }
    }
    
    mutating func updateCell(columnName: String, newValue: String, originalValue: String, dataType: String) {
        cellModifications[columnName] = CellModification(
            rowIndex: rowIndex,
            columnName: columnName,
            originalValue: originalValue,
            newValue: newValue,
            dataType: dataType
        )
    }
    
    mutating func removeCell(columnName: String) {
        cellModifications.removeValue(forKey: columnName)
    }
    
    func getModification(for columnName: String) -> CellModification? {
        return cellModifications[columnName]
    }
}

// MARK: - Table Modification Tracker
@Observable class TableModificationTracker {
    private var rowModifications: [Int: RowModification] = [:]
    
    // Public computed properties
    var modifiedRowCount: Int {
        return rowModifications.values.filter { $0.hasModifications }.count
    }
    
    var allModifications: [RowModification] {
        return rowModifications.values.filter { $0.hasModifications }
    }
    
    var hasModifications: Bool {
        return modifiedRowCount > 0
    }
    
    // MARK: - Modification Management
    func updateCell(rowIndex: Int, columnName: String, newValue: String, originalValue: String, dataType: String) {
        if rowModifications[rowIndex] == nil {
            rowModifications[rowIndex] = RowModification(rowIndex: rowIndex)
        }
        
        rowModifications[rowIndex]?.updateCell(
            columnName: columnName,
            newValue: newValue,
            originalValue: originalValue,
            dataType: dataType
        )
        
        // Remove the row modification if no changes remain
        if let rowMod = rowModifications[rowIndex], !rowMod.hasModifications {
            rowModifications.removeValue(forKey: rowIndex)
        }
    }
    
    func resetCell(rowIndex: Int, columnName: String) {
        rowModifications[rowIndex]?.removeCell(columnName: columnName)
        
        // Remove the row modification if no changes remain
        if let rowMod = rowModifications[rowIndex], !rowMod.hasModifications {
            rowModifications.removeValue(forKey: rowIndex)
        }
    }
    
    func resetRow(rowIndex: Int) {
        rowModifications.removeValue(forKey: rowIndex)
    }
    
    func resetAllModifications() {
        rowModifications.removeAll()
    }
    
    func getRowModification(for rowIndex: Int) -> RowModification? {
        return rowModifications[rowIndex]
    }
    
    func getCellModification(rowIndex: Int, columnName: String) -> CellModification? {
        return rowModifications[rowIndex]?.getModification(for: columnName)
    }
    
    func isRowModified(_ rowIndex: Int) -> Bool {
        return rowModifications[rowIndex]?.hasModifications ?? false
    }
    
    func isCellModified(rowIndex: Int, columnName: String) -> Bool {
        return getCellModification(rowIndex: rowIndex, columnName: columnName)?.hasChanged ?? false
    }
}
