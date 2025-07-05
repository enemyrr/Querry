//
//  AppKitTooltip.swift
//  Pluk
//
//  Created by Assistant on 7/5/25.
//

import AppKit

class AppKitTooltip: NSWindow {
    private let tooltipView: NSView
    private var hideTimer: Timer?
    
    init(text: String) {
        // Create tooltip content
        let label = NSTextField(labelWithString: text)
        label.font = .systemFont(ofSize: 11)
        label.textColor = .white
        label.backgroundColor = .clear
        label.isEditable = false
        label.isBordered = false
        label.drawsBackground = false
        label.sizeToFit()
        
        // Create container view with padding
        tooltipView = NSView()
        tooltipView.wantsLayer = true
        tooltipView.layer?.backgroundColor = NSColor.black.cgColor
        tooltipView.layer?.cornerRadius = 6
        
        // Add shadow
        tooltipView.layer?.shadowColor = NSColor.black.cgColor
        tooltipView.layer?.shadowOpacity = 0.2
        tooltipView.layer?.shadowOffset = CGSize(width: 0, height: -1)
        tooltipView.layer?.shadowRadius = 2
        
        // Calculate size with padding
        let padding: CGFloat = 8
        let contentRect = NSRect(
            x: 0,
            y: 0,
            width: label.frame.width + padding * 2,
            height: label.frame.height + padding * 2
        )
        
        super.init(
            contentRect: contentRect,
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )
        
        // Configure window
        self.backgroundColor = .clear
        self.isOpaque = false
        self.level = .popUpMenu
        self.hasShadow = false
        self.ignoresMouseEvents = true
        
        // Set up view hierarchy
        tooltipView.frame = contentRect
        label.frame = NSRect(
            x: padding,
            y: padding,
            width: label.frame.width,
            height: label.frame.height
        )
        
        tooltipView.addSubview(label)
        self.contentView = tooltipView
    }
    
    func show(at point: NSPoint, relativeTo view: NSView) {
        guard let window = view.window else { return }
        
        // Convert point to screen coordinates
        let screenPoint = window.convertPoint(toScreen: view.convert(point, to: nil))
        
        // Position tooltip
        var tooltipOrigin = screenPoint
        tooltipOrigin.y -= 4 // Small offset below cursor
        
        self.setFrameOrigin(tooltipOrigin)
        
        // Show with fade in
        self.alphaValue = 0
        window.addChildWindow(self, ordered: .above)
        
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.15
            self.animator().alphaValue = 1.0
        })
    }
    
    func hide() {
        hideTimer?.invalidate()
        hideTimer = nil
        
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.15
            self.animator().alphaValue = 0.0
        }) {
            self.parent?.removeChildWindow(self)
            self.orderOut(nil)
        }
    }
    
    func scheduleHide(after delay: TimeInterval) {
        hideTimer?.invalidate()
        hideTimer = Timer.scheduledTimer(withTimeInterval: delay, repeats: false) { [weak self] _ in
            self?.hide()
        }
    }
}

// Tooltip manager to handle showing/hiding tooltips
class TooltipManager {
    static let shared = TooltipManager()
    private var currentTooltip: AppKitTooltip?
    
    private init() {}
    
    func showTooltip(_ text: String, at point: NSPoint, relativeTo view: NSView) {
        hideTooltip()
        
        let tooltip = AppKitTooltip(text: text)
        tooltip.show(at: point, relativeTo: view)
        currentTooltip = tooltip
    }
    
    func hideTooltip() {
        currentTooltip?.hide()
        currentTooltip = nil
    }
}