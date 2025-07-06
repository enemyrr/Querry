//
//  CustomTableView.swift
//  Pluk
//
//  Created by Fauzaan on 6/24/25.
//

import Foundation
import AppKit

// MARK: - Custom NSTableView that enables single-click editing
class CustomTableView: NSTableView {
    // Handler for undo operations
    var undoHandler: (() -> Bool)?
    
    // Track currently selected cell for keyboard navigation
    private var currentSelectedRow: Int = -1
    private var currentSelectedColumn: Int = -1
    
    override func keyDown(with event: NSEvent) {
        // Check for Cmd+Z (undo)
        if event.modifierFlags.contains(.command) && event.keyCode == 6 { // 'z' key
            if let undoHandler = undoHandler, undoHandler() {
                // Undo was handled successfully
                return
            }
        }
        
        // Handle navigation keys when NOT in edit mode
        if handleNonEditModeNavigation(with: event) {
            return // We handled the key
        }
        
        // Let the superclass handle other key events
        super.keyDown(with: event)
    }
    
    // MARK: - Non-Edit Mode Navigation
    private func handleNonEditModeNavigation(with event: NSEvent) -> Bool {
        debugLog("🧭 Handling navigation in non-edit mode")
        
        let currentColumn = currentSelectedColumn
        let currentRow = currentSelectedRow
        let keyCode = event.keyCode
        
        debugLog("📍 Current position: Row \(currentRow), Column \(currentColumn)")
        
        // Only initialize selection if user explicitly requests navigation and there's no current selection
        if currentSelectedRow == -1 || currentSelectedColumn == -1 {
            // For keyboard navigation, only start selection if user presses arrow keys or enter
            // Don't auto-select on table mount
            if keyCode == 126 || keyCode == 125 || keyCode == 123 || keyCode == 124 || keyCode == 48 || keyCode == 36 {
                debugLog("🎯 User initiated navigation, initializing selection")
                // If no cell is selected, start at current selected row or (0,0)
                if selectedRow >= 0 {
                    currentSelectedRow = selectedRow
                    currentSelectedColumn = 0
                } else {
                    currentSelectedRow = 0
                    currentSelectedColumn = 0
                }
                // Select the initial cell
                selectCell(row: currentSelectedRow, column: currentSelectedColumn)
                return true
            } else {
                // Not a navigation key, don't initialize selection
                return false
            }
        }
        var newRow = currentSelectedRow
        var newColumn = currentSelectedColumn
        var handled = false
        
        switch keyCode {
        case 126: // Up arrow
            newRow = max(0, currentSelectedRow - 1)
            handled = true
            debugLog("⬆️ Up arrow - moving from row \(currentRow) to row \(newRow)")
            
        case 125: // Down arrow
            newRow = min(numberOfRows - 1, currentSelectedRow + 1)
            handled = true
            debugLog("⬇️ Down arrow - moving from row \(currentRow) to row \(newRow)")
            
        case 123: // Left arrow
            newColumn = max(0, currentSelectedColumn - 1)
            handled = true
            debugLog("⬅️ Left arrow - moving from column \(currentColumn) to column \(newColumn)")
            
        case 124: // Right arrow
            newColumn = min(numberOfColumns - 1, currentSelectedColumn + 1)
            handled = true
            debugLog("➡️ Right arrow - moving from column \(currentColumn) to column \(newColumn)")
            
        case 48, 36: // Tab key
            // Enter edit mode for current cell
            if currentSelectedRow >= 0 && currentSelectedColumn >= 0 {
                debugLog("⏎ Enter pressed - entering edit mode for cell (\(currentRow), \(currentColumn))")
                enterEditModeForCell(row: currentSelectedRow, column: currentSelectedColumn)
                handled = true
            }
            
        case 53: // Escape key
            // Clear selection
            debugLog("❌ Escape pressed - clearing selection")
            clearCurrentCellSelection()
            currentSelectedRow = -1
            currentSelectedColumn = -1
            selectRowIndexes(IndexSet(), byExtendingSelection: false)
            handled = true
            
        case 51, 117: // Delete key (forward) and Backspace key (backward)
            // Mark the selected rows for deletion
            let selectedRows = self.selectedRowIndexes
            // We need a way to communicate this back to the coordinator/view model
            // For now, let's post a notification
            NotificationCenter.default.post(name: .didRequestDelete, object: self, userInfo: ["rows": selectedRows, "tableView": self])
            handled = true
            
        default:
            return false
        }
        
        if handled {
            // Ensure new position is valid
            newRow = max(0, min(numberOfRows - 1, newRow))
            newColumn = max(0, min(numberOfColumns - 1, newColumn))
            
            // Update selection if position changed and we're not clearing selection
            if (newRow != currentSelectedRow || newColumn != currentSelectedColumn) && keyCode != 53 {
                debugLog("🎯 Moving active cell from (\(currentSelectedRow), \(currentSelectedColumn)) to (\(newRow), \(newColumn))")
                selectCell(row: newRow, column: newColumn)
            }
        }
        
        return handled
    }
    
