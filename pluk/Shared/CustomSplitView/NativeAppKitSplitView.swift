//
//  NativeAppKitSplitView.swift
//  Pluk
//
//  Created by Claude on 1/25/25.
//

import SwiftUI
import AppKit

struct NativeAppKitSplitView<Left: View, Right: View>: NSViewRepresentable {
    let left: Left
    let right: Right
    @Binding var isSidebarVisible: Bool
    let isFixedSidebar: Bool
    let fixedSidebarWidth: CGFloat
    let minSidebarWidth: CGFloat

    init(left: Left, right: Right, isSidebarVisible: Binding<Bool>, isFixedSidebar: Bool = false, fixedSidebarWidth: CGFloat = 50, minSidebarWidth: CGFloat = 290) {
        self.left = left
        self.right = right
        self._isSidebarVisible = isSidebarVisible
        self.isFixedSidebar = isFixedSidebar
        self.fixedSidebarWidth = fixedSidebarWidth
        self.minSidebarWidth = minSidebarWidth
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    // Expose the toggle method for external use
    func toggleSidebar() {
        // This will be called from the notification handler
    }

    func makeNSView(context: Context) -> NSSplitView {
        let splitView = CustomNSSplitView()
        splitView.translatesAutoresizingMaskIntoConstraints = false
        splitView.isVertical = true
        splitView.dividerStyle = .thin
        splitView.delegate = context.coordinator
        splitView.isFixedSidebar = isFixedSidebar
        splitView.fixedSidebarWidth = fixedSidebarWidth
        splitView.minSidebarWidth = minSidebarWidth

        // Configure autosave to remember user's preferred size (only for resizable sidebars)
        if !isFixedSidebar {
            splitView.autosaveName = NSSplitView.AutosaveName("PlukSidebarSplitView")
        }

        // Create hosting views
        let leftHost = NSHostingView(rootView: left)
        let rightHost = NSHostingView(rootView: right)

        leftHost.translatesAutoresizingMaskIntoConstraints = false
        rightHost.translatesAutoresizingMaskIntoConstraints = false

        // Add subviews
        splitView.addArrangedSubview(leftHost)
        splitView.addArrangedSubview(rightHost)

        // Store references in coordinator
        context.coordinator.splitView = splitView
        context.coordinator.leftHost = leftHost
        context.coordinator.rightHost = rightHost
        context.coordinator.sidebarVisibilityBinding = $isSidebarVisible
        context.coordinator.isFixedSidebar = isFixedSidebar
        context.coordinator.fixedSidebarWidth = fixedSidebarWidth
        context.coordinator.minSidebarWidth = minSidebarWidth

        // Listen for resize notifications
        NotificationCenter.default.addObserver(
            context.coordinator,
            selector: #selector(Coordinator.splitViewDidResizeSubviews(_:)),
            name: NSSplitView.didResizeSubviewsNotification,
            object: splitView
        )

        // Listen for sidebar toggle notifications
        NotificationCenter.default.addObserver(
            context.coordinator,
            selector: #selector(Coordinator.handleSidebarToggle(_:)),
            name: .toggleLeftSidebar,
            object: nil
        )

        // Set initial state
        DispatchQueue.main.async {
            applyVisibility(context: context)
        }

        return splitView
    }

    func updateNSView(_ nsView: NSSplitView, context: Context) {
        // Update the hosting views with new content
        if let leftHost = context.coordinator.leftHost as? NSHostingView<Left> {
            leftHost.rootView = left
        }
        if let rightHost = context.coordinator.rightHost as? NSHostingView<Right> {
            rightHost.rootView = right
        }

        context.coordinator.sidebarVisibilityBinding = $isSidebarVisible
        applyVisibility(context: context)
    }

    private func applyVisibility(context: Context) {
        guard let splitView = context.coordinator.splitView,
              let leftHost = context.coordinator.leftHost else { return }

        // Fixed sidebar doesn't support visibility changes
        if isFixedSidebar {
            return
        }

        if isSidebarVisible {
            if leftHost.isHidden {
                leftHost.isHidden = false
                // Restore to default width respecting minimum
                let expandWidth = max(330, minSidebarWidth)
                splitView.setPosition(expandWidth, ofDividerAt: 0)
            }
        } else {
            leftHost.isHidden = true
        }
    }

    final class Coordinator: NSObject, NSSplitViewDelegate {
        weak var splitView: NSSplitView?
        weak var leftHost: NSView?
        weak var rightHost: NSView?
        var sidebarVisibilityBinding: Binding<Bool>?
        var isFixedSidebar: Bool = false
        var fixedSidebarWidth: CGFloat = 50
        var minSidebarWidth: CGFloat = 290
        var lastUserSidebarWidth: CGFloat = 330 // Track user's preferred width

        // MARK: - Native Sidebar Collapse Methods

        func toggleSidebar() {
            guard let splitView = splitView,
                  let leftHost = leftHost else { return }

            // Fixed sidebar doesn't support toggling
            if isFixedSidebar {
                return
            }

            if leftHost.isHidden {
                // Show sidebar at user's last preferred width
                let expandWidth = max(lastUserSidebarWidth, minSidebarWidth)
                splitView.setPosition(expandWidth, ofDividerAt: 0)
                leftHost.isHidden = false
                sidebarVisibilityBinding?.wrappedValue = true
            } else {
                // Store current width before hiding
                lastUserSidebarWidth = leftHost.frame.width
                leftHost.isHidden = true
                sidebarVisibilityBinding?.wrappedValue = false
            }
        }

        // MARK: - NSSplitViewDelegate

        func splitView(_ splitView: NSSplitView, constrainMinCoordinate proposedMinimumPosition: CGFloat, ofSubviewAt dividerIndex: Int) -> CGFloat {
            if isFixedSidebar {
                return fixedSidebarWidth // Fixed width
            }
            return minSidebarWidth // Minimum width for resizable sidebars
        }

        func splitView(_ splitView: NSSplitView, constrainMaxCoordinate proposedMaximumPosition: CGFloat, ofSubviewAt dividerIndex: Int) -> CGFloat {
            if isFixedSidebar {
                return fixedSidebarWidth // Fixed width
            }
            return splitView.frame.width - 400 // Leave at least 400px for content
        }

        func splitView(_ splitView: NSSplitView, canCollapseSubview subview: NSView) -> Bool {
            // Fixed sidebar cannot be collapsed
            if isFixedSidebar {
                return false
            }
            return subview == leftHost // Only allow collapsing the sidebar
        }

        func splitView(_ splitView: NSSplitView, shouldCollapseSubview subview: NSView, forDoubleClickOnDividerAt dividerIndex: Int) -> Bool {
            return false // Disable double-click to collapse
        }

        func splitView(_ splitView: NSSplitView, resizeSubviewsWithOldSize oldSize: NSSize) {
            guard let leftHost = leftHost, let rightHost = rightHost else {
                splitView.adjustSubviews()
                return
            }

            let newSize = splitView.frame.size
            let totalWidth = newSize.width
            let totalHeight = newSize.height

            if isFixedSidebar {
                // Fixed sidebar: simple fixed width
                let sidebarWidth = fixedSidebarWidth
                let contentWidth = totalWidth - sidebarWidth

                leftHost.frame = NSRect(x: 0, y: 0, width: sidebarWidth, height: totalHeight)
                rightHost.frame = NSRect(x: sidebarWidth, y: 0, width: contentWidth, height: totalHeight)
            } else {
                // Priority-based resizing: sidebar has fixed desired width, content gets remaining space
                let desiredSidebarWidth: CGFloat = {
                    // If this is initial sizing (no previous size), use last user width or default
                    if oldSize.width == 0 {
                        return max(lastUserSidebarWidth, minSidebarWidth)
                    }

                    // During resize, maintain current sidebar width and update our tracking
                    let currentSidebarWidth = leftHost.frame.width

                    // Only update lastUserSidebarWidth if sidebar is visible and not at minimum
                    if !leftHost.isHidden && currentSidebarWidth > minSidebarWidth {
                        lastUserSidebarWidth = currentSidebarWidth
                    }

                    return max(minSidebarWidth, min(currentSidebarWidth, totalWidth - 400))
                }()

                let constrainedSidebarWidth = max(minSidebarWidth, min(desiredSidebarWidth, totalWidth - 400))
                let contentWidth = totalWidth - constrainedSidebarWidth

                // Apply the frames
                leftHost.frame = NSRect(x: 0, y: 0, width: constrainedSidebarWidth, height: totalHeight)
                rightHost.frame = NSRect(x: constrainedSidebarWidth, y: 0, width: contentWidth, height: totalHeight)
            }
        }

        // Track when user manually resizes to update binding
        @objc func splitViewDidResizeSubviews(_ notification: Notification) {
            guard let splitView = notification.object as? NSSplitView,
                  splitView == self.splitView,
                  let leftHost = leftHost else { return }

            // Update binding based on actual visibility
            let isVisible = !leftHost.isHidden
            sidebarVisibilityBinding?.wrappedValue = isVisible
        }

        // Handle sidebar toggle notification
        @objc func handleSidebarToggle(_ notification: Notification) {
            guard let sourceWindow = notification.object as? NSWindow,
                  let myWindow = splitView?.window,
                  sourceWindow == myWindow else { return }

            toggleSidebar()
        }

        deinit {
            NotificationCenter.default.removeObserver(self)
        }
    }
}

// Custom NSSplitView subclass for styling
private class CustomNSSplitView: NSSplitView {
    private var isDividerVisible = false
    private var trackingArea: NSTrackingArea?
    var isFixedSidebar: Bool = false
    var fixedSidebarWidth: CGFloat = 50
    var minSidebarWidth: CGFloat = 290

