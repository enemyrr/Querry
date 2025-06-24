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
    
    override func keyDown(with event: NSEvent) {
        // Check for Cmd+Z (undo)
        if event.modifierFlags.contains(.command) && event.keyCode == 6 { // 'z' key
            if let undoHandler = undoHandler, undoHandler() {
                // Undo was handled successfully
                return
            }
        }
        
        // Let the superclass handle other key events
        super.keyDown(with: event)
    }
    
    override var acceptsFirstResponder: Bool {
        return true
    }
    
    private func drawCellSelection(tableView: NSTableView, selectedColumns: IndexSet) {
        for columnIndex in selectedColumns {
            guard columnIndex < tableView.numberOfColumns else { continue }
            
            let columnRect = tableView.rect(ofColumn: columnIndex)
            let cellRect = NSRect(
                x: columnRect.origin.x,
                y: 0,
                width: columnRect.width,
                height: rowHeight  // Adjust for your padding
            )
            
            
            // CUSTOMIZE THESE VALUES:
            NSColor.systemBlue.withAlphaComponent(0.2).setFill()  // Background color
            cellRect.fill()
            
            // Optional border
            NSColor.systemBlue.withAlphaComponent(0.8).setStroke()
            let borderPath = NSBezierPath(rect: cellRect)
            borderPath.lineWidth = 1.0  // Border thickness
            borderPath.stroke()
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
