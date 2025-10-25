//
//  CustomTooltip.swift
//  Collection
//
//  Created by Fauzaan on 3/8/25.
//
import SwiftUI
import AppKit

/// Defines the possible positions for the tooltip
enum TooltipPosition {
    case top
    case bottom
    case left
    case right
}

/// Represents a keyboard modifier
struct KeyboardModifier: Identifiable {
    let id = UUID()
    let symbol: String
    
    // Common modifiers
    static let command = KeyboardModifier(symbol: "⌘")
    static let shift = KeyboardModifier(symbol: "shift")
    static let option = KeyboardModifier(symbol: "⌥")
    static let control = KeyboardModifier(symbol: "⌃")
}

/// Represents a keyboard shortcut for display
struct KeyboardShortcut {
    let modifiers: [KeyboardModifier]
    let key: String
}

// MARK: - AppKit-based Tooltip Window
class CustomAppKitTooltip: NSWindow {
    private let tooltipView: NSView
    private var hideTimer: Timer?
    private var clickMonitor: Any?
    
    init(text: String, shortcut: KeyboardShortcut? = nil) {
        // Create container view
        tooltipView = NSView()
        tooltipView.wantsLayer = true
        tooltipView.layer?.backgroundColor = NSColor.black.cgColor
        tooltipView.layer?.cornerRadius = 10
        tooltipView.layer?.borderWidth = 0.5
        tooltipView.layer?.borderColor = NSColor(white: 1.0, alpha: 0.1).cgColor
        
        // Add shadow
        tooltipView.layer?.shadowColor = NSColor.black.cgColor
        tooltipView.layer?.shadowOpacity = 0.2
        tooltipView.layer?.shadowOffset = CGSize(width: 0, height: 1)
        tooltipView.layer?.shadowRadius = 1
        
        let padding: CGFloat = 8
        var contentWidth: CGFloat = 0
        var contentHeight: CGFloat = 0
        
        // Create text label
        let label = NSTextField(labelWithString: text)
        label.font = .systemFont(ofSize: 11)
        label.textColor = .white
        label.backgroundColor = .clear
        label.isEditable = false
        label.isBordered = false
        label.drawsBackground = false
        label.sizeToFit()
        
        if let shortcut = shortcut {
            // Layout with keyboard shortcut
            var currentX: CGFloat = padding + 2
            let keyHeight: CGFloat = 18
            let totalHeight = max(label.frame.height, keyHeight) + padding * 2
            
            // Calculate vertical center for alignment
            let labelY = (totalHeight - label.frame.height) / 2
            let keyY = (totalHeight - keyHeight) / 2
            
            // Add label
            label.frame = NSRect(
                x: currentX,
                y: labelY,
                width: label.frame.width,
                height: label.frame.height
            )
            tooltipView.addSubview(label)
            currentX += label.frame.width + 10
            
            // Add modifier keys
            for modifier in shortcut.modifiers {
                let modifierView = Self.createKeyModifierView(symbol: modifier.symbol)
                modifierView.frame.origin = NSPoint(x: currentX, y: keyY)
                tooltipView.addSubview(modifierView)
                currentX += modifierView.frame.width + 6
            }
            
            // Add key
            let keyView = Self.createKeyView(symbol: shortcut.key)
            keyView.frame.origin = NSPoint(x: currentX, y: keyY)
            tooltipView.addSubview(keyView)
            currentX += keyView.frame.width
            
            contentWidth = currentX + padding
            contentHeight = totalHeight
        } else {
            // Simple text tooltip
            label.frame = NSRect(
                x: padding,
                y: padding,
                width: label.frame.width,
                height: label.frame.height
            )
            tooltipView.addSubview(label)
            
            contentWidth = label.frame.width + padding * 2
            contentHeight = label.frame.height + padding * 2
        }
        
        let contentRect = NSRect(
            x: 0,
            y: 0,
            width: contentWidth,
            height: contentHeight
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
        
        tooltipView.frame = contentRect
        self.contentView = tooltipView
    }
    
    private static func createKeyModifierView(symbol: String) -> NSView {
        let container = NSView()
        container.wantsLayer = true
        container.layer?.backgroundColor = NSColor(white: 0.2, alpha: 1.0).cgColor
        container.layer?.cornerRadius = 4
        
        let label = NSTextField(labelWithString: symbol)
        label.font = .systemFont(ofSize: 11)
        label.textColor = .white
        label.backgroundColor = .clear
        label.isEditable = false
        label.isBordered = false
        label.drawsBackground = false
        label.alignment = .center
        label.sizeToFit()
        
        let width = max(label.frame.width, 20)
        let height: CGFloat = 18
        
        container.frame = NSRect(x: 0, y: 0, width: width, height: height)
        label.frame = NSRect(
            x: (width - label.frame.width) / 2,
            y: (height - label.frame.height) / 2,
            width: label.frame.width,
            height: label.frame.height
        )
        
        container.addSubview(label)
        return container
    }
    
    private static func createKeyView(symbol: String) -> NSView {
        let container = NSView()
        container.wantsLayer = true
        container.layer?.backgroundColor = NSColor(white: 0.2, alpha: 1.0).cgColor
        container.layer?.cornerRadius = 4
        
        let label = NSTextField(labelWithString: symbol)
        label.font = .systemFont(ofSize: 11)
        label.textColor = .white
        label.backgroundColor = .clear
        label.isEditable = false
        label.isBordered = false
        label.drawsBackground = false
        label.alignment = .center
        label.sizeToFit()
        
        let width = max(label.frame.width, 20)
        let height: CGFloat = 18
        
        container.frame = NSRect(x: 0, y: 0, width: width, height: height)
        label.frame = NSRect(
            x: (width - label.frame.width) / 2,
            y: (height - label.frame.height) / 2,
            width: label.frame.width,
            height: label.frame.height
        )
        
        container.addSubview(label)
        return container
    }
    
    func show(at point: NSPoint, relativeTo view: NSView, position: TooltipPosition, alignment: TooltipPosition?, spacing: CGFloat) {
        guard let window = view.window else { return }
        
        // Convert point to screen coordinates
        let viewBounds = view.bounds
        let windowPoint = view.convert(viewBounds, to: nil)
        let screenRect = window.convertToScreen(windowPoint)
        
        var tooltipOrigin = NSPoint.zero
        
        // Calculate position based on TooltipPosition
        switch position {
        case .top:
            tooltipOrigin.y = screenRect.maxY + spacing
            // Horizontal alignment
            if let alignment = alignment {
                switch alignment {
                case .left:
                    tooltipOrigin.x = screenRect.minX
                case .right:
                    tooltipOrigin.x = screenRect.maxX - self.frame.width
                default:
                    tooltipOrigin.x = screenRect.midX - self.frame.width / 2
                }
            } else {
                tooltipOrigin.x = screenRect.midX - self.frame.width / 2
            }
            
        case .bottom:
            tooltipOrigin.y = screenRect.minY - self.frame.height - spacing
            // Horizontal alignment
            if let alignment = alignment {
                switch alignment {
                case .left:
                    tooltipOrigin.x = screenRect.minX
                case .right:
                    tooltipOrigin.x = screenRect.maxX - self.frame.width
                default:
                    tooltipOrigin.x = screenRect.midX - self.frame.width / 2
                }
            } else {
                tooltipOrigin.x = screenRect.midX - self.frame.width / 2
            }
            
        case .left:
            tooltipOrigin.x = screenRect.minX - self.frame.width - spacing
            // Vertical alignment
            if let alignment = alignment {
                switch alignment {
                case .top:
                    tooltipOrigin.y = screenRect.maxY - self.frame.height
                case .bottom:
                    tooltipOrigin.y = screenRect.minY
                default:
                    tooltipOrigin.y = screenRect.midY - self.frame.height / 2
                }
            } else {
                tooltipOrigin.y = screenRect.midY - self.frame.height / 2
            }
            
        case .right:
            tooltipOrigin.x = screenRect.maxX + spacing
            // Vertical alignment
            if let alignment = alignment {
                switch alignment {
                case .top:
                    tooltipOrigin.y = screenRect.maxY - self.frame.height
                case .bottom:
                    tooltipOrigin.y = screenRect.minY
                default:
                    tooltipOrigin.y = screenRect.midY - self.frame.height / 2
                }
            } else {
                tooltipOrigin.y = screenRect.midY - self.frame.height / 2
            }
        }
        
        self.setFrameOrigin(tooltipOrigin)
        
        // Show with fade in
        self.alphaValue = 0
        window.addChildWindow(self, ordered: .above)
        
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.15
            self.animator().alphaValue = 1.0
        })
        
