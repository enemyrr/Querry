//
//  CustomTableView.swift
//  Pluk
//
//  Created by Fauzaan on 6/24/25.
//
import Foundation
import AppKit

// MARK: - Custom NSTableView using built-in selection mechanisms
class CustomTableView: NSTableView {
    // Handler for undo operations
    var undoHandler: (() -> Bool)?
    
    // Delegate for cell-level selection events
    weak var cellSelectionDelegate: TableViewCellSelectionDelegate?
    
    // Current cell selection (computed from built-in selection)
    private var currentCellLocation: (row: Int, column: Int)? {
        let selectedRow = self.selectedRow
        let clickedCol = self.clickedColumn
        
        // Only return a location if we have a valid selected row
        guard selectedRow >= 0 else {
            return nil
        }
        
        // If we have a valid clicked column, use it; otherwise use -1 for row-only selection
        let column = (clickedCol >= 0 && clickedCol < numberOfColumns) ? clickedCol : -1
        
        return (selectedRow, column)
    }
    
    override func awakeFromNib() {
        super.awakeFromNib()
    }
    
    // MARK: - Action-Target Pattern for Click Detection
    @objc private func handleTableClick() {
        let selectedRow = self.selectedRow
        let clickedCol = self.clickedColumn
        
        if selectedRow >= 0 && clickedCol >= 0 {
            debugLog("🎯 Cell clicked: (\(selectedRow), \(clickedCol))")
            cellSelectionDelegate?.tableView(self, didSelectCellAt: selectedRow, column: clickedCol)
        }
    }
    
    // MARK: - Keyboard Navigation
    override func keyDown(with event: NSEvent) {
        // Check for Cmd+Z (undo)
        if event.modifierFlags.contains(.command) && event.keyCode == 6 { // 'z' key
            if let undoHandler = undoHandler, undoHandler() {
                return
            }
        }
        
        // Handle navigation keys
        if handleKeyboardNavigation(with: event) {
            return
        }
        
        // Let the superclass handle other key events
        super.keyDown(with: event)
    }
    
    private func handleKeyboardNavigation(with event: NSEvent) -> Bool {
        let keyCode = event.keyCode
        let currentRow = selectedRow
        
        // Initialize selection if none exists and user presses navigation key
        if currentRow < 0 && (keyCode == 126 || keyCode == 125 || keyCode == 123 || keyCode == 124) {
            selectRowIndexes(IndexSet(integer: 0), byExtendingSelection: false)
            scrollRowToVisible(0)
            return true
        }
        
        var newRow = currentRow
        var handled = false
        
        switch keyCode {
        case 126: // Up arrow
            newRow = max(0, currentRow - 1)
            handled = true
            
        case 125: // Down arrow
            newRow = min(numberOfRows - 1, currentRow + 1)
            handled = true
            
        case 123: // Left arrow - move to previous column
            let newColumn = max(0, (storedClickedColumn >= 0 ? storedClickedColumn : 0) - 1)
            setClickedColumn(newColumn)
            refreshSelectedRowByReselection()
            handled = true
            
        case 124: // Right arrow - move to next column
            let newColumn = max(0, (storedClickedColumn >= 0 ? storedClickedColumn : 0) + 1)
            setClickedColumn(newColumn)
            refreshSelectedRowByReselection()
            handled = true
            
        case 48, 36: // Tab/Enter - enter edit mode
            if let cellLocation = currentCellLocation {
                enterEditModeForCell(row: cellLocation.row, column: cellLocation.column)
                handled = true
            }
            
        case 53: // Escape - clear selection
            selectRowIndexes(IndexSet(), byExtendingSelection: false)
            handled = true
            
        case 51, 117: // Delete/Backspace
            let selectedRows = selectedRowIndexes
            NotificationCenter.default.post(
                name: .didRequestDelete,
                object: self,
                userInfo: ["rows": selectedRows, "tableView": self]
            )
            handled = true
            
        default:
            return false
        }
        
        if handled && newRow != currentRow && keyCode != 53 {
            selectRowIndexes(IndexSet(integer: newRow), byExtendingSelection: false)
            scrollRowToVisible(newRow)
        }
        
        return handled
    }
    
