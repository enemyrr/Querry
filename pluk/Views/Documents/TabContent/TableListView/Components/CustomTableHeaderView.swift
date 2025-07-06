//
//  CustomTableHeaderView.swift
//  Pluk
//
//  Created by Assistant on 7/5/25.
//

import AppKit

class CustomTableHeaderView: NSTableHeaderView {
    private var trackingArea: NSTrackingArea?
    private var currentHoveredColumn: Int = -1
    
    override func awakeFromNib() {
        super.awakeFromNib()
        setupTrackingArea()
    }
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupTrackingArea()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupTrackingArea()
    }
    
    private func setupTrackingArea() {
        // Remove existing tracking area
        if let trackingArea = trackingArea {
            removeTrackingArea(trackingArea)
        }
        
        // Create new tracking area
        let options: NSTrackingArea.Options = [.mouseEnteredAndExited, .mouseMoved, .activeInKeyWindow]
        trackingArea = NSTrackingArea(
            rect: bounds,
            options: options,
            owner: self,
            userInfo: nil
        )
        
        if let trackingArea = trackingArea {
            addTrackingArea(trackingArea)
        }
    }
    
    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        setupTrackingArea()
    }
    
    override func mouseEntered(with event: NSEvent) {
        super.mouseEntered(with: event)
        updateTooltip(with: event)
    }
    
    override func mouseExited(with event: NSEvent) {
        super.mouseExited(with: event)
        TooltipManager.shared.hideTooltip()
        currentHoveredColumn = -1
    }
    
    override func mouseMoved(with event: NSEvent) {
        super.mouseMoved(with: event)
        updateTooltip(with: event)
    }
    
    private func updateTooltip(with event: NSEvent) {
        guard let tableView = tableView else {
            TooltipManager.shared.hideTooltip()
            return
        }
        
        let locationInView = convert(event.locationInWindow, from: nil)
        let columnIndex = column(at: locationInView)
        
        if columnIndex >= 0 && columnIndex < tableView.numberOfColumns {
            let column = tableView.tableColumns[columnIndex]
            if let headerCell = column.headerCell as? CustomTableHeaderCell {
                // Get the header rect for this column
                let headerRect = headerRect(ofColumn: columnIndex)
                
                // Check if we're hovering over the type icon
                if let fieldType = headerCell.getFieldType() {
                    // Calculate where the type icon should be based on the header cell's layout
                    // The icon is at textRect.minX + 6, and textRect is rect.insetBy(dx: 2, dy: 0)
                    // So icon starts at headerRect.minX + 2 + 6 = headerRect.minX + 8
                    let iconX = headerRect.minX + 8
                    let iconSize: CGFloat = 20 // Approximate size including padding
                    
                    let iconRect = NSRect(
                        x: iconX,
                        y: headerRect.minY,
                        width: iconSize,
                        height: headerRect.height
                    )
                    
                    if iconRect.contains(locationInView) {
                        if currentHoveredColumn != columnIndex {
                            // Show tooltip below the icon, centered
                            // Calculate the icon center position
                            let iconCenterX = iconRect.midX
                            // Position tooltip below the header (at the bottom of the header view)
                            let tooltipY = self.bounds.maxY
                            
                            let tooltipPoint = NSPoint(
                                x: iconCenterX,
                                y: tooltipY
                            )
                            TooltipManager.shared.showTooltip(fieldType, at: tooltipPoint, relativeTo: self)
                            currentHoveredColumn = columnIndex
                        }
                        return
                    }
                }
            }
        }
        
        // Not hovering over any type icon
        TooltipManager.shared.hideTooltip()
        currentHoveredColumn = -1
    }
}
