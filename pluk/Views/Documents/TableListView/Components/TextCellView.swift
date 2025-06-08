//
//  TextCellView.swift
//  Pluk
//
//  Created by Fauzaan on 6/4/25.
//

import Foundation
import AppKit
import PostgresNIO

class TextCellView: NSView {
    private var textField: NSTextField!
    private var hoverBorderView: NSView?
    private var selectedBorderView: NSView?
    private var trackingArea: NSTrackingArea?
    private var rightBorderView: NSView?
    private var bottomBorderView: NSView?
    
    private static weak var currentlyHoveredCell: TextCellView?
    private static weak var currentlySelectedCell: TextCellView?
    
    private var isSelected: Bool = false
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
         setupTextField()
//         setupHoverBorder()
//         setupSelectedBorder()
//         setupTracking()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupTextField()
//         setupHoverBorder()
//         setupSelectedBorder()
//         setupTracking()
    }
    
    private func setupTextField() {
        // Use the most lightweight initializer
            textField = NSTextField(frame: .zero)
            
            // Batch configure properties to minimize notifications/updates
            textField.configureForTableCell()
            
            // Add to view hierarchy before setting up constraints (better for layout)
            addSubview(textField)
            
            // Disable autoresizing mask translation once
            textField.translatesAutoresizingMaskIntoConstraints = false
            
            // Create and activate constraints in one call (more efficient)
            setupTextFieldConstraints()
    }
    
    private func setupTextFieldConstraints() {
        // Pre-calculate constants to avoid repeated calculations
        let leadingConstant: CGFloat = 4
        let trailingConstant: CGFloat = -4
        
        // Create constraints array and activate all at once
        NSLayoutConstraint.activate([
            textField.leadingAnchor.constraint(equalTo: leadingAnchor, constant: leadingConstant),
            textField.trailingAnchor.constraint(equalTo: trailingAnchor, constant: trailingConstant),
            textField.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])
    }
    
    private func setupHoverBorder() {
        hoverBorderView = NSView()
        hoverBorderView?.wantsLayer = true
        hoverBorderView?.layer?.borderWidth = 1.0
        hoverBorderView?.layer?.borderColor = NSColor.alternateSelectedControlTextColor.withAlphaComponent(0.5).cgColor
        hoverBorderView?.layer?.cornerRadius = 0.0
        hoverBorderView?.isHidden = true
        
        addSubview(hoverBorderView!)
        hoverBorderView?.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            hoverBorderView!.leadingAnchor.constraint(equalTo: leadingAnchor, constant: -8),
            hoverBorderView!.trailingAnchor.constraint(equalTo: trailingAnchor, constant: 8),
            hoverBorderView!.topAnchor.constraint(equalTo: topAnchor, constant: 1),
            hoverBorderView!.bottomAnchor.constraint(equalTo: bottomAnchor, constant: 0)
        ])
    }
    
    private func setupSelectedBorder() {
        selectedBorderView = NSView()
        selectedBorderView?.wantsLayer = true
        selectedBorderView?.layer?.borderWidth = 1.0
        selectedBorderView?.layer?.borderColor = NSColor.alternateSelectedControlTextColor.withAlphaComponent(0.5).cgColor
        selectedBorderView?.layer?.cornerRadius = 0.0
        selectedBorderView?.isHidden = true
        
        addSubview(selectedBorderView!)
        selectedBorderView?.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            selectedBorderView!.leadingAnchor.constraint(equalTo: leadingAnchor, constant: -8),
            selectedBorderView!.trailingAnchor.constraint(equalTo: trailingAnchor, constant: 8),
            selectedBorderView!.topAnchor.constraint(equalTo: topAnchor, constant: 1),
            selectedBorderView!.bottomAnchor.constraint(equalTo: bottomAnchor, constant: 0)
        ])
    }
    
    private func setupTracking() {
        let options: NSTrackingArea.Options = [.mouseEnteredAndExited, .activeAlways]
        trackingArea = NSTrackingArea(rect: bounds, options: options, owner: self, userInfo: nil)
        addTrackingArea(trackingArea!)
    }
    
