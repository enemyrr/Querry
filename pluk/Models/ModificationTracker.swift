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
    var newValue: String
    let dataType: String
    
    var hasChanged: Bool {
        return originalValue != newValue
    }
}

// MARK: - Modification History Entry
struct ModificationHistoryEntry {
    let id = UUID()
    let timestamp: Date
    let rowIndex: Int
    let columnName: String
    let previousValue: String
    let newValue: String
    let dataType: String
    
    init(rowIndex: Int, columnName: String, previousValue: String, newValue: String, dataType: String) {
        self.timestamp = Date()
        self.rowIndex = rowIndex
        self.columnName = columnName
        self.previousValue = previousValue
        self.newValue = newValue
        self.dataType = dataType
    }
}

enum RowModificationType {
    case update
    case insert
    case delete
}

// MARK: - Row Modification Model
struct RowModification {
    let rowIndex: Int
    var type: RowModificationType
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
    private var modificationHistory: [ModificationHistoryEntry] = []
    
    // Delegate to notify about undo events
    weak var undoDelegate: TableModificationUndoDelegate?
    
    // Public computed properties
    var modifiedRowCount: Int {
        return rowModifications.values.filter { $0.hasModifications }.count
    }
    
    var allModifications: [RowModification] {
        return rowModifications.values.filter { $0.hasModifications || $0.type == .insert || $0.type == .delete }
    }
    
    var hasModifications: Bool {
        return modifiedRowCount > 0
    }
    
    var hasPendingDeletions: Bool {
        return rowModifications.values.contains { $0.type == .delete }
    }
    
    var pendingDeletionCount: Int {
        return rowModifications.values.filter { $0.type == .delete }.count
    }
    
    var canUndo: Bool {
        return !modificationHistory.isEmpty
    }
    
    var historyCount: Int {
        return modificationHistory.count
    }
    
    // MARK: - Modification Management
    func markAsNewRow(rowIndex: Int, initialData: [String: Any]) {
        var newRow = RowModification(rowIndex: rowIndex, type: .insert)
        for (key, value) in initialData {
            let stringValue = String(describing: value)
            newRow.cellModifications[key] = CellModification(
                rowIndex: rowIndex,
                columnName: key,
                originalValue: stringValue,
                newValue: stringValue,
                dataType: "" // Data type can be refined later if needed
            )
        }
        rowModifications[rowIndex] = newRow
        print("rowModification: \(rowModifications)")
    }
    
    func markAsDeleted(rowIndex: Int) {
        if var row = rowModifications[rowIndex] {
            if row.type == .delete {
                // If it's already marked as delete, unmark it
                row.type = .update // Or revert to its original state if you track that
                rowModifications[rowIndex] = row
            } else {
                // If it's an update or insert, mark it as delete
                row.type = .delete
                rowModifications[rowIndex] = row
            }
        } else {
            // If there's no modification yet, create a new one and mark it as delete
            rowModifications[rowIndex] = RowModification(rowIndex: rowIndex, type: .delete)
        }
    }
    
    func updateCell(rowIndex: Int, columnName: String, newValue: String, originalValue: String, dataType: String) {
        print("updateCell: \(rowModifications)")
        // Check if there's already a modification for this cell
        let existingModification = getCellModification(rowIndex: rowIndex, columnName: columnName)
        
        if let existing = existingModification {
            // Cell already has a modification - we're updating an existing change
            // Only add to history if the new value is different from current modified value
            if existing.newValue != newValue {
                let historyEntry = ModificationHistoryEntry(
                    rowIndex: rowIndex,
                    columnName: columnName,
                    previousValue: existing.newValue,
                    newValue: newValue,
                    dataType: dataType
                )
                modificationHistory.append(historyEntry)
                print("📝 Updated existing modification: Row \(rowIndex), Column \(columnName), \(existing.newValue) → \(newValue)")
            }
        } else {
            // New modification - add to history
            let historyEntry = ModificationHistoryEntry(
                rowIndex: rowIndex,
                columnName: columnName,
                previousValue: originalValue,
                newValue: newValue,
                dataType: dataType
            )
            modificationHistory.append(historyEntry)
            print("📝 New cell modification: Row \(rowIndex), Column \(columnName), \(originalValue) → \(newValue)")
        }
        
        if rowModifications[rowIndex] == nil {
            rowModifications[rowIndex] = RowModification(rowIndex: rowIndex, type: .update)
        }
        
        rowModifications[rowIndex]?.updateCell(
            columnName: columnName,
            newValue: newValue,
            originalValue: originalValue,
            dataType: dataType
        )
        
        // Remove the row modification if no changes remain
        if let rowMod = rowModifications[rowIndex], !rowMod.hasModifications, rowMod.type == .update {
            rowModifications.removeValue(forKey: rowIndex)
        }
    }
    
    func resetCell(rowIndex: Int, columnName: String) {
        // Get the current modified value before resetting
        if let cellMod = getCellModification(rowIndex: rowIndex, columnName: columnName) {
            let historyEntry = ModificationHistoryEntry(
                rowIndex: rowIndex,
                columnName: columnName,
                previousValue: cellMod.newValue,
                newValue: cellMod.originalValue,
                dataType: cellMod.dataType
            )
            modificationHistory.append(historyEntry)
            print("🔄 Cell reset to original: Row \(rowIndex), Column \(columnName), \(cellMod.newValue) → \(cellMod.originalValue)")
        }
        
        rowModifications[rowIndex]?.removeCell(columnName: columnName)
        
        // Remove the row modification if no changes remain
        if let rowMod = rowModifications[rowIndex], !rowMod.hasModifications, rowMod.type == .update {
            rowModifications.removeValue(forKey: rowIndex)
        }
    }
    