        // Monitor for clicks to hide tooltip
        clickMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            self?.hide()
            return event
        }
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
    
    deinit {
        if let monitor = clickMonitor {
            NSEvent.removeMonitor(monitor)
        }
    }
}

// MARK: - Tooltip Manager
class CustomTooltipManager {
    static let shared = CustomTooltipManager()
    private var currentTooltip: CustomAppKitTooltip?
    
    private init() {}
    
    func showTooltip(
        _ text: String,
        at point: NSPoint,
        relativeTo view: NSView,
        position: TooltipPosition,
        alignment: TooltipPosition?,
        spacing: CGFloat,
        shortcut: KeyboardShortcut?
    ) {
        hideTooltip()
        
        let tooltip = CustomAppKitTooltip(text: text, shortcut: shortcut)
        tooltip.show(at: point, relativeTo: view, position: position, alignment: alignment, spacing: spacing)
        currentTooltip = tooltip
    }
    
    func hideTooltip() {
        currentTooltip?.hide()
        currentTooltip = nil
    }
}

// MARK: - NSView Wrapper for Tooltip Tracking
struct TooltipHostView: NSViewRepresentable {
    let text: String
    let delay: Double
    let position: TooltipPosition
    let alignment: TooltipPosition?
    let shortcut: KeyboardShortcut?
    let spacing: CGFloat
    
