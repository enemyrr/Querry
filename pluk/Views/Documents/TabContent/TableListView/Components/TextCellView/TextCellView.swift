//
//  TextCellView.swift
//  Pluk
//
//  Created by Fauzaan on 06/22/25.
//

import Foundation
import AppKit
import PostgresNIO

// MARK: - TextCellView
class TextCellView: NSView, NSTextFieldDelegate {
    private var textField: NSTextField!
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
        print("TextCellView clicked - clickCount: \(event.clickCount)")
        
        // Check if the click is inside the text field bounds
        let textFieldPoint = textField.convert(point, from: self)
        
        if textField.bounds.contains(textFieldPoint) {
            print("Click is inside text field bounds")
            
            // Handle single click for selection
            if event.clickCount == 1 {
                // Clear previous selection first
                TextCellView.clearAllSelections()
                
                // Get table view and coordinate
                if let tableView = findTableView() {
                    let currentRow = tableView.row(for: self)
                    let currentColumn = tableView.column(for: self)
                    
                    // Select this cell
                    setSelected(true)
                    TextCellView.currentlySelectedCell = self
                }
            }
            
            // Only handle double-clicks for editing
            if event.clickCount == 2 {
                print("Double click - entering edit mode")
                enterEditMode()
                self.textField.selectText(nil)
            }
        }
    }
    
    // Add this new static method to clear all selections
    private static func clearAllSelections() {
        // Clear the currently selected cell
        if let selectedCell = currentlySelectedCell {
            selectedCell.setSelected(false)
        }
        currentlySelectedCell = nil
        
        // Clear the currently hovered cell
        if let hoveredCell = currentlyHoveredCell {
            hoveredCell.setSelected(false)
        }
        currentlyHoveredCell = nil
    }
    
    // Public method for exiting edit mode (can be called externally)
    func exitEditModeForRow() {
        exitEditMode()
    }
    
    // Public method for entering edit mode
    func enterEditMode() {
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
            // Set background color on the cell itself to indicate modification
            layer?.backgroundColor = NSColor(red: 0x7C/255.0, green: 0x59/255.0, blue: 0x2C/255.0, alpha: 1.0).cgColor
        } else {
            // Reset background color when not modified
            layer?.backgroundColor = NSColor.clear.cgColor
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
        
        // Track the complete cell modification when editing ends
        let finalValue = textField.stringValue
        if let tracker = modificationTracker, rowIndex >= 0 {
            if finalValue != originalValue {
                // Cell was changed - add to modification tracker and history
                tracker.updateCell(
                    rowIndex: rowIndex,
                    columnName: columnName,
                    newValue: finalValue,
                    originalValue: originalValue,
                    dataType: dataType
                )
                print("📝 Cell editing completed: Row \(rowIndex), Column \(columnName), \(originalValue) → \(finalValue)")
            } else {
                // Cell was reverted to original value - remove from tracker
                tracker.resetCell(rowIndex: rowIndex, columnName: columnName)
                print("🔄 Cell reverted to original: Row \(rowIndex), Column \(columnName)")
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
        // Only update the visual state during typing, don't track history yet
        let currentValue = textField.stringValue
        let hasChanged = currentValue != originalValue
        
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
        
        if !wantsLayer {
            wantsLayer = true
        }
        
        if selected {
            layer?.borderWidth = 1.0
            layer?.borderColor = NSColor.white.cgColor
        } else {
            // Remove border when not selected
            layer?.borderWidth = 0.0
            layer?.borderColor = NSColor.clear.cgColor
            layer?.cornerRadius = 0.0
        }
        
        needsDisplay = true  // Trigger redraw
        
    }
    
    func configure(queryRowInfo: QueryRowInfo?, columnInfo: QueryColumnInfo) {
        guard let queryRowInfo = queryRowInfo else {
            textField.placeholderString = "(EMPTY)"
            createBorderViewIfNeeded()
            return
        }
        
        textField.placeholderString = "(EMPTY)"
        
        // Handle nil values
        guard let value = queryRowInfo.value else {
            textField.placeholderString = "(NULL)"
            textField.stringValue = ""
            createBorderViewIfNeeded()
            return
        }
        
        // Cast to String and check if empty
        if let stringValue = value as? String {
            textField.stringValue = stringValue
            
            if stringValue.isEmpty {
                textField.placeholderString = "(EMPTY)"
            } else {
                textField.textColor = NSColor.controlTextColor
            }
        } else {
            // Handle non-string values by converting to string
            let stringRepresentation = String(describing: value)
            textField.stringValue = stringRepresentation
            textField.textColor = NSColor.controlTextColor
        }
        
        createBorderViewIfNeeded()
    }
    
    // New method that includes tracking information
    func configure(queryRowInfo: QueryRowInfo?, columnInfo: QueryColumnInfo, rowIndex: Int, modificationTracker: TableModificationTracker?) {
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
            configure(queryRowInfo: queryRowInfo, columnInfo: columnInfo)
        }
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
    
    /// Sets this cell as the currently selected cell (called by CustomTableView)
    func setAsSelectedCell() {
        // Clear any previous selection
        TextCellView.clearAllSelections()
        
        // Set this cell as selected
        setSelected(true)
        TextCellView.currentlySelectedCell = self
        
        print("Cell selected at row: \(rowIndex), column: \(columnName)")
    }
    
    /// Clears the selection state of this cell
    func clearSelection() {
        setSelected(false)
        
        // Clear the static reference if this was the selected cell
        if TextCellView.currentlySelectedCell === self {
            TextCellView.currentlySelectedCell = nil
        }
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
