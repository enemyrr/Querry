//
//  TextCellView.swift
//  Pluk
//
//  Created by Fauzaan on 06/22/25.
//

import Foundation
import AppKit
import PostgresNIO

// MARK: - Custom NSTextFieldCell with internal padding
class PaddedTextFieldCell: NSTextFieldCell {
    let textPadding: NSEdgeInsets = NSEdgeInsets(top: 2, left: 8, bottom: 2, right: 8)
    
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
        paddedRect.size.width -= (textPadding.left + textPadding.right)
        paddedRect.size.height -= (textPadding.top + textPadding.bottom)
        
        super.select(withFrame: paddedRect, in: controlView, editor: textObj, delegate: delegate, start: selStart, length: selLength)
    }
    
    override func drawInterior(withFrame cellFrame: NSRect, in controlView: NSView) {
        var paddedRect = cellFrame
        paddedRect.origin.x += textPadding.left
        paddedRect.origin.y += textPadding.top
        paddedRect.size.width -= (textPadding.left + textPadding.right)
        paddedRect.size.height -= (textPadding.top + textPadding.bottom)
        super.drawInterior(withFrame: paddedRect, in: controlView)  // Changed this line
    }
    
//    override func draw(withFrame cellFrame: NSRect, in controlView: NSView) {
//        var paddedRect = cellFrame
//        paddedRect.origin.x += textPadding.left
//        paddedRect.origin.y += textPadding.top
//        paddedRect.size.width -= (textPadding.left + textPadding.right)
//        paddedRect.size.height -= (textPadding.top + textPadding.bottom)
//        super.draw(withFrame: paddedRect, in: controlView)
//    }
}


// MARK: - Enhanced TextCellView with single-click edit support
class TextCellView: NSView, NSTextFieldDelegate {
    private var textField: NSTextField!
    private var hoverBorderView: NSView?
    private var selectedBorderView: NSView?
    private var trackingArea: NSTrackingArea?
    private var rightBorderView: NSView?
    private var bottomBorderView: NSView?
    
    private static weak var currentlyHoveredCell: TextCellView?
    private static weak var currentlySelectedCell: TextCellView?
    
    private var isSelected: Bool = false
    private var isEditing: Bool = false {
        didSet {
            if oldValue != isEditing {
                updateEditingAppearance()
            }
        }
    }
    private var rowIndex: Int = -1
    private var columnName: String = ""
    private var dataType: String = ""
    
    // Weak reference to modification tracker to avoid retain cycles
    weak var modificationTracker: TableModificationTracker?
    private var originalValue: String = ""
    private var isModified: Bool = false {
        didSet {
            if oldValue != isModified {
                updateModificationAppearance()
            }
        }
    }
    