    // Enter edit mode for a specific cell
    private func enterEditModeForCell(row: Int, column: Int) {
        guard row >= 0 && row < numberOfRows && column >= 0 && column < numberOfColumns else {
            debugLog("❌ Invalid cell position: (\(row), \(column))")
            return
        }
        
        if let cellView = view(atColumn: column, row: row, makeIfNecessary: false) as? TextCellView {
            debugLog("✅ Entering edit mode for cell at (\(row), \(column))")
            cellView.enterEditMode()
        } else {
            debugLog("❌ Could not find TextCellView at (\(row), \(column))")
        }
    }
    
    // MARK: - Cell Selection Management
    
    /// Selects a specific cell and updates visual state
    func selectCell(row: Int, column: Int) {
        guard row >= 0 && row < numberOfRows && column >= 0 && column < numberOfColumns else {
            return
        }
        
        // Clear previous selection
        clearCurrentCellSelection()
        
        // Update current selection
        currentSelectedRow = row
        currentSelectedColumn = column
        
        // Update table row selection
        selectRowIndexes(IndexSet(integer: row), byExtendingSelection: false)
        
        // Set cell as selected
        if let cellView = view(atColumn: column, row: row, makeIfNecessary: false) as? TextCellView {
            cellView.setAsSelectedCell()
        }
        
        // Scroll to make sure the cell is visible
        scrollRowToVisible(row)
        scrollColumnToVisible(column)
    }
    
    override var acceptsFirstResponder: Bool {
        return true
    }
    
    /// Gets the currently selected cell coordinates
    func getCurrentSelectedCell() -> (row: Int, column: Int)? {
        if currentSelectedRow >= 0 && currentSelectedColumn >= 0 {
            return (currentSelectedRow, currentSelectedColumn)
        }
        return nil
    }
    
    /// Clears the current cell selection
    func clearCurrentCellSelection() {
        if currentSelectedRow >= 0 && currentSelectedColumn >= 0 {
            if let cellView = view(atColumn: currentSelectedColumn, row: currentSelectedRow, makeIfNecessary: false) as? TextCellView {
                cellView.clearSelection()
            }
        }
    }
    
    /// Clears all selection state completely (for pagination)
    func clearAllSelection() {
        debugLog("🧹 Clearing all table selection state")
        
        // Clear current cell selection visual state
        clearCurrentCellSelection()
        
        // Reset internal selection tracking
        currentSelectedRow = -1
        currentSelectedColumn = -1
        
        // Clear table row selection
        selectRowIndexes(IndexSet(), byExtendingSelection: false)
        
        // Clear any column selection
        deselectAll(nil)
        
        debugLog("✅ All selection state cleared")
    }
    
    /// Updates selection when table selection changes externally
    override func selectRowIndexes(_ indexes: IndexSet, byExtendingSelection extend: Bool) {
        super.selectRowIndexes(indexes, byExtendingSelection: extend)
        
        // Update our internal tracking
        if let firstIndex = indexes.first {
            currentSelectedRow = firstIndex
        }
    }
    
    override func selectColumnIndexes(_ indexes: IndexSet, byExtendingSelection extend: Bool) {
        super.selectColumnIndexes(indexes, byExtendingSelection: extend)
        
        // Update our internal column tracking
        if let firstIndex = indexes.first {
            currentSelectedColumn = firstIndex
            
            // If we have a valid row selection, update the cell selection
            if currentSelectedRow >= 0 {
                debugLog("📋 Column selection changed - updating cell selection to (\(currentSelectedRow), \(currentSelectedColumn))")
                selectCell(row: currentSelectedRow, column: currentSelectedColumn)
            }
        } else {
            // No columns selected, clear column tracking
            if !extend {
                currentSelectedColumn = -1
                clearCurrentCellSelection()
            }
        }
    }
    