    func makeNSView(context: Context) -> NSView {
        let view = TooltipTrackingView()
        view.tooltipText = text
        view.tooltipDelay = delay
        view.tooltipPosition = position
        view.tooltipAlignment = alignment
        view.tooltipShortcut = shortcut
        view.tooltipSpacing = spacing
        return view
    }
    
    func updateNSView(_ nsView: NSView, context: Context) {
        if let trackingView = nsView as? TooltipTrackingView {
            trackingView.tooltipText = text
            trackingView.tooltipDelay = delay
            trackingView.tooltipPosition = position
            trackingView.tooltipAlignment = alignment
            trackingView.tooltipShortcut = shortcut
            trackingView.tooltipSpacing = spacing
        }
    }
}

class TooltipTrackingView: NSView {
    var tooltipText: String = ""
    var tooltipDelay: Double = 1.0
    var tooltipPosition: TooltipPosition = .bottom
    var tooltipAlignment: TooltipPosition?
    var tooltipShortcut: KeyboardShortcut?
    var tooltipSpacing: CGFloat = 8
    
    private var trackingArea: NSTrackingArea?
    private var delayTask: DispatchWorkItem?
    
    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        
        if let trackingArea = trackingArea {
            removeTrackingArea(trackingArea)
        }
        
        trackingArea = NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .activeInKeyWindow],
            owner: self,
            userInfo: nil
        )
        
        if let trackingArea = trackingArea {
            addTrackingArea(trackingArea)
        }
    }
    
    override func mouseEntered(with event: NSEvent) {
        super.mouseEntered(with: event)
        
        delayTask?.cancel()
        
        let task = DispatchWorkItem { [weak self] in
            guard let self = self else { return }
            CustomTooltipManager.shared.showTooltip(
                self.tooltipText,
                at: NSPoint.zero,
                relativeTo: self,
                position: self.tooltipPosition,
                alignment: self.tooltipAlignment,
                spacing: self.tooltipSpacing,
                shortcut: self.tooltipShortcut
            )
        }
        
        delayTask = task
        DispatchQueue.main.asyncAfter(deadline: .now() + tooltipDelay, execute: task)
    }
    
    override func mouseExited(with event: NSEvent) {
        super.mouseExited(with: event)
        
        delayTask?.cancel()
        CustomTooltipManager.shared.hideTooltip()
    }
    
    override func mouseDown(with event: NSEvent) {
        super.mouseDown(with: event)
        
        delayTask?.cancel()
        CustomTooltipManager.shared.hideTooltip()
    }
    
    override func rightMouseDown(with event: NSEvent) {
        super.rightMouseDown(with: event)
        
        delayTask?.cancel()
        CustomTooltipManager.shared.hideTooltip()
    }
}

// MARK: - SwiftUI ViewModifier
struct CustomTooltip: ViewModifier {
    let text: String
    let delay: Double
    let position: TooltipPosition
    let alignment: TooltipPosition?
    let shortcut: KeyboardShortcut?
    let spacing: CGFloat
    
    func body(content: Content) -> some View {
        content
            .background(
                TooltipHostView(
                    text: text,
                    delay: delay,
                    position: position,
                    alignment: alignment,
                    shortcut: shortcut,
                    spacing: spacing
                )
            )
    }
}

// MARK: - SwiftUI Extensions (Backward Compatible)
extension View {
    /// Apply a custom tooltip with the specified position and spacing
    func customHelp(
        delay: Double = 1,
        position: TooltipPosition = .bottom,
        shortcut: KeyboardShortcut? = nil,
        alignment: TooltipPosition? = nil,
        spacing: CGFloat = 8,
        @ViewBuilder content: @escaping () -> some View
    ) -> some View {
        self.modifier(CustomTooltip(
            text: extractText(from: content()),
            delay: delay,
            position: position,
            alignment: alignment,
            shortcut: shortcut,
            spacing: spacing
        ))
    }
    
    /// Convenience version for simple text tooltips with position control
    func customHelp(
        _ text: String,
        delay: Double = 1.5,
        position: TooltipPosition = .bottom,
        shortcut: KeyboardShortcut? = nil,
        alignment: TooltipPosition? = nil,
        spacing: CGFloat = 8
    ) -> some View {
        self.modifier(CustomTooltip(
            text: text,
            delay: delay,
            position: position,
            alignment: alignment,
            shortcut: shortcut,
            spacing: spacing
        ))
    }
    
    private func extractText(from view: some View) -> String {
        // Simple text extraction - in practice, this would need to be more sophisticated
        // For now, we'll return a placeholder
        return "Tooltip"
    }
}
