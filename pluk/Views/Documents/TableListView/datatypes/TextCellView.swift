//
//  TextCellView.swift
//  Pluk
//
//  Created by Fauzaan on 6/4/25.
//

import Foundation
import AppKit

class TextCellView: NSView {
    private var textField: NSTextField!
    private var borderView: NSView?
    private var hoverBorderView: NSView?
    private var selectedBorderView: NSView?
    private var trackingArea: NSTrackingArea?
    
    // Static properties to track states
    private static weak var currentlyHoveredCell: TextCellView?
    private static weak var currentlySelectedCell: TextCellView?
    
    private var isSelected: Bool = false
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupTextField()
        setupHoverBorder()
        setupSelectedBorder()
        setupTracking()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupTextField()
        setupHoverBorder()
        setupSelectedBorder()
        setupTracking()
    }
    
    private func setupTextField() {
        textField = NSTextField(labelWithString: "")
        textField.textColor = NSColor.labelColor
        textField.font = NSFont.systemFont(ofSize: 12)
        
        addSubview(textField)
        textField.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            textField.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
            textField.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])
    }
    
    private func setupHoverBorder() {
        hoverBorderView = NSView()
        hoverBorderView?.wantsLayer = true
        hoverBorderView?.layer?.borderWidth = 2.0
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
        selectedBorderView?.layer?.borderWidth = 2.0
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
    
    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        
        if let trackingArea = trackingArea {
            removeTrackingArea(trackingArea)
        }
        
        let options: NSTrackingArea.Options = [.mouseEnteredAndExited, .activeAlways]
        trackingArea = NSTrackingArea(rect: bounds, options: options, owner: self, userInfo: nil)
        addTrackingArea(trackingArea!)
    }
    
    override func mouseEntered(with event: NSEvent) {
        super.mouseEntered(with: event)
        
        // Clear any previously hovered cell (but don't affect selected state)
        if let previousHovered = TextCellView.currentlyHoveredCell, previousHovered !== self {
            previousHovered.hideHoverBorder()
        }
        
        // Set this cell as the currently hovered one
        TextCellView.currentlyHoveredCell = self
        
        // Show hover only if not already selected
        if !isSelected {
            showHoverBorder()
        }
    }
    
    override func mouseExited(with event: NSEvent) {
        super.mouseExited(with: event)
        
        // Only hide hover if this cell is currently the hovered one and not selected
        if TextCellView.currentlyHoveredCell === self && !isSelected {
            TextCellView.currentlyHoveredCell = nil
            hideHoverBorder()
        }
    }
    
    override func mouseDown(with event: NSEvent) {
        super.mouseDown(with: event)
        
        // Get the previously selected cell for animation
        let previousCell = TextCellView.currentlySelectedCell
        
        // Set this cell as selected immediately (for state management)
        TextCellView.currentlySelectedCell = self
        
        // Animate the transition
        if let previousCell = previousCell, previousCell !== self {
            animateSelectionTransition(from: previousCell, to: self)
        } else {
            // No previous selection, just show normally
            setSelected(true)
        }
        
        // Find the table view and get row/column info
        if let tableView = findTableView() {
            let row = tableView.row(for: self)
            let column = tableView.column(for: self)
            print("Cell selected at row: \(row), column: \(column)")
        }
    }
    
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
    
    func configure(text: String, isLastColumn: Bool) {
        textField.stringValue = text
        
        // Handle border for last column
        if isLastColumn {
            if borderView == nil {
                createBorderView()
            }
            borderView?.isHidden = false
        } else {
            borderView?.isHidden = true
        }
    }
    
    private func createBorderView() {
        borderView = NSView()
        borderView?.wantsLayer = true
        borderView?.layer?.backgroundColor = NSColor.separatorColor.cgColor
        
        addSubview(borderView!)
        borderView?.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            borderView!.trailingAnchor.constraint(equalTo: trailingAnchor, constant: 9),
            borderView!.topAnchor.constraint(equalTo: topAnchor),
            borderView!.bottomAnchor.constraint(equalTo: bottomAnchor),
            borderView!.widthAnchor.constraint(equalToConstant: 1.0)
        ])
    }
    
    // Prepare for reuse - reset state
    override func prepareForReuse() {
        super.prepareForReuse()
        textField.stringValue = ""
        borderView?.isHidden = true
        
        // Clear hover state if this cell was currently hovered
        if TextCellView.currentlyHoveredCell === self {
            TextCellView.currentlyHoveredCell = nil
        }
        
        // Clear selected state if this cell was currently selected
        if TextCellView.currentlySelectedCell === self {
            TextCellView.currentlySelectedCell = nil
        }
        
        // Reset visual state
        isSelected = false
        hoverBorderView?.isHidden = true
        hoverBorderView?.alphaValue = 1.0
        selectedBorderView?.isHidden = true
        selectedBorderView?.alphaValue = 1.0
    }
    
    // Clean up tracking area when view is deallocated
    deinit {
        // Clear static references if this cell was currently hovered or selected
        if TextCellView.currentlyHoveredCell === self {
            TextCellView.currentlyHoveredCell = nil
        }
        if TextCellView.currentlySelectedCell === self {
            TextCellView.currentlySelectedCell = nil
        }
        
        if let trackingArea = trackingArea {
            removeTrackingArea(trackingArea)
        }
    }
}
