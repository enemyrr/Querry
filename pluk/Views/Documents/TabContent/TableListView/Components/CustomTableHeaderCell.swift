//
//  CustomTableHeaderCell.swift
//  Pluk
//
//  Created by Fauzaan on 6/4/25.
//

import Foundation
import AppKit

class CustomTableHeaderCell: NSTableHeaderCell {
    private var customView: NSView?
    private var titleLabel: NSTextField?
    private var iconImageView: NSImageView?
    private var sortButton: NSButton?
    
    // Sort state
    private var isActiveSortColumn = false
    private var sortAscending = true
    
    override init(textCell string: String) {
        super.init(textCell: string)
    }
    
    required init(coder: NSCoder) {
        super.init(coder: coder)
    }
    
    private func setupCustomView() {
        // Create container view
        customView = NSView()
        customView?.wantsLayer = true
        customView?.layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor
        
        // Create title label
        titleLabel = NSTextField()
        titleLabel?.isEditable = false
        titleLabel?.isBordered = false
        titleLabel?.backgroundColor = .clear
        titleLabel?.font = NSFont.systemFont(ofSize: 12, weight: .semibold)
        titleLabel?.alignment = .left
        
        if let titleLabel = titleLabel {
            customView?.addSubview(titleLabel)
        }
    }
    
    func configure(title: String, icon: NSImage? = nil, showSortButton: Bool = true) {
        titleLabel?.stringValue = title
        iconImageView?.image = icon
        iconImageView?.isHidden = icon == nil
        sortButton?.isHidden = !showSortButton
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
    
    override func drawFocusRingMask(withFrame cellFrame: NSRect, in controlView: NSView) {
        drawCustomBackground(in: cellFrame)
    }
    
    override func drawInterior(withFrame cellFrame: NSRect, in controlView: NSView) {
        drawCustomBackground(in: cellFrame)
    }
    
    override func draw(withExpansionFrame cellFrame: NSRect, in view: NSView) {
        drawCustomBackground(in: cellFrame)
    }
    
    override func drawingRect(forBounds rect: NSRect) -> NSRect {
        return rect
    }
    
    override func draggingImageComponents(withFrame frame: NSRect, in view: NSView) -> [NSDraggingImageComponent] {
        drawCustomBackground(in: frame)
        return []
    }
    
    override func drawSortIndicator(withFrame cellFrame: NSRect, in controlView: NSView, ascending: Bool, priority: Int) {
        drawCustomBackground(in: cellFrame)
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
