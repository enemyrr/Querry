//
//  TextCellView.swift
//  Pluk
//
//  Created by Fauzaan on 06/22/25.
//

import Foundation
import AppKit
import PostgresNIO

// MARK: - Custom NSTextField that handles Escape key via cancelOperation
class EditableTextField: NSTextField {
    weak var cellView: TextCellView?
    
    // Override cancdelOperation which is called when Escape is pressed during editing
    override func cancelOperation(_ sender: Any?) {
        print("🚫 cancelOperation triggered")
        
        guard let cellView = cellView else {
            super.cancelOperation(sender)
            return
        }
        
        let originalValue = cellView.originalValue
        
        // Perform abort editing synchronously (this should be fast)
        if abortEditing() {
            let tableView = cellView.findTableView()
            print("✅ abortEditing succeeded")
            
            // Set values immediately on main thread with User Interactive QoS
            DispatchQueue.main.async(qos: .userInteractive) { [weak self, weak cellView] in
                guard let self = self, let cellView = cellView else { return }
                
                // Ensure our value is what we expect
                self.stringValue = originalValue
                cellView.isModified = false
                
                // Call exit edit mode on main thread with proper QoS
                cellView.exitEditMode()
                
                if let tableView = tableView {
                    if tableView.acceptsFirstResponder {
                        DispatchQueue.main.async(qos: .userInteractive) {
                            let success = tableView.window?.makeFirstResponder(tableView) ?? false
                            print("   - Table view became first responder: \(success)")
                            
                            if !success {
                                print("⚠️ Failed to make table view first responder, trying window")
                                tableView.window?.makeFirstResponder(tableView.window)
                            }
                        }
                    } else {
                        print("⚠️ Table view doesn't accept first responder")
                        // Fallback: make window first responder
                        window?.makeFirstResponder(window)
                    }
                    
                }
                
                print("   - Current first responder: \(self.window?.firstResponder?.className ?? "nil")")
                print("   - Text field isEditable: \(self.isEditable)")
            }
        } else {
            print("⚠️ abortEditing failed, falling back to manual exit")
            
            // Fallback: manual revert and exit on main thread with User Interactive QoS
            DispatchQueue.main.async(qos: .userInteractive) { [weak self, weak cellView] in
                guard let self = self, let cellView = cellView else { return }
                
                self.stringValue = originalValue
                cellView.isModified = false
                cellView.exitEditMode()
            }
        }
    }
}

// MARK: - TextCellView
class TextCellView: NSView, NSTextFieldDelegate {
    private var textField: EditableTextField!
    private var rightBorderView: NSView?
    private var bottomBorderView: NSView?
    
    // Static reference to track which cell is currently editing
    private static weak var currentEditingCell: TextCellView?
    
    public var isSelected: Bool = false
    private var isEditing: Bool = false {
        didSet {
            if oldValue != isEditing {
                updateEditingAppearance()
                
                // Update global editing state
                if isEditing {
                    TextCellView.currentEditingCell = self
                } else if TextCellView.currentEditingCell === self {
                    TextCellView.currentEditingCell = nil
                }
            }
        }
    }
    private var rowIndex: Int = -1
    private var columnName: String = ""
    private var dataType: String = ""
    