//    override func updateTrackingAreas() {
//        super.updateTrackingAreas()
//        
//        if let trackingArea = trackingArea {
//            removeTrackingArea(trackingArea)
//        }
//        
//        let options: NSTrackingArea.Options = [.mouseEnteredAndExited, .activeAlways]
//        trackingArea = NSTrackingArea(rect: bounds, options: options, owner: self, userInfo: nil)
//        addTrackingArea(trackingArea!)
//    }
    
//    override func mouseEntered(with event: NSEvent) {
//        super.mouseEntered(with: event)
//        
//        // Clear any previously hovered cell (but don't affect selected state)
//        if let previousHovered = TextCellView.currentlyHoveredCell, previousHovered !== self {
//            previousHovered.hideHoverBorder()
//        }
//        
//        // Set this cell as the currently hovered one
//        TextCellView.currentlyHoveredCell = self
//        
//        // Show hover only if not already selected
//        if !isSelected {
//            showHoverBorder()
//        }
//    }
//    
//    override func mouseExited(with event: NSEvent) {
//        super.mouseExited(with: event)
//        
//        // Only hide hover if this cell is currently the hovered one and not selected
//        if TextCellView.currentlyHoveredCell === self && !isSelected {
//            TextCellView.currentlyHoveredCell = nil
//            hideHoverBorder()
//        }
//    }
//    
//    override func mouseDown(with event: NSEvent) {
//        super.mouseDown(with: event)
//        
//        // Get the previously selected cell for animation
//        let previousCell = TextCellView.currentlySelectedCell
//        
//        // Set this cell as selected immediately (for state management)
//        TextCellView.currentlySelectedCell = self
//        
//        // Animate the transition
//        if let previousCell = previousCell, previousCell !== self {
//            animateSelectionTransition(from: previousCell, to: self)
//        } else {
//            // No previous selection, just show normally
//            setSelected(true)
//        }
//        
//        // Find the table view and get row/column info
//        if let tableView = findTableView() {
//            let row = tableView.row(for: self)
//            let column = tableView.column(for: self)
//            print("Cell selected at row: \(row), column: \(column)")
//        }
//    }
    
    private func findTableView() -> NSTableView? {
        var view: NSView? = self.superview
        while view != nil {
            if let tableView = view as? NSTableView {
                return tableView
            }
            view = view?.superview
        }
        return nil
    }
    
    private func animateSelectionTransition(from fromCell: TextCellView, to toCell: TextCellView) {
        guard let commonSuperview = findCommonSuperview(between: fromCell, and: toCell) else {
            // Fallback to normal animation if no common superview found
            fromCell.setSelected(false)
            toCell.setSelected(true)
            return
        }
        
        // Get the frames of both cells in the common superview coordinate system
        let fromFrame = commonSuperview.convert(fromCell.bounds, from: fromCell)
        let toFrame = commonSuperview.convert(toCell.bounds, from: toCell)
        
        // Create a temporary animated border view
        let animatedBorder = NSView()
        animatedBorder.wantsLayer = true
        animatedBorder.layer?.borderWidth = 2.0
        animatedBorder.layer?.borderColor = NSColor.alternateSelectedControlTextColor.withAlphaComponent(0.5).cgColor
        animatedBorder.layer?.cornerRadius = 0.0
        animatedBorder.layer?.backgroundColor = NSColor.clear.cgColor
        
        // Position it at the source cell initially (with the same insets as selected border)
        let startFrame = NSRect(
            x: fromFrame.origin.x - 8,
            y: fromFrame.origin.y - 1,
            width: fromFrame.width + 16,
            height: fromFrame.height + 1
        )
        
        let endFrame = NSRect(
            x: toFrame.origin.x - 8,
            y: toFrame.origin.y - 1,
            width: toFrame.width + 16,
            height: toFrame.height + 1
        )
        
        animatedBorder.frame = startFrame
        commonSuperview.addSubview(animatedBorder)
        
        // Hide both cells' selection borders during animation
        fromCell.selectedBorderView?.isHidden = true
        toCell.selectedBorderView?.isHidden = true
        
        // Animate the transition
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.15
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            context.allowsImplicitAnimation = true
            
            // Animate frame
            animatedBorder.animator().frame = endFrame
            
            // Add a subtle scale effect
            animatedBorder.layer?.transform = CATransform3DMakeScale(1.05, 1.05, 1.0)
            animatedBorder.animator().layer?.transform = CATransform3DIdentity
            
        }) {
            // Animation completed
            animatedBorder.removeFromSuperview()
            
            // Update the actual selection states
            fromCell.setSelected(false)
            toCell.setSelected(true)
        }
    }
    
    private func findCommonSuperview(between view1: NSView, and view2: NSView) -> NSView? {
        var superview1: NSView? = view1.superview
        
        while superview1 != nil {
            var superview2: NSView? = view2.superview
            
            while superview2 != nil {
                if superview1 === superview2 {
                    return superview1
                }
                superview2 = superview2?.superview
            }
            superview1 = superview1?.superview
        }
        
        return nil
    }
    
    private func showHoverBorder() {
        hoverBorderView?.isHidden = false
        
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.15
            context.allowsImplicitAnimation = true
            hoverBorderView?.alphaValue = 1.0
        }
    }
    
    private func hideHoverBorder() {
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.15
            context.allowsImplicitAnimation = true
            hoverBorderView?.alphaValue = 0.0
        } completionHandler: {
            self.hoverBorderView?.isHidden = true
            self.hoverBorderView?.alphaValue = 1.0 // Reset for next time
        }
    }
    
    private func setSelected(_ selected: Bool) {
        isSelected = selected
        
        if selected {
            hideHoverBorder() // Hide hover when selected
            selectedBorderView?.isHidden = false
            
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.15
                context.allowsImplicitAnimation = true
                selectedBorderView?.alphaValue = 1.0
            }
        } else {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.15
                context.allowsImplicitAnimation = true
                selectedBorderView?.alphaValue = 0.0
            } completionHandler: {
                self.selectedBorderView?.isHidden = true
                self.selectedBorderView?.alphaValue = 1.0
            }
        }
    }
    
    // Public method to programmatically select/deselect
    func setSelectedState(_ selected: Bool, animated: Bool = true) {
        if selected {
            let previousCell = TextCellView.currentlySelectedCell
            TextCellView.currentlySelectedCell = self
            
            if animated && previousCell != nil && previousCell !== self {
                animateSelectionTransition(from: previousCell!, to: self)
            } else {
                previousCell?.setSelected(false)
                setSelected(true)
            }
        } else if TextCellView.currentlySelectedCell === self {
            TextCellView.currentlySelectedCell = nil
            setSelected(selected)
        }
    }
    
    private func formatValueForDisplay(_ value: Any?) -> String? {
        guard let value = value else { return "NULL" }
        
        if let date = value as? Date {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            formatter.timeStyle = .short
            return formatter.string(from: date)
        } else if let bool = value as? Bool {
            return bool ? "true" : "false"
        } else {
            return String(describing: value)
        }
    }

    private func decodeValue(from cell: PostgresCell) throws -> Any? {
        guard cell.bytes != nil else { return nil }
        
        switch cell.dataType {
        case .bool:
            return try cell.decode(Bool.self)
        case .int2:
            return try cell.decode(Int16.self)
        case .int4:
            return try cell.decode(Int32.self)
        case .int8:
            return try cell.decode(Int64.self)
        case .float4:
            return try cell.decode(Float.self)
        case .float8:
            return try cell.decode(Double.self)
        case .text, .varchar, .char:
            return try cell.decode(String.self)
        case .timestamp, .timestamptz, .date:
            return try cell.decode(Date.self)
        case .uuid:
            return try cell.decode(UUID.self)
        case .json, .jsonb:
            return try cell.decode(String.self)
        case .bytea:
            return try cell.decode(Data.self)
        case .numeric:
            return try cell.decode(String.self)
        default:
            return try cell.decode(String.self)
        }
    }
    
    func configure(rawCell: PostgresCell?, columnInfo: PostgreSQLColumnInfo) {
        guard let cell = rawCell else {
                textField.stringValue = "(NULL)"
                createBorderViewIfNeeded()
                return
            }
        
         do {
             textField.stringValue = "(NULL)"
             let value = try decodeValue(from: cell)
             configureWithValue(value, columnInfo: columnInfo)
         } catch {
             textField.stringValue = "Error: \(error.localizedDescription)"
             textField.textColor = NSColor.systemRed
         }
         
         createBorderViewIfNeeded()
    }
    private func configureWithValue(_ value: Any?, columnInfo: PostgreSQLColumnInfo) {
        if let value = value {
            let displayValue = formatValueForDisplay(value, columnInfo: columnInfo)
            
            if let stringValue = value as? String, stringValue.isEmpty {
                textField.stringValue = "(EMPTY)"
                textField.textColor = .disabledControlTextColor
            } else {
                textField.stringValue = displayValue
                textField.textColor = NSColor.controlTextColor
            }
        } else {
            textField.stringValue = "(NULL)"
            textField.textColor = .disabledControlTextColor
        }
    }
    
    private func formatValueForDisplay(_ value: Any?, columnInfo: PostgreSQLColumnInfo) -> String {
        guard let value = value else { return "(NULL)" }
        
        // Format based on PostgreSQL data type for better display
        switch columnInfo.dataType {
        case .timestamp, .timestamptz:
            if let date = value as? Date {
                let formatter = DateFormatter()
                formatter.dateStyle = .medium
                formatter.timeStyle = .medium
                return formatter.string(from: date)
            }
        case .date:
            if let date = value as? Date {
                let formatter = DateFormatter()
                formatter.dateStyle = .medium
                return formatter.string(from: date)
            }
        case .bool:
            if let bool = value as? Bool {
                return bool ? "true" : "false"
            }
        case .json, .jsonb:
            // For JSON, you might want to pretty-print or validate
            if let jsonString = value as? String {
                return jsonString
            }
        case .numeric:
            // Format numbers nicely
            if let numericString = value as? String {
                return numericString
            }
        default:
            break
        }
        
        return String(describing: value)
    }

    // Rename the old method to avoid conflicts and keep it for backward compatibility
    func configureLegacy(value: Any?, columnInfo: PostgreSQLColumnInfo) {
        configureWithValue(value, columnInfo: columnInfo)
        createBorderViewIfNeeded()
    }
    
    private func createBorderViewIfNeeded() {
        if rightBorderView == nil || bottomBorderView == nil {
            createBorderView()
        }
    }
    
    private func createBorderView() {
         // Right border
         rightBorderView = NSView()
         rightBorderView?.wantsLayer = true
         rightBorderView?.layer?.backgroundColor = NSColor.separatorColor.cgColor
        
         addSubview(rightBorderView!)
         rightBorderView?.translatesAutoresizingMaskIntoConstraints = false
         NSLayoutConstraint.activate([
             rightBorderView!.trailingAnchor.constraint(equalTo: trailingAnchor, constant: 9),
             rightBorderView!.topAnchor.constraint(equalTo: topAnchor),
             rightBorderView!.bottomAnchor.constraint(equalTo: bottomAnchor),
             rightBorderView!.widthAnchor.constraint(equalToConstant: 1.0)
         ])
        
        // Bottom border
        bottomBorderView = NSView()
        bottomBorderView?.wantsLayer = true
        bottomBorderView?.layer?.backgroundColor = NSColor.separatorColor.cgColor
        
        addSubview(bottomBorderView!)
        bottomBorderView?.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            bottomBorderView!.leadingAnchor.constraint(equalTo: leadingAnchor, constant: -8),
            bottomBorderView!.trailingAnchor.constraint(equalTo: trailingAnchor, constant: 8),
            bottomBorderView!.bottomAnchor.constraint(equalTo: bottomAnchor, constant: 0),
            bottomBorderView!.heightAnchor.constraint(equalToConstant: 1.0)
        ])
    }
    
    override func layout() {
        super.layout()
        // No need for manual frame updates - Auto Layout handles everything
    }
    
    
    // MARK: - For Large Tables: Constraint Caching
    private var constraintsCache: [NSLayoutConstraint]?

    private func setupTextFieldWithConstraintCaching() {
        textField = NSTextField(frame: .zero)
        textField.configureForTableCell()
        
        addSubview(textField)
        textField.translatesAutoresizingMaskIntoConstraints = false
        
        // Cache constraints for reuse in cell recycling scenarios
        if constraintsCache == nil {
            constraintsCache = [
                textField.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 4),
                textField.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -4),
                textField.centerYAnchor.constraint(equalTo: centerYAnchor)
            ]
        }
        
        NSLayoutConstraint.activate(constraintsCache!)
    }
    
    // Prepare for reuse - reset state