    override func awakeFromNib() {
        super.awakeFromNib()
        setupDividerTracking()
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if window != nil {
            setupDividerTracking()
        }
    }


    private func setupDividerTracking() {
        // Fixed sidebar doesn't need divider tracking
        if isFixedSidebar {
            return
        }

        // Remove existing tracking area
        if let existingArea = trackingArea {
            removeTrackingArea(existingArea)
        }

        // Create new tracking area for the entire split view
        trackingArea = NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .mouseMoved, .activeInKeyWindow, .inVisibleRect],
            owner: self,
            userInfo: nil
        )

        if let trackingArea = trackingArea {
            addTrackingArea(trackingArea)
        }
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        setupDividerTracking()
    }

    override func mouseMoved(with event: NSEvent) {
        super.mouseMoved(with: event)
        updateDividerVisibility(for: event)
    }

    override func mouseEntered(with event: NSEvent) {
        super.mouseEntered(with: event)
        updateDividerVisibility(for: event)
    }

    override func mouseExited(with event: NSEvent) {
        super.mouseExited(with: event)
        isDividerVisible = false
        needsDisplay = true
    }

    private func updateDividerVisibility(for event: NSEvent) {
        let location = convert(event.locationInWindow, from: nil)
        let dividerRect = dividerRect(at: 0)

        // Check if mouse is within 10 pixels of the divider
        let threshold: CGFloat = 10
        let expandedDividerRect = dividerRect.insetBy(dx: -threshold, dy: 0)

        let shouldShowDivider = expandedDividerRect.contains(location)

        if shouldShowDivider != isDividerVisible {
            isDividerVisible = shouldShowDivider
            needsDisplay = true
        }
    }

    private func dividerRect(at index: Int) -> NSRect {
        guard index == 0, arrangedSubviews.count >= 2 else { return .zero }

        let leftView = arrangedSubviews[0]
        let dividerX = leftView.frame.maxX
        return NSRect(
            x: dividerX,
            y: 0,
            width: dividerThickness,
            height: frame.height
        )
    }

    override var dividerThickness: CGFloat {
        if isFixedSidebar {
            return 0 // No divider for fixed sidebar
        }
        return 2.0 // Thin divider line for resizable sidebar
    }

    override func drawDivider(in rect: NSRect) {
        // Fixed sidebar has no divider
        if isFixedSidebar {
            return
        }

        // Only draw divider when cursor is near
        if isDividerVisible {
            NSColor.separatorColor.setFill()
            rect.fill()
        }
        // Otherwise, draw nothing (invisible divider)
    }
}