    // Cache for optimization
    private var lastConfiguredColumn: String = ""
    private var lastConfiguredValue: String = ""
    private var lastCellDataHash: Int = 0
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupTextField()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupTextField()
    }
    
    private func setupTextField() {
        textField = NSTextField(frame: .zero)
        textField.configureForTableCell()
        textField.delegate = self
        
        textField.cell = PaddedTextFieldCell()
        
        addSubview(textField)
        textField.translatesAutoresizingMaskIntoConstraints = false
        
        // Add padding through constraints instead of cell manipulation for better control
        NSLayoutConstraint.activate([
            textField.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 0),
            textField.trailingAnchor.constraint(equalTo: trailingAnchor, constant: 0),
            textField.topAnchor.constraint(equalTo: topAnchor, constant: 0),
            textField.bottomAnchor.constraint(equalTo: bottomAnchor, constant: 0)
        ])
    }
    
    // MARK: - Double-Click Edit Handler (called from CustomTableView)
    func handleDoubleClickEdit(at point: NSPoint, with event: NSEvent) {
        print("TextCellView handleDoubleClickEdit - clickCount: \(event.clickCount)")
        
        // Check if the click is inside the text field bounds
        let textFieldPoint = textField.convert(point, from: self)
        
        if textField.bounds.contains(textFieldPoint) {
            print("Click is inside text field bounds")
            
            // Only handle double-clicks for editing
            if event.clickCount == 2 {
                print("Double click - entering edit mode")
                enterEditMode()
                self.textField.selectText(nil)
            }
        }
    }
    
    // Public method for exiting edit mode (can be called externally)
    func exitEditModeForRow() {
        exitEditMode()
    }
    
    // Public method for entering edit mode
    func enterEditMode() {
        guard !isEditing else { return }
        
        print("Entering edit mode for cell")
        
        // Find all cells in the same row and put them in edit mode
        if let tableView = findTableView() {
            let currentRow = tableView.row(for: self)
            if currentRow >= 0 {
                // Enable edit mode for all cells in this row
                for columnIndex in 0..<tableView.numberOfColumns {
                    if let cellView = tableView.view(atColumn: columnIndex, row: currentRow, makeIfNecessary: false) as? TextCellView {
                        cellView.enableEditMode()
                    }
                }
                
                // Make this cell's text field first responder
                window?.makeFirstResponder(textField)
            }
        } else {
            // Fallback for single cell if table view not found
            enableEditMode()
            window?.makeFirstResponder(textField)
        }
    }
    
    // Public method to reset modification state (useful for external control)
    func resetModificationState() {
        originalValue = textField.stringValue
        isModified = false
    }
    
    // Internal method to enable edit mode for individual cell
    private func enableEditMode() {
        guard !isEditing else { return }
        
        // Store original value for modification tracking
        originalValue = textField.stringValue
        
        // Enable editing
        textField.isEditable = true
        textField.isSelectable = true
        
        // Update visual state
        isEditing = true
    }
    
    private func exitEditMode() {
        guard isEditing else { return }
        
        print("Exiting edit mode for cell: \(isEditing)")
        
        // Find all cells in the same row and exit edit mode
        if let tableView = findTableView() {
            let currentRow = tableView.row(for: self)
            if currentRow >= 0 {
                // Exit edit mode for all cells in this row
                for columnIndex in 0..<tableView.numberOfColumns {
                    if let cellView = tableView.view(atColumn: columnIndex, row: currentRow, makeIfNecessary: false) as? TextCellView {
                        cellView.disableEditMode()
                    }
                }
            }
        } else {
            // Fallback for single cell if table view not found
            disableEditMode()
        }
        
        // Remove first responder status
        if window?.firstResponder == textField {
            window?.makeFirstResponder(nil)
        }
        
        // Notify that editing has ended
        handleEditingCompleted()
    }
    
    // Internal method to disable edit mode for individual cell
    private func disableEditMode() {
        guard isEditing else { return }
        
        // Disable editing
        textField.isEditable = false
        
        // Update visual state
        isEditing = false
    }
    
    private func updateEditingAppearance() {
        print("updateEditingAppearance - isEditing: \(isEditing)")
        if isEditing {
            textField.backgroundColor = NSColor.clear
            textField.drawsBackground = true
        }
    }
    
    private func updateModificationAppearance() {
        print("updateModificationAppearance - isModified: \(isModified)")
        
        // Ensure the cell has a layer for background drawing
        if !wantsLayer {
            wantsLayer = true
        }
        
        if isModified {
            // Set background color on the cell itself
            layer?.backgroundColor = NSColor.systemOrange.withAlphaComponent(0.2).cgColor
        }
    }
    
    private func handleEditingCompleted() {
        // This is where you can add logic to save the edited value
        // For example, update your data model, send to database, etc.
        print("Cell editing completed with value: \(textField.stringValue)")
        
        // Reset modification state after editing is completed
        // In a real app, you might want to keep the modified state until the data is actually saved
        isModified = false
        originalValue = textField.stringValue
        
        // You might want to notify a delegate or post a notification
        NotificationCenter.default.post(
            name: NSNotification.Name("CellEditingCompleted"),
            object: self,
            userInfo: [
                "newValue": textField.stringValue,
                "cell": self,
                "wasModified": textField.stringValue != originalValue
            ]
        )
    }
    
    // MARK: - NSTextFieldDelegate Methods
    func controlTextDidEndEditing(_ obj: Notification) {
        // Only exit edit mode if we're actually editing and the reason is appropriate
        guard isEditing else { return }
        
        // Check the reason for ending editing
        if let userInfo = obj.userInfo,
           let reasonValue = userInfo["NSTextMovement"] as? Int {
            let reason = NSTextMovement(rawValue: reasonValue) ?? .other
            
            switch reason {
            case .return, .cancel:
                // User pressed Enter, .Esc
                exitEditMode()
            case .other:
                // Check if we're losing focus to something outside the table
                if !(window?.firstResponder is NSTextView) {
                    // Not editing any text field
                    exitEditMode()
                }
            default:
                // For other movements, don't automatically exit edit mode
                break
            }
        } else {
            // If no movement reason, check if we're actually losing focus
            if window?.firstResponder != textField {
                exitEditMode()
            }
        }
    }
    
    func controlTextDidBeginEditing(_ obj: Notification) {
        // Ensure we're in edit mode when editing begins
        if !isEditing {
            enterEditMode()
            print("Text editing began - ensuring edit mode is active")
        }
    }
    
    func controlTextDidChange(_ obj: Notification) {
        // Check if the text has been modified from the original value
        let currentValue = textField.stringValue
        let hasChanged = currentValue != originalValue
        
        // Update the modification tracker on every change
        if let tracker = modificationTracker, rowIndex >= 0 {
            if hasChanged {
                tracker.updateCell(
                    rowIndex: rowIndex,
                    columnName: columnName,
                    newValue: currentValue,
                    originalValue: originalValue,
                    dataType: dataType
                )
            } else {
                tracker.resetCell(rowIndex: rowIndex, columnName: columnName)
            }
        }
        
        // Update the visual state only when modification state changes
        if hasChanged != isModified {
            isModified = hasChanged
            print("Text field modification state changed: \(isModified)")
        }
    }

    // MARK: - Helper Methods
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
    
    private func setSelected(_ selected: Bool) {
        isSelected = selected
        // Add your selection visual logic here if needed
    }
    
    private func formatValueForDisplay(_ value: Any?) -> String? {
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
    
    func configure(rawCell: Any?, columnInfo: QueryColumnInfo) {
        guard let rawCell = rawCell else {
            textField.placeholderString = "(EMPTY)"
            createBorderViewIfNeeded()
            return
        }
        
        do {
            textField.placeholderString = "(EMPTY)"
            
            // Handle the case where rawCell is a PostgresCell
            if let postgresCell = rawCell as? PostgresCell {
                let value = try decodeValue(from: postgresCell)
                configureWithValue(value, columnInfo: columnInfo)
            } else {
                // Handle other database types or direct values
                configureWithValue(rawCell, columnInfo: columnInfo)
            }
        } catch {
            textField.stringValue = "Error: \(error.localizedDescription)"
            textField.textColor = NSColor.systemRed
        }
        
        createBorderViewIfNeeded()
    }
    
    // New method that includes tracking information
    func configure(rawCell: Any?, columnInfo: QueryColumnInfo, rowIndex: Int, modificationTracker: TableModificationTracker?) {
        // Store tracking information
        self.rowIndex = rowIndex
        self.columnName = columnInfo.name
        self.dataType = columnInfo.dataType
        self.modificationTracker = modificationTracker
        
        // Check if this cell has existing modifications
        if let tracker = modificationTracker,
           let cellMod = tracker.getCellModification(rowIndex: rowIndex, columnName: columnInfo.name) {
            // Use the modified value instead of the original
            textField.stringValue = cellMod.newValue
            originalValue = cellMod.originalValue
            isModified = cellMod.hasChanged
        } else {
            // Configure normally
            configure(rawCell: rawCell, columnInfo: columnInfo)
        }
    }
    
    private func configureWithValue(_ value: Any?, columnInfo: QueryColumnInfo) {
        if let value = value {
            let displayValue = formatValueForDisplay(value, columnInfo: columnInfo)
            
            textField.stringValue = displayValue
            if let stringValue = value as? String, stringValue.isEmpty {
                textField.placeholderString = "(EMPTY)"
            } else {
                textField.textColor = NSColor.controlTextColor
            }
        } else {
            textField.placeholderString = "(NULL)"
        }
        
        // Store the configured value as the original value and reset modification state
        originalValue = textField.stringValue
        isModified = false
    }
    
    private func formatValueForDisplay(_ value: Any?, columnInfo: QueryColumnInfo) -> String {
        guard let value = value else { return "(NULL)" }
        
        // Format based on data type for better display
        switch columnInfo.dataType.lowercased() {
        case "timestamp", "timestamptz":
            if let date = value as? Date {
                let formatter = DateFormatter()
                formatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSSSSS"
                formatter.timeZone = TimeZone(identifier: "UTC")
                
                let fullString = formatter.string(from: date)
                
                if let dotIndex = fullString.lastIndex(of: ".") {
                    let beforeDot = String(fullString[..<dotIndex])
                    let afterDot = String(fullString[fullString.index(after: dotIndex)...])
                    
                    // Take maximum 5 decimal places, remove trailing zeros
                    let maxDecimals = String(afterDot.prefix(5))
                    let trimmed = maxDecimals.trimmingCharacters(in: CharacterSet(charactersIn: "0"))
                    
                    if trimmed.isEmpty {
                        return beforeDot
                    } else {
                        return "\(beforeDot).\(trimmed)"
                    }
                }
                return fullString
            }
        case "date":
            if let date = value as? Date {
                let formatter = DateFormatter()
                formatter.dateFormat = "yyyy-MM-dd"
                return formatter.string(from: date)
            }
        case "bool", "boolean":
            if let bool = value as? Bool {
                return bool ? "true" : "false"
            }
        case "json", "jsonb":
            // For JSON, you might want to pretty-print or validate
            if let jsonString = value as? String {
                return jsonString
            }
        case "numeric", "decimal":
            // Format numbers nicely
            if let numericString = value as? String {
                return numericString
            }
        default:
            break
        }
        
        return String(describing: value)
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
            rightBorderView!.trailingAnchor.constraint(equalTo: trailingAnchor, constant: 0),
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
            bottomBorderView!.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 0),
            bottomBorderView!.trailingAnchor.constraint(equalTo: trailingAnchor, constant: 0),
            bottomBorderView!.bottomAnchor.constraint(equalTo: bottomAnchor, constant: 0),
            bottomBorderView!.heightAnchor.constraint(equalToConstant: 1.0)
        ])
    }
    
    override func layout() {
        super.layout()
    }
    
    // MARK: - For Large Tables: Constraint Caching
    private var constraintsCache: [NSLayoutConstraint]?
    
    private func setupTextFieldWithConstraintCaching() {
        textField = NSTextField(frame: .zero)
        textField.configureForTableCell()
        
        // Use custom padded cell for internal text padding
        let paddedCell = PaddedTextFieldCell()
//        paddedCell.textPadding = NSEdgeInsets(top: 2, left: 8, bottom: 2, right: 8)
        textField.cell = paddedCell
        
        addSubview(textField)
        textField.translatesAutoresizingMaskIntoConstraints = false
        
        // TextField fills entire cell - internal padding handled by custom cell
        if constraintsCache == nil {
            constraintsCache = [
                textField.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 0),
                textField.trailingAnchor.constraint(equalTo: trailingAnchor, constant: 0),
                textField.topAnchor.constraint(equalTo: topAnchor, constant: 0),
                textField.bottomAnchor.constraint(equalTo: bottomAnchor, constant: 0)
            ]
        }
        
        NSLayoutConstraint.activate(constraintsCache!)
    }
}

// MARK: - Extension for Performance
private extension NSTextField {
    func configureForTableCell() {
        // Content and appearance
        stringValue = ""
        textColor = .disabledControlTextColor
        font = .systemFont(ofSize: 12)
        
        // Behavior settings
        lineBreakMode = .byTruncatingTail
        
        // Disable expensive features for table cells
        isEditable = false  // Will be enabled on click
        isSelectable = true
        isBordered = false
        backgroundColor = .clear
        drawsBackground = true  // Don't draw background for better performance
        
        // Remove any cell padding or insets
        cell?.wraps = false
        cell?.isScrollable = true
        
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
    }
}

// MARK: - Custom NSTableView that enables single-click editing
class CustomTableView: NSTableView {
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