    func resetRow(rowIndex: Int) {
        // Add reset entries to history for all modified cells in this row
        if let rowMod = rowModifications[rowIndex] {
            for (_, cellMod) in rowMod.cellModifications where cellMod.hasChanged {
                let historyEntry = ModificationHistoryEntry(
                    rowIndex: rowIndex,
                    columnName: cellMod.columnName,
                    previousValue: cellMod.newValue,
                    newValue: cellMod.originalValue,
                    dataType: cellMod.dataType
                )
                modificationHistory.append(historyEntry)
            }
        }
        
        rowModifications.removeValue(forKey: rowIndex)
    }
    
    func resetAllModifications() {
        // Add reset entries to history for all modifications
        for rowMod in allModifications {
            for (_, cellMod) in rowMod.cellModifications where cellMod.hasChanged {
                let historyEntry = ModificationHistoryEntry(
                    rowIndex: cellMod.rowIndex,
                    columnName: cellMod.columnName,
                    previousValue: cellMod.newValue,
                    newValue: cellMod.originalValue,
                    dataType: cellMod.dataType
                )
                modificationHistory.append(historyEntry)
            }
        }
        
        rowModifications.removeAll()
    }
    
    // MARK: - Undo Functionality
    func undo() -> Bool {
        guard let lastEntry = modificationHistory.popLast() else {
            print("❌ No modifications to undo")
            return false
        }
        
        print("⏪ Undoing: Row \(lastEntry.rowIndex), Column \(lastEntry.columnName), \(lastEntry.newValue) → \(lastEntry.previousValue)")
        
        // Notify delegate about the undo operation
        undoDelegate?.willUndoModification(
            rowIndex: lastEntry.rowIndex,
            columnName: lastEntry.columnName,
            fromValue: lastEntry.newValue,
            toValue: lastEntry.previousValue
        )
        
        // Apply the undo by setting the cell back to its previous value
        // We need to find the original value for this cell
        let originalValue = findOriginalValue(rowIndex: lastEntry.rowIndex, columnName: lastEntry.columnName)
        
        if lastEntry.previousValue == originalValue {
            // Reverting to original value - remove the modification
            if rowModifications[lastEntry.rowIndex] != nil {
                rowModifications[lastEntry.rowIndex]?.removeCell(columnName: lastEntry.columnName)
                
                // Remove the row modification if no changes remain
                if let rowMod = rowModifications[lastEntry.rowIndex], !rowMod.hasModifications {
                    rowModifications.removeValue(forKey: lastEntry.rowIndex)
                }
            }
        } else {
            // Reverting to a previous modified value - update the modification
            if rowModifications[lastEntry.rowIndex] == nil {
                rowModifications[lastEntry.rowIndex] = RowModification(rowIndex: lastEntry.rowIndex, type: .update)
            }
            
            rowModifications[lastEntry.rowIndex]?.updateCell(
                columnName: lastEntry.columnName,
                newValue: lastEntry.previousValue,
                originalValue: originalValue,
                dataType: lastEntry.dataType
            )
        }
        
        // Notify delegate that undo is complete
        undoDelegate?.didUndoModification(
            rowIndex: lastEntry.rowIndex,
            columnName: lastEntry.columnName,
            newValue: lastEntry.previousValue
        )
        
        return true
    }
    
    private func findOriginalValue(rowIndex: Int, columnName: String) -> String {
        // Look through history to find the first entry for this cell (which would contain the original value)
        // We need to find the earliest entry for this cell
        var earliestEntry: ModificationHistoryEntry?
        for entry in modificationHistory {
            if entry.rowIndex == rowIndex && entry.columnName == columnName {
                if earliestEntry == nil || entry.timestamp < earliestEntry!.timestamp {
                    earliestEntry = entry
                }
            }
        }
        
        if let earliest = earliestEntry {
            return earliest.previousValue
        }
        
        // If not found in history, check current modifications
        if let cellMod = getCellModification(rowIndex: rowIndex, columnName: columnName) {
            return cellMod.originalValue
        }
        
        // Fallback - should not happen in normal operation
        return ""
    }
    
    func clearHistory() {
        modificationHistory.removeAll()
        print("🗑️ Cleared modification history")
    }
    
    func printHistory() {
        print("📋 Modification History (\(modificationHistory.count) entries):")
        for (index, entry) in modificationHistory.enumerated() {
            print("  \(index + 1). Row \(entry.rowIndex), \(entry.columnName): '\(entry.previousValue)' → '\(entry.newValue)'")
        }
    }
    
    // MARK: - Query Methods
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

// MARK: - Undo Delegate Protocol
protocol TableModificationUndoDelegate: AnyObject {
    func willUndoModification(rowIndex: Int, columnName: String, fromValue: String, toValue: String)
    func didUndoModification(rowIndex: Int, columnName: String, newValue: String)
}