//    override func prepareForReuse() {
//        super.prepareForReuse()
//        textField.stringValue = ""
//        
//        // Clear hover state if this cell was currently hovered
//        if TextCellView.currentlyHoveredCell === self {
//            TextCellView.currentlyHoveredCell = nil
//        }
//        
//        // Clear selected state if this cell was currently selected
//        if TextCellView.currentlySelectedCell === self {
//            TextCellView.currentlySelectedCell = nil
//        }
//        
//        // Reset visual state
//        isSelected = false
//        hoverBorderView?.isHidden = true
//        hoverBorderView?.alphaValue = 1.0
//        selectedBorderView?.isHidden = true
//        selectedBorderView?.alphaValue = 1.0
//    }
    
    // Clean up tracking area when view is deallocated
//    deinit {
//        // Clear static references if this cell was currently hovered or selected
//        if TextCellView.currentlyHoveredCell === self {
//            TextCellView.currentlyHoveredCell = nil
//        }
//        if TextCellView.currentlySelectedCell === self {
//            TextCellView.currentlySelectedCell = nil
//        }
//        
//        if let trackingArea = trackingArea {
//            removeTrackingArea(trackingArea)
//        }
//    }
}

// MARK: - Extension for Performance
private extension NSTextField {
    func configureForTableCell() {
        // Batch all property assignments to minimize KVO notifications
        
        // Content and appearance
        stringValue = ""
        textColor = .disabledControlTextColor
        font = .systemFont(ofSize: 12)
        
        // Behavior settings
        lineBreakMode = .byTruncatingTail
        
        // Cell configuration (safe unwrap to avoid crashes)
        if let cell = cell {
            cell.truncatesLastVisibleLine = true
            cell.isScrollable = false  // Prevent unnecessary scrolling behavior
            cell.wraps = false         // Disable wrapping for better performance
        }
        
        // Disable expensive features for table cells
        isEditable = false
        isSelectable = false
        isBordered = false
        backgroundColor = .clear
        drawsBackground = false  // Don't draw background for better performance
        
        // Optimize text rendering
        allowsEditingTextAttributes = false
        importsGraphics = false
        
        // Disable automatic behaviors that can slow down table scrolling
        if #available(macOS 10.12.2, *) {
            isAutomaticTextCompletionEnabled = false
            allowsCharacterPickerTouchBarItem = false
        }
        
        if #available(macOS 10.11, *) {
            allowsDefaultTighteningForTruncation = false
        }
    }
}
