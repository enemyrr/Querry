//
//  NSTextFieldCell.swift
//  Pluk
//
//  Created by Fauzaan on 6/24/25.
//

import Foundation
import AppKit

// MARK: - Custom NSTextFieldCell with internal padding
class PaddedTextFieldCell: NSTextFieldCell {
    let textPadding: NSEdgeInsets = NSEdgeInsets(top: 2, left: 8, bottom: 2, right: 8)
    
    override init(textCell string: String) {
        super.init(textCell: string)
        setupCell()
    }
    
    required init(coder: NSCoder) {
        super.init(coder: coder)
        setupCell()
    }
    
    private func setupCell() {
        lineBreakMode = .byTruncatingTail
        wraps = false
        isScrollable = false
        usesSingleLineMode = true
    }
    
    // Rest of your existing methods remain the same...
    override func titleRect(forBounds rect: NSRect) -> NSRect {
        var paddedRect = super.titleRect(forBounds: rect)
        paddedRect.origin.x += textPadding.left
        paddedRect.origin.y += textPadding.top
        paddedRect.size.width -= (textPadding.left + textPadding.right)
        paddedRect.size.height -= (textPadding.top + textPadding.bottom)
        return paddedRect
    }
    
    override func edit(withFrame rect: NSRect, in controlView: NSView, editor textObj: NSText, delegate: Any?, event: NSEvent?) {
        var paddedRect = rect
        paddedRect.origin.x += textPadding.left
        paddedRect.origin.y += textPadding.top
        paddedRect.size.width -= (textPadding.left + textPadding.right)
        paddedRect.size.height -= (textPadding.top + textPadding.bottom)
        
        super.edit(withFrame: paddedRect, in: controlView, editor: textObj, delegate: delegate, event: event)
    }
    
    override func select(withFrame rect: NSRect, in controlView: NSView, editor textObj: NSText, delegate: Any?, start selStart: Int, length selLength: Int) {
        var paddedRect = rect
        paddedRect.origin.x += textPadding.left - 2
        paddedRect.origin.y += textPadding.top
        paddedRect.size.width -= (textPadding.left + textPadding.right) + 2
        paddedRect.size.height -= (textPadding.top + textPadding.bottom)
        
        super.select(withFrame: paddedRect, in: controlView, editor: textObj, delegate: delegate, start: selStart, length: selLength)
    }
    
    override func drawInterior(withFrame cellFrame: NSRect, in controlView: NSView) {
        var paddedRect = titleRect(forBounds: cellFrame)
        
        // Check if we're in edit mode but not active
        if let textField = controlView as? NSTextField,
           textField.isEditable && textField.window?.firstResponder != textField {
            
            paddedRect.origin.x -= 2
            paddedRect.size.width += 2  // Compensate width to maintain right edge
            
            // Custom drawing for edit mode (non-active)
            // You can modify appearance here - different background, border, etc.
            
//#if DEBUG
//            NSColor.controlAccentColor.withAlphaComponent(0.1).set()
//            paddedRect.fill()
//            NSColor.controlAccentColor.withAlphaComponent(0.3).set()
//            paddedRect.frame()
//#endif
        }
        
        super.drawInterior(withFrame: paddedRect, in: controlView)
    }
}

// MARK: - NSTextField
public extension NSTextField {
    func configureForTableCell() {
        // Content and appearance
        stringValue = ""
        textColor = .disabledControlTextColor
        font = .systemFont(ofSize: 12)
        
        // Disable expensive features for table cells
        isEditable = false  // Will be enabled on click
        isSelectable = true
        isBordered = false
        backgroundColor = .clear
        drawsBackground = true  // Don't draw background for better
        
        // Optimize text rendering
        allowsEditingTextAttributes = false
        importsGraphics = false
        
        isAutomaticTextCompletionEnabled = false
        allowsCharacterPickerTouchBarItem = false
        allowsDefaultTighteningForTruncation = false
        
        placeholderString = "(EMPTY)"
        
        isBordered = false
        isBezeled = false
        bezelStyle = .squareBezel  // Reset bezel style
        focusRingType = .none  // Disable the white focus ring
    }
}