    override func editColumn(_ column: Int, row: Int, with event: NSEvent?, select: Bool) {
        debugLog("✏️ editColumn called for (\(row), \(column)) with select: \(select)")
        
        // Validate row and column bounds
        guard row >= 0 && row < numberOfRows && column >= 0 && column < numberOfColumns else {
            debugLog("❌ Invalid cell position for editing: (\(row), \(column))")
            super.editColumn(column, row: row, with: event, select: select)
            return
        }
        
        // If select is true, update our selection to this cell
        if select {
            debugLog("🎯 Selecting cell (\(row), \(column)) before editing")
            selectCell(row: row, column: column)
        }
        
        // Try to get our custom TextCellView
        if let cellView = view(atColumn: column, row: row, makeIfNecessary: false) as? TextCellView {
            debugLog("✅ Found TextCellView - entering custom edit mode")
            
            // Update our internal tracking
            currentSelectedRow = row
            currentSelectedColumn = column
            
            // Use our custom edit mode implementation
            cellView.enterEditMode()
            
            // Ensure the cell is visible
            scrollRowToVisible(row)
            scrollColumnToVisible(column)
            
        } else {
            debugLog("⚠️ No TextCellView found - falling back to default editing")
            // Fall back to default behavior if we don't have a custom cell view
            super.editColumn(column, row: row, with: event, select: select)
        }
    }
    
    /// Get column index for a given column identifier
    func columnIndex(for identifier: String) -> Int {
        for (index, column) in tableColumns.enumerated() {
            if column.identifier.rawValue == identifier {
                return index
            }
        }
        return -1
    }
    
    /// Public method to trigger selection validation
    func validateSelectionAfterCellConfiguration() {
        DispatchQueue.main.async { [weak self] in
            self?.validateSelectionState()
        }
    }
    
    override func tile() {
        super.tile()
        // Use a small delay to ensure cells are configured before validating selection
        DispatchQueue.main.async { [weak self] in
            self?.validateSelectionState() // Ensure only correct cell is selected
        }
    }
    
    private func validateSelectionState() {
            // Ensure only the correct cell shows as selected
            if currentSelectedRow >= 0 && currentSelectedColumn >= 0 {
                debugLog("🔍 Validating selection state - should be selected: (\(currentSelectedRow), \(currentSelectedColumn))")
                
                // Clear any incorrectly selected cells
                for row in 0..<numberOfRows {
                    for col in 0..<numberOfColumns {
                        if let cellView = view(atColumn: col, row: row, makeIfNecessary: false) as? TextCellView {
                            let shouldBeSelected = (row == currentSelectedRow && col == currentSelectedColumn)
                            
                            if cellView.isSelected != shouldBeSelected {
                                debugLog("🔧 Correcting selection state for cell (\(row), \(col)): \(cellView.isSelected) → \(shouldBeSelected)")
                                
                                if shouldBeSelected {
                                    cellView.setAsSelectedCell()
                                } else {
                                    cellView.clearSelection()
                                }
                            }
                        }
                    }
                }
            } else {
                debugLog("🔍 No selected cell to validate")
            }
        }
        
    
    
    override func mouseDown(with event: NSEvent) {
        // Convert click point to table view coordinates
        let clickPoint = convert(event.locationInWindow, from: nil)
        
        // Get the row and column that was clicked
        let clickedRow = row(at: clickPoint)
        let clickedColumn = column(at: clickPoint)
        
        // Handle our custom logic first (this is fast and won't cause QoS issues)
        var handledByCustomCell = false
        
        // Ensure we clicked on a valid cell
        if clickedRow >= 0 && clickedColumn >= 0 {
            // Update our internal selection tracking
            selectCell(row: clickedRow, column: clickedColumn)
            
            // Get the cell view at the clicked location
            if let cellView = view(atColumn: clickedColumn, row: clickedRow, makeIfNecessary: false) {
                // Convert click point to cell view coordinates
                let cellClickPoint = cellView.convert(clickPoint, from: self)
                
                // Check if we clicked inside the cell bounds
                if cellView.bounds.contains(cellClickPoint) {
                    // If it's our custom TextCellView, handle the click
                    if let textCellView = cellView as? TextCellView {
                        textCellView.handleDoubleClickEdit(at: cellClickPoint, with: event)
                        handledByCustomCell = true
                    }
                }
            }
        }
        
        // Only call super if we didn't handle it with our custom logic
        // This reduces the chances of QoS conflicts
        if !handledByCustomCell {
            super.mouseDown(with: event)
        } else {
            // For custom cells, we still need row selection but can do it more efficiently
            if clickedRow >= 0 {
                // Perform selection change on main queue with appropriate QoS
                DispatchQueue.main.async(qos: .userInteractive) { [weak self] in
                    self?.selectRowIndexes(IndexSet(integer: clickedRow), byExtendingSelection: false)
                }
            }
        }
    }
}
