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
    private var fieldType: String?
    
    // Sort state
    private var isActiveSortColumn = false
    private var sortAscending = true
    
    override init(textCell string: String) {
        super.init(textCell: string)
    }
    
    required init(coder: NSCoder) {
        super.init(coder: coder)
    }
    
    func configure(title: String, fieldType: String? = nil) {
        titleLabel?.stringValue = title
        self.fieldType = fieldType
    }
    
    override func draw(withFrame cellFrame: NSRect, in controlView: NSView) {
        drawCustomBackground(in: cellFrame)
        
        // Only draw content if this is a valid column header (not empty space)
        if !title.isEmpty {
            let typeIconData = getDataTypeIcon()
            drawTitle(in: cellFrame, sortIcon: getSortIcon(), typeIconData: typeIconData)
        }
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
    
    private func getDataTypeIcon() -> (icon: NSImage, size: CGFloat)? {
        guard let fieldType = fieldType else { return nil }
        
        let symbolName: String
        let customSize: CGFloat
        
        switch fieldType.lowercased() {
        case let type where type.hasPrefix("text") || type.hasPrefix("character") || type.contains("varchar"):
            symbolName = "textformat.alt"
            customSize = 10
        case let type where type.contains("int"):
            symbolName = "number"
            customSize = 12
        case "numeric", "decimal", "real", "double precision", "float", "money":
            symbolName = "dollarsign"
            customSize = 13
        case let type where type.hasPrefix("unknown"):
            symbolName = "tag"
            customSize = 14
        case "bool", "boolean":
            symbolName = "switch.2"
            customSize = 14
        case "xml":
            symbolName = "ellipsis.curlybraces"
            customSize = 13
        case let type where type.hasPrefix("timestamp") || type.hasPrefix("date"):
            symbolName = "calendar"
            customSize = 13
        case "time", "time with time zone", "time without time zone", "timez":
            symbolName = "clock"
            customSize = 14
        case "uuid":
            symbolName = "barcode"
            customSize = 12
        case "json", "jsonb":
            symbolName = "curlybraces"
            customSize = 13
        case "array":
            symbolName = "square.stack"
            customSize = 13
        case "bytea":
            symbolName = "doc.text"
            customSize = 12
        default:
            symbolName = "questionmark.circle"
            customSize = 14
        }
        
        let config = NSImage.SymbolConfiguration(pointSize: 11, weight: .regular)
            .applying(.init(hierarchicalColor: .tertiaryLabelColor))
        
        guard let icon = NSImage(systemSymbolName: symbolName, accessibilityDescription: fieldType)?
            .withSymbolConfiguration(config) else { return nil }
        
        return (icon, customSize)
    }
    
    private func drawTitle(in rect: NSRect, sortIcon: NSImage?, typeIconData: (icon: NSImage, size: CGFloat)?) {
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
        
        // Calculate space needed for icons
        var iconSpace: CGFloat = 0
        let currentX: CGFloat = textRect.minX + 6
        
        // Draw type icon
        if let typeIconData = typeIconData {
            let typeIcon = typeIconData.icon
            let targetHeight = typeIconData.size
            let naturalSize = typeIcon.size
            let scale = targetHeight / naturalSize.height
            let scaledWidth = naturalSize.width * scale
            let scaledHeight = targetHeight
            
            let iconRect = NSRect(
                x: currentX,
                y: rect.midY - scaledHeight / 2,
                width: scaledWidth,
                height: scaledHeight
            )
            
            typeIcon.draw(in: iconRect)
            iconSpace += scaledWidth + 4
        }
        
        // Draw title (offset if there's a type icon)
        let titleRect = NSRect(
            x: textRect.minX + 6 + iconSpace,
            y: textRect.midY - titleSize.height / 2,
            width: textRect.width - iconSpace,
            height: titleSize.height
        )
        
        attributedTitle.draw(in: titleRect)
        
        if let sortIcon = sortIcon {
            let naturalSize = sortIcon.size
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
            
            sortIcon.draw(in: iconRect)
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
        
        // Add padding for your custom drawing including type icon
        let width = titleSize.width + 60 // Space for borders, type icon, sort icon, etc.
        let height = max(titleSize.height + 8, 32) // Minimum height
        
        return NSSize(width: width, height: height)
    }
    
    
    override func highlight(_ flag: Bool, withFrame cellFrame: NSRect, in controlView: NSView) {
        drawCustomBackground(in: cellFrame)
        
        // Only draw content if this is a valid column header (not empty space)
        if !title.isEmpty {
            let typeIconData = getDataTypeIcon()
            drawTitle(in: cellFrame, sortIcon: getSortIcon(), typeIconData: typeIconData)
        }
    }
    
    func updateSortIndicator(isActive: Bool, ascending: Bool) {
        isActiveSortColumn = isActive
        sortAscending = ascending
        
        // Trigger redraw
        if let controlView = controlView {
            controlView.setNeedsDisplay(controlView.bounds)
        }
    }
    
    // MARK: - Tooltip Support
    func getFieldType() -> String? {
        return fieldType
    }
}
