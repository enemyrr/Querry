//
//  CustomTableRowView.swift
//  Pluk
//
//  Created by Fauzaan on 6/4/25.
//

import Foundation
import AppKit

class CustomTableRowView: NSTableRowView {
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
    
    override func drawSelection(in dirtyRect: NSRect) {
        guard let tableView = self.superview as? NSTableView else {
            let customColor = NSColor.controlColor.withAlphaComponent(0.08)
            customColor.setFill()
            bounds.fill()
            return
        }
        
        let currentRowIndex = tableView.row(for: self)
        let selectedColumns = tableView.selectedColumnIndexes
        let selectedRows = tableView.selectedRowIndexes
        
        if selectedRows.contains(currentRowIndex) && !selectedColumns.isEmpty {
            drawCellSelection(tableView: tableView, selectedColumns: selectedColumns)
        } else if selectedRows.contains(currentRowIndex) {
            drawFullRowSelection()
        }
    }
    
    private func drawCellSelection(tableView: NSTableView, selectedColumns: IndexSet) {
        for columnIndex in selectedColumns {
            guard columnIndex < tableView.numberOfColumns else { continue }
            
            let cellRect = calculateCellRect(for: columnIndex, in: tableView)
            
            NSColor.red.withAlphaComponent(0.3).setFill()
            cellRect.fill()
            
            NSColor.controlAccentColor.withAlphaComponent(0.8).setStroke()
            let borderPath = NSBezierPath(rect: cellRect)
            borderPath.lineWidth = 2.0
            borderPath.stroke()
        }
    }
    
    private func calculateCellRect(for columnIndex: Int, in tableView: NSTableView) -> NSRect {
        let columnRect = tableView.rect(ofColumn: columnIndex)
        return NSRect(
            x: columnRect.origin.x,
            y: 0,
            width: columnRect.width,
            height: bounds.height
        )
    }
    
    private func drawFullRowSelection() {
        let customColor = NSColor.controlColor.withAlphaComponent(0.08)
        customColor.setFill()
        
        // Apply bottom padding to the selection rectangle
        let paddedRect = NSRect(
            x: bounds.origin.x,
            y: bounds.origin.y,
            width: bounds.width,
            height: bounds.height - 1
        )
        paddedRect.fill()
    }
    
    // Prepare for reuse - reset any custom state
    override func prepareForReuse() {
        super.prepareForReuse()
    }
}
