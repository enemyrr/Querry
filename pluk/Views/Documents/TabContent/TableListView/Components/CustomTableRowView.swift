//
//  CustomTableRowView.swift
//  Pluk
//
//  Created by Fauzaan on 6/4/25.
//

import Foundation
import AppKit

class CustomTableRowView: NSTableRowView {
    override func drawSelection(in dirtyRect: NSRect) {
        guard let tableView = self.superview as? CustomTableView else {
            // Fallback for non-custom table views
            drawFullRowSelection()
            return
        }
        
        let currentRowIndex = tableView.row(for: self)
        let selectedRows = tableView.selectedRowIndexes
        
        // Check if this row is selected
        if selectedRows.contains(currentRowIndex) {
            // Get the current active cell location
            if let cellLocation = tableView.getCurrentSelectedCell(),
               cellLocation.row == currentRowIndex {
                // Draw cell-specific selection
                drawCellSelection(for: cellLocation.column, in: tableView)
            } else {
                // Draw full row selection as fallback
                drawFullRowSelection()
            }
        }
    }
    
    private func drawCellSelection(for columnIndex: Int, in tableView: NSTableView) {
        // If columnIndex is -1, just draw row selection
        if columnIndex == -1 {
            drawFullRowSelection()
            return
        }
        
        guard columnIndex >= 0 && columnIndex < tableView.numberOfColumns else {
            drawFullRowSelection()
            return
        }
        
        drawFullRowSelection()
        
        let cellRect = calculateCellRect(for: columnIndex, in: tableView)
        
        // Draw cell border
        let borderColor = NSColor.controlAccentColor.withAlphaComponent(0.6)
        borderColor.setStroke()
        
        let borderPath = NSBezierPath(rect: cellRect.insetBy(dx: 0.5, dy: 0.5))
        borderPath.lineWidth = 1.5
        borderPath.stroke()
        
        // Optional: Add subtle inner glow effect
        let innerGlowColor = NSColor.controlAccentColor.withAlphaComponent(0.1)
        innerGlowColor.setFill()
        let innerRect = cellRect.insetBy(dx: 1, dy: 1)
        innerRect.fill()
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
        // Subtle row selection color with different colors for light/dark theme
        let isDarkMode = NSApp.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        let customColor = isDarkMode
            ? NSColor.controlColor.withAlphaComponent(0.08)
            : NSColor.controlAccentColor.withAlphaComponent(0.08)
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
}