    // Weak reference to modification tracker to avoid retain cycles
    weak var modificationTracker: TableModificationTracker?
    fileprivate var originalValue: String = ""
    fileprivate var isModified: Bool = false {
        didSet {
            if oldValue != isModified {
                updateModificationAppearance()
            }
        }
    }
    var isMarkedForDeletion: Bool = false
    
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
    
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        if isMarkedForDeletion {
            NSColor.red.withAlphaComponent(0.3).setFill()
            let fillRect = NSRect(x: bounds.origin.x, y: bounds.origin.y, width: bounds.width - 1, height: bounds.height - 1)
            fillRect.fill()
        }
    }
    
    override func prepareForReuse() {
        if isEditing { exitEditMode() }
        isModified = false
        // Clear static references
        if TextCellView.currentEditingCell === self {
            TextCellView.currentEditingCell = nil
        }
    }
    
    private func setupTextField() {
        textField = EditableTextField(frame: .zero)
        textField.configureForTableCell()
        textField.delegate = self
        textField.cellView = self  // Connect the text field to this cell view
        
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
                // Exit edit mode for any currently editing cell when selecting a new cell
                if let currentEditingCell = TextCellView.currentEditingCell, currentEditingCell !== self {
                    print("Single click - exiting edit mode for previous cell")
                    TextCellView.exitCurrentEditMode()
                }
                
                setSelected(true)
            }
            
            // Only handle double-clicks for editing
            if event.clickCount == 2 {
                print("Double click - entering edit mode")
                
                // Explicitly exit any currently editing cell first
                TextCellView.exitCurrentEditMode()
                
                // Small delay to ensure previous cell has exited edit mode
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.01) {
                    self.enterEditMode()
                    self.textField.selectText(nil)
                }
            }
        }
    }
    
    func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
        print("🔍 Command during editing: \(NSStringFromSelector(commandSelector))")
        
        // Handle arrow keys during active editing
        switch commandSelector {
        case #selector(NSResponder.moveUp(_:)):
            print("⬆️ Up arrow pressed during editing")
            handleUpKeyDuringEditing()
            return true // We handled it, don't let the text view process it
            
        case #selector(NSResponder.moveDown(_:)):
            print("⬇️ Down arrow pressed during editing")
            handleDownKeyDuringEditing()
            return true // We handled it, don't let the text view process it
            
        default:
            print("🔄 Other command: \(NSStringFromSelector(commandSelector))")
            return false // Let the text view handle other commands
        }
    }
    
    
    // Public method for exiting edit mode (can be called externally)
    func exitEditModeForRow() {
        exitEditMode()
    }
    
    // Public method for entering edit mode
    func enterEditMode() {
        print("Entering edit mode for cell at row: \(rowIndex), column: \(columnName)")
        
        // First, ensure no other cell is in edit mode
        exitEditModeForAllCells()
        
        enableEditMode()
        window?.makeFirstResponder(textField)
        
        print("✅ Edit mode entered for cell at row: \(rowIndex), column: \(columnName)")
    }
    
    // Public method to reset modification state (useful for external control)
    func resetModificationState() {
        originalValue = textField.stringValue
        isModified = false
    }
    
    // Internal method to enable edit mode for individual cell
    private func enableEditMode() {
        guard !isEditing else { return }
        
        // Double-check that no other cell is editing
        if let currentEditingCell = TextCellView.currentEditingCell, currentEditingCell !== self {
            print("Warning: Another cell is still in edit mode, forcing exit")
            currentEditingCell.exitEditMode()
        }
        
        // Store original value for modification tracking
        originalValue = textField.stringValue
        
        // Enable editing
        textField.isEditable = true
        
        // Update visual state
        isEditing = true
    }
    
    fileprivate func exitEditMode() {
        print("Exiting edit mode for cell: \(isEditing)")
        
        guard isEditing else {
            print("⚠️ Cell is not in edit mode, nothing to exit")
            return
        }
        // Simply disable edit mode for this cell
        disableEditMode()
        
        // Remove first responder status
        if window?.firstResponder == textField {
            print("🔄 Removing first responder status from text field")
            window?.makeFirstResponder(window) // Give focus back to window
        }
        
        
        // Notify that editing has ended
        handleEditingCompleted()
    }
    
    // Method to exit edit mode for all cells in the table
    private func exitEditModeForAllCells() {
        // If there's a currently editing cell, exit its edit mode
        if let currentEditingCell = TextCellView.currentEditingCell, currentEditingCell !== self {
            print("🔄 Exiting edit mode for previous cell (row: \(currentEditingCell.rowIndex), col: \(currentEditingCell.columnName)) before entering new one")
            currentEditingCell.exitEditMode()
        } else if TextCellView.currentEditingCell == nil {
            print("✅ No previous cell in edit mode")
        } else {
            print("✅ Same cell - no need to exit")
        }
    }
    
    // Static method to get the currently editing cell (for debugging or external use)
    static func getCurrentEditingCell() -> TextCellView? {
        return currentEditingCell
    }
    
    // Static method to exit edit mode for any currently editing cell
    static func exitCurrentEditMode() {
        currentEditingCell?.exitEditMode()
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
        } else {
            // When exiting edit mode, ensure the modification background is still visible
            textField.backgroundColor = NSColor.clear
            textField.drawsBackground = false
        }
        
        // Ensure modification appearance is updated after editing changes
        updateModificationAppearance()
    }
    
    private func updateModificationAppearance() {
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
        
        // Keep the modification state visible after editing is completed
        // The modification background should remain until the data is actually saved to the database
        // Don't reset isModified here - it should remain true to show the visual indication
        
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
        
        // Check the movement reason to determine what key was pressed
        if let movementNumber = obj.userInfo?["NSTextMovement"] as? Int,
           let movement = NSTextMovement(rawValue: movementNumber) {
            print("moment: \(movement)")
            
            switch movement {
            case .tab:
                print("Tab key pressed - moving to next cell")
                handleTabKeyInEditMode()
                
            case .backtab:
                print("Shift+Tab key pressed - moving to previous cell")
                handleShiftTabKeyInEditMode()
                
            case .return:
                print("Return key pressed - moving down")
                handleEnterKeyInEditMode()
                
            default:
                print("Other movement: \(movement)")
                break
            }
        }
        
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
    func findTableView() -> NSTableView? {
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
        print("🎯 Setting cell (\(rowIndex), \(columnName)) selected: \(selected)")
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
        
        if let modification = modificationTracker?.getRowModification(for: rowIndex), modification.type == .delete {
            self.isMarkedForDeletion = true
        } else {
            self.isMarkedForDeletion = false
        }
        
        // Check if this cell has existing modifications
        if let tracker = modificationTracker,
           let cellMod = tracker.getCellModification(rowIndex: rowIndex, columnName: columnInfo.name) {
            // Use the modified value instead of the original
            textField.stringValue = cellMod.newValue
            originalValue = cellMod.originalValue
            isModified = cellMod.hasChanged
            
            // Ensure the modification appearance is applied immediately
            updateModificationAppearance()
        } else {
            // Configure normally and ensure no modification appearance
            configure(queryRowInfo: queryRowInfo, columnInfo: columnInfo)
            isModified = false
            updateModificationAppearance()
        }
        
        // Check if this cell should be selected and restore selection state
        if let tableView = findTableView() as? CustomTableView,
           let selectedCell = tableView.getCurrentSelectedCell() {
            let currentColumnIndex = tableView.columnIndex(for: columnInfo.name)
            let shouldBeSelected = (selectedCell.row == rowIndex && selectedCell.column == currentColumnIndex)
            
            print("🔍 Cell (\(rowIndex), \(currentColumnIndex)) - Should be selected: \(shouldBeSelected) (Selected cell: \(selectedCell.row), \(selectedCell.column))")
            
            if shouldBeSelected {
                setSelected(true)
            } else {
                setSelected(false)
            }
        } else {
            setSelected(false)
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
    
    func setAsSelectedCell() {
        // Set this cell as selected
        setSelected(true)
        
        print("Cell selected at row: \(rowIndex), column: \(columnName)")
    }
    
    /// Clears the selection state of this cell
    func clearSelection() {
        setSelected(false)
    }
    
    override func layout() {
        super.layout()
    }
    
    override func viewWillDraw() {
        let textColor: NSColor
        let placeholderColor: NSColor

        if let rowView = self.superview as? NSTableRowView, rowView.isSelected {
            textColor = .white
            placeholderColor = .lightGray
        } else {
            textColor = .controlTextColor
            placeholderColor = .placeholderTextColor
        }

        self.textField.textColor = textColor
        if let currentPlaceholder = self.textField.placeholderString, !currentPlaceholder.isEmpty {
            self.textField.placeholderAttributedString = NSAttributedString(
                string: currentPlaceholder,
                attributes: [.foregroundColor: placeholderColor]
            )
        }
        
        super.viewWillDraw()
        
        // Check and restore selection state before drawing
        if let tableView = findTableView() as? CustomTableView,
           let selectedCell = tableView.getCurrentSelectedCell() {
            let currentColumnIndex = tableView.columnIndex(for: columnName)
            let shouldBeSelected = (selectedCell.row == rowIndex && selectedCell.column == currentColumnIndex)
            
            if shouldBeSelected && !isSelected {
                print("🔄 Restoring selection for cell (\(rowIndex), \(currentColumnIndex)) in viewWillDraw")
                setSelected(true)
            } else if !shouldBeSelected && isSelected {
                print("🔄 Clearing incorrect selection for cell (\(rowIndex), \(currentColumnIndex)) in viewWillDraw")
                setSelected(false)
            }
        }
    }
    
    // MARK: - For Large Tables: Constraint Caching
    private var constraintsCache: [NSLayoutConstraint]?
    
    private func setupTextFieldWithConstraintCaching() {
        textField = EditableTextField(frame: .zero)
        textField.configureForTableCell()
        textField.cellView = self  // Connect the text field to this cell view
        
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


extension TextCellView {
    func handleTabKeyInEditMode() {
        print("🔄 Handling Tab key - navigating to next cell")
        
        // Save current changes first
        saveCurrentChanges()
        
        // Navigate to next cell
        navigateToCell(direction: .next)
    }
    
    func handleShiftTabKeyInEditMode() {
        print("🔄 Handling Shift+Tab key - navigating to previous cell")
        
        // Save current changes first
        saveCurrentChanges()
        
        // Navigate to previous cell
        navigateToCell(direction: .previous)
    }
    
    func handleEnterKeyInEditMode() {
        print("🔄 Handling Enter key - navigating down")
        
        // Save current changes first
        saveCurrentChanges()
        
        exitEditMode()
    }
    
    
    func handleUpKeyInEditMode() {
        print("🔄 Handling Up arrow key - navigating up")
        
        // Save current changes first
        saveCurrentChanges()
        
        forceEnterEditMode()
        // Navigate up
        navigateToCell(direction: .up)
    }
    
    func handleDownKeyInEditMode() {
        print("🔄 Handling Down arrow key - navigating down")
        
        // Save current changes first
        saveCurrentChanges()
        
        forceEnterEditMode()
        // Navigate down (same as Enter)
        navigateToCell(direction: .down)
    }
    
    func handleUpKeyDuringEditing() {
        // Save current changes and navigate up
        saveCurrentChanges()
        
        // Check if we're at the first line of a multi-line text field
        let textView = textField.currentEditor() as? NSTextView
        let selectedRange = textView?.selectedRange() ?? NSRange(location: 0, length: 0)
        
        // If cursor is at the beginning or this is single-line, navigate to previous row
        if selectedRange.location == 0 || textField.usesSingleLineMode {
            navigateToCell(direction: .up)
        }
    }
    
    private func handleDownKeyDuringEditing() {
        // Save current changes and navigate down
        saveCurrentChanges()
        
        // Check if we're at the last line of a multi-line text field
        let textView = textField.currentEditor() as? NSTextView
        let selectedRange = textView?.selectedRange() ?? NSRange(location: 0, length: 0)
        let textLength = textField.stringValue.count
        
        // If cursor is at the end or this is single-line, navigate to next row
        if selectedRange.location == textLength || textField.usesSingleLineMode {
            navigateToCell(direction: .down)
        }
    }
    
    private func saveCurrentChanges() {
        // Save current changes to modification tracker
        if let tracker = modificationTracker, rowIndex >= 0 {
            let finalValue = textField.stringValue
            if finalValue != originalValue {
                tracker.updateCell(
                    rowIndex: rowIndex,
                    columnName: columnName,
                    newValue: finalValue,
                    originalValue: originalValue,
                    dataType: dataType
                )
                print("💾 Saved changes: \(originalValue) → \(finalValue)")
            }
        }
    }
    
    private enum NavigationDirection {
        case next, previous, down, up
    }
    
    func forceEnterEditMode() {
        print("🔧 Force entering edit mode for cell at (\(rowIndex), \(columnName))")
        
        // Ensure we're not already editing
        if isEditing {
            print("Already in edit mode")
            return
        }
        
        // First, ensure no other cell is in edit mode
        exitEditModeForAllCells()
        
        // Store original value
        originalValue = textField.stringValue
        
        // Enable editing directly
        textField.isEditable = true
        
        // Set edit state
        isEditing = true
        
        // Force first responder
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.window?.makeFirstResponder(self.textField)
            self.textField.selectText(nil)
            print("🔧 Forced edit mode complete")
        }
    }
    
    private func navigateToCell(direction: NavigationDirection) {
        guard let tableView = findTableView() as? CustomTableView else {
            print("❌ Could not find CustomTableView")
            exitEditMode()
            return
        }
        
        let currentRow = tableView.row(for: self)
        let currentColumn = tableView.column(for: self)
        
        guard currentRow >= 0 && currentColumn >= 0 else {
            print("❌ Invalid current position")
            return
        }
        
        var nextColumn = currentColumn
        var nextRow = currentRow
        var shouldMove = true
        
        switch direction {
        case .next:
            nextColumn = currentColumn + 1
            // Stop at last column instead of wrapping
            if nextColumn >= tableView.numberOfColumns {
                shouldMove = false
                print("At last column - staying in current cell")
            }
            
        case .previous:
            nextColumn = currentColumn - 1
            // Stop at first column instead of wrapping
            if nextColumn < 0 {
                shouldMove = false
                print("At first column - staying in current cell")
            }
            
        case .down:
            nextRow = currentRow + 1
            // Stop at last row instead of wrapping
            if nextRow >= tableView.numberOfRows {
                shouldMove = false
                print("At last row - staying in current cell")
            }
            
        case .up:
            nextRow = currentRow - 1
            // Stop at first row instead of wrapping
            if nextRow < 0 {
                shouldMove = false
                print("At first row - staying in current cell")
            }
        }
        
        // Only navigate if we should move
        if shouldMove {
            print("🎯 Navigating from (\(currentRow), \(currentColumn)) to (\(nextRow), \(nextColumn))")
            
            // Exit edit mode for current cell immediately
            exitEditMode()
            
            // Select the next cell
            tableView.selectCell(row: nextRow, column: nextColumn)
            
            // Enter edit mode for the next cell
            if let nextCellView = tableView.view(atColumn: nextColumn, row: nextRow, makeIfNecessary: false) as? TextCellView {
                // Use a small delay to ensure the current cell has fully exited edit mode
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.01) {
                    nextCellView.enterEditMode()
                    // Select all text for easy replacement
                    nextCellView.textField.selectText(nil)
                    print("✅ Successfully navigated to new cell")
                }
            } else {
                print("❌ Could not find next cell view")
            }
        }
    }
}