    func refreshSelectedRowByReselection() {
        guard selectedRow >= 0 else { return }
        
        let currentRow = selectedRow
        let currentColumn = storedClickedColumn
        
        // Deselect
        selectRowIndexes(IndexSet(), byExtendingSelection: false)
        
        // Immediately reselect
        selectRowIndexes(IndexSet(integer: currentRow), byExtendingSelection: false)
        
        // Restore column selection
        if currentColumn >= 0 {
            storedClickedColumn = currentColumn
        }
    }
    
    // MARK: - Mouse Event Handling
    override func mouseDown(with event: NSEvent) {
        let clickPoint = convert(event.locationInWindow, from: nil)
        let clickedRow = row(at: clickPoint)
        let clickedColumn = column(at: clickPoint)
        
        debugLog("🖱️ Mouse down at: (\(clickedRow), \(clickedColumn))")
        
        // Check if clicking the same row
        let isSameRow = (clickedRow == selectedRow && clickedRow >= 0)
        
        setClickedColumn(clickedColumn)
        // If same row clicked, force refresh
        if isSameRow {
            debugLog("🔄 Same row clicked - refreshing selection")
            refreshSelectedRowByReselection()
        }
        
        super.mouseDown(with: event)
    }
    
    // Helper to store clicked column (since NSTableView doesn't always track this reliably)
    private var storedClickedColumn: Int = -1
    
    private func setClickedColumn(_ column: Int) {
        storedClickedColumn = column
    }
    
    override var clickedColumn: Int {
        // Return stored column if available, otherwise use built-in
        if storedClickedColumn >= 0 {
            return storedClickedColumn
        }
        
        return super.clickedColumn
    }
    
    // MARK: - Edit Mode
    func enterEditModeForCell(row: Int, column: Int) {
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
    
    override func editColumn(_ column: Int, row: Int, with event: NSEvent?, select: Bool) {
        debugLog("✏️ editColumn called for (\(row), \(column)) with select: \(select)")
        
        // Validate bounds
        guard row >= 0 && row < numberOfRows && column >= 0 && column < numberOfColumns else {
            super.editColumn(column, row: row, with: event, select: select)
            return
        }
        
        // Select the row using built-in selection
        if select {
            selectRowIndexes(IndexSet(integer: row), byExtendingSelection: false)
        }
        
        // Try to use custom TextCellView
        if let cellView = view(atColumn: column, row: row, makeIfNecessary: false) as? TextCellView {
            cellView.enterEditMode()
            scrollRowToVisible(row)
            scrollColumnToVisible(column)
        } else {
            // Fall back to default behavior
            super.editColumn(column, row: row, with: event, select: select)
        }
    }
    
    // MARK: - Selection Management
    override var acceptsFirstResponder: Bool {
        return true
    }
    
    /// Gets the currently selected cell coordinates
    func getCurrentSelectedCell() -> (row: Int, column: Int)? {
        return currentCellLocation
    }
    
    /// Programmatically select a specific cell
    func selectCell(row: Int, column: Int) {
        guard row >= 0 && row < numberOfRows && column >= 0 && column < numberOfColumns else {
            return
        }
        
        // Use built-in row selection
        selectRowIndexes(IndexSet(integer: row), byExtendingSelection: false)
        
        // Store column for later retrieval
        storedClickedColumn = column
        
        // Notify delegate
        cellSelectionDelegate?.tableView(self, didSelectCellAt: row, column: column)
        
        // Scroll to make visible
        scrollRowToVisible(row)
        scrollColumnToVisible(column)
    }
    
    /// Clears all selection
    func clearAllSelection() {
        debugLog("🧹 Clearing all table selection state")
        selectRowIndexes(IndexSet(), byExtendingSelection: false)
        storedClickedColumn = -1
    }
    
    /// Get column index for identifier
    func columnIndex(for identifier: String) -> Int {
        for (index, column) in tableColumns.enumerated() {
            if column.identifier.rawValue == identifier {
                return index
            }
        }
        return -1
    }
}

// MARK: - Cell Selection Delegate Protocol
protocol TableViewCellSelectionDelegate: AnyObject {
    func tableView(_ tableView: NSTableView, didSelectCellAt row: Int, column: Int)
}
