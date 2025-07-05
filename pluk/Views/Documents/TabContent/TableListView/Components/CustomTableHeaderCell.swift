//
//  CustomTableHeaderCell.swift
//  Pluk
//
//  Created by Fauzaan on 6/4/25.
//

import Foundation
import AppKit

class CustomTableHeaderCell: NSTableHeaderCell {
    private var titleLabel: NSTextField?
    
    // Sort state
    private var isActiveSortColumn = false
    private var sortAscending = true
    
    override init(textCell string: String) {
        super.init(textCell: string)
    }
    
    required init(coder: NSCoder) {
        super.init(coder: coder)
    }
    
    func configure(title: String) {
        titleLabel?.stringValue = title
    }
    
    override func draw(withFrame cellFrame: NSRect, in controlView: NSView) {
        drawCustomBackground(in: cellFrame)
        drawTitle(in: cellFrame, icon: getSortIcon())
    }
    
    private func getSortIcon() -> NSImage? {
        let symbolName: String
        if isActiveSortColumn {
            symbolName = sortAscending ? "chevron.up" : "chevron.down"
            
            // Create symbol configuration with secondary color
            let config = NSImage.SymbolConfiguration(pointSize: 11, weight: .regular)
                .applying(.init(hierarchicalColor: .secondaryLabelColor))
            
            return NSImage(systemSymbolName: symbolName, accessibilityDescription: nil)?
                .withSymbolConfiguration(config)
        }
        
        return nil
    }
    
    
    private func drawTitle(in rect: NSRect, icon: NSImage?) {
        var textRect = rect.insetBy(dx: 2, dy: 0)
        textRect.size.width -= 20 // Space for sort indicator
        
        // Create text attributes
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineBreakMode = .byTruncatingTail
        paragraphStyle.alignment = self.alignment
        
        let textColor = NSColor.secondaryLabelColor
        let fontWeight: NSFont.Weight = .regular
        
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 12, weight: fontWeight),
            .foregroundColor: textColor,
            .paragraphStyle: paragraphStyle,
        ]
        
        // Draw the text
        let attributedTitle = NSAttributedString(string: title, attributes: attributes)
        let titleSize = attributedTitle.size()
        let titleRect = NSRect(
            x: textRect.minX + 6,
            y: textRect.midY - titleSize.height / 2,
            width: textRect.width,
            height: titleSize.height
        )
        
        attributedTitle.draw(in: titleRect)
        
        if let icon = icon {
            let naturalSize = icon.size
            let maxIconHeight = rect.height * 0.25
            
            let scale = maxIconHeight / naturalSize.height
            let scaledWidth = naturalSize.width * scale
            let scaledHeight = naturalSize.height * scale
            
            let iconRect = NSRect(
                x: rect.maxX - scaledWidth - 8,
                y: rect.midY - scaledHeight / 2,
                width: scaledWidth,
                height: scaledHeight
            )
            
            icon.draw(in: iconRect)
        }
    }
    
    private func drawCustomBackground(in frame: NSRect) {
        frame.fill(using: .clear)
        
        NSColor.separatorColor.setStroke()
        
        let verticalInset: CGFloat = 6
        let rightBorder = NSBezierPath()
        rightBorder.move(to: NSPoint(x: frame.maxX - 0.5, y: frame.minY + verticalInset))
        rightBorder.line(to: NSPoint(x: frame.maxX - 0.5, y: frame.maxY - verticalInset))
        rightBorder.lineWidth = 1
        rightBorder.stroke()
        
        let bottomBorder = NSBezierPath()
        bottomBorder.move(to: NSPoint(x: frame.minX, y: frame.maxY - 0.5))
        bottomBorder.line(to: NSPoint(x: frame.maxX, y: frame.maxY - 0.5))
        bottomBorder.lineWidth = 2
        bottomBorder.stroke()
    }
    
    
    
    override func cellSize(forBounds rect: NSRect) -> NSSize {
        let font = NSFont.systemFont(ofSize: 12, weight: .medium)
        let attributes = [NSAttributedString.Key.font: font]
        let titleSize = (title as NSString).size(withAttributes: attributes)
        
        // Add padding for your custom drawing
        let width = titleSize.width + 40 // Space for borders, icons, etc.
        let height = max(titleSize.height + 8, 32) // Minimum height
        
        return NSSize(width: width, height: height)
    }
    
    
    override func highlight(_ flag: Bool, withFrame cellFrame: NSRect, in controlView: NSView) {
        drawCustomBackground(in: cellFrame)
        drawTitle(in: cellFrame, icon: getSortIcon())
    }
    
    func updateSortIndicator(isActive: Bool, ascending: Bool) {
        isActiveSortColumn = isActive
        sortAscending = ascending
        
        // Trigger redraw
        if let controlView = controlView {
            controlView.setNeedsDisplay(controlView.bounds)
        }
    }
}
