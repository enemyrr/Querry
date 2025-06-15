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
    
    override init(textCell string: String) {
        super.init(textCell: string)
        //            setupCustomView()
    }
    
    required init(coder: NSCoder) {
        super.init(coder: coder)
        //            setupCustomView()
        //            drawBackground(in: cellFrame)
    }
    
    //    override func draw(withFrame cellFrame: NSRect, in controlView: NSView) {
    //            drawBackground(in: cellFrame)
    ////            drawBorder(in: cellFrame)
    ////            drawTitle(in: cellFrame)
    ////            drawSortIndicator(in: cellFrame)
    //        }
    
    //    private func drawBackground(in rect: NSRect) {
    //            // Create gradient background
    //        let gradient = NSGradient(colors: NSColor.alternatingContentBackgroundColors)
    //            gradient?.draw(in: rect, angle: 90.0) // Vertical gradient
    //
    //            // Alternative: Solid color background
    //            // NSColor.controlBackgroundColor.setFill()
    //            // rect.fill()
    //        }
    
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
        //
        //        // Create icon
        //        iconImageView = NSImageView()
        //        iconImageView?.imageScaling = .scaleProportionallyUpOrDown
        //        iconImageView?.image = NSImage(systemSymbolName: "star.fill", accessibilityDescription: nil)
        //
        //        // Create sort button
        //        sortButton = NSButton()
        //        sortButton?.title = ""
        //        sortButton?.image = NSImage(systemSymbolName: "chevron.up.chevron.down", accessibilityDescription: nil)
        //        sortButton?.isBordered = false
        //        sortButton?.bezelStyle = .regularSquare
        //        sortButton?.target = self
        //        sortButton?.action = #selector(sortButtonClicked)
        //
        //        // Add subviews
        //        guard let customView = customView,
        //              let titleLabel = titleLabel,
        //              let iconImageView = iconImageView,
        //              let sortButton = sortButton else { return }
        
        if let titleLabel = titleLabel {
            customView?.addSubview(titleLabel)
        }
        //        customView.addSubview(iconImageView)
        //        customView.addSubview(sortButton)
        //
        setupConstraints()
    }
    
    private func setupConstraints() {
        //        guard let titleLabel = titleLabel,
        //              let iconImageView = iconImageView,
        //              let sortButton = sortButton,
        //              let customView = customView else { return }
        
        //        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        //        iconImageView.translatesAutoresizingMaskIntoConstraints = false
        //        sortButton.translatesAutoresizingMaskIntoConstraints = false
        //
        //                NSLayoutConstraint.activate([
        // Icon constraints
        //                    iconImageView.leadingAnchor.constraint(equalTo: customView.leadingAnchor, constant: 8),
        //                    iconImageView.centerYAnchor.constraint(equalTo: customView.centerYAnchor),
        //                    iconImageView.widthAnchor.constraint(equalToConstant: 16),
        //                    iconImageView.heightAnchor.constraint(equalToConstant: 16),
        
        // Title label constraints
        //                    titleLabel.leadingAnchor.constraint(equalTo: iconImageView.trailingAnchor, constant: 4),
        //                    titleLabel.centerYAnchor.constraint(equalTo: customView.centerYAnchor),
        //                    titleLabel.trailingAnchor.constraint(equalTo: sortButton.leadingAnchor, constant: -4),
        
        // Sort button constraints
        //                    sortButton.trailingAnchor.constraint(equalTo: customView.trailingAnchor, constant: -8),
        //                    sortButton.centerYAnchor.constraint(equalTo: customView.centerYAnchor),
        //                    sortButton.widthAnchor.constraint(equalToConstant: 20),
        //                    sortButton.heightAnchor.constraint(equalToConstant: 20)
        //                ])
    }
    
    func configure(title: String, icon: NSImage? = nil, showSortButton: Bool = true) {
        titleLabel?.stringValue = title
        iconImageView?.image = icon
        iconImageView?.isHidden = icon == nil
        sortButton?.isHidden = !showSortButton
    }
    
    //    @objc private func sortButtonClicked() {
    //        print("Sort button clicked for: \(titleLabel?.stringValue ?? "")")
    //        // Notify delegate or post notification for sorting
    //        NotificationCenter.default.post(
    //            name: NSNotification.Name("HeaderSortClicked"),
    //            object: self,
    //            userInfo: ["column": stringValue]
    //        )
    //    }
    
    override func draw(withFrame cellFrame: NSRect, in controlView: NSView) {
        // Don't call super to avoid default drawing
        drawCustomBackground(in: cellFrame)
        drawTitle(in: cellFrame, icon: NSImage(systemSymbolName: "chevron.up.chevron.down", accessibilityDescription: nil))
    }
    
    
    private func drawTitle(in rect: NSRect, icon: NSImage?) {
        var textRect = rect.insetBy(dx: 8, dy: 0)
        textRect.size.width -= 20 // Space for sort indicator
        
        // Create text attributes
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = self.alignment
        
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.menuBarFont(ofSize: 12),
            .foregroundColor: NSColor.secondaryLabelColor,
            .paragraphStyle: paragraphStyle
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
        drawTitle(in: cellFrame, icon: NSImage(systemSymbolName: "chevron.up.chevron.down", accessibilityDescription: nil))
        
        if flag {
            //            customView?.layer?.backgroundColor = NSColor.selectedControlColor.withAlphaComponent(0.3).cgColor
        } else {
            //            customView?.layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor
        }
    }
}
