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

        // Don't interfere with ongoing animations
        if context.coordinator.isCurrentlyAnimating {
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

        // Exposed for applyVisibility to check
        var isCurrentlyAnimating: Bool { isAnimating || isFadeAnimating }

        private var isAnimating = false
        private var isFadeAnimating = false
        private var animationTimer: DispatchSourceTimer?
        private var animationStartTime: CFTimeInterval = 0
        private var animationStartPosition: CGFloat = 0
        private var animationTargetPosition: CGFloat = 0
        private var isCollapsing = false

        // Animation timing
        private let animationDuration: CFTimeInterval = 0.2
        private let fadeDuration: CFTimeInterval = 0.08

        private var animationCompletionHandler: (() -> Void)?

        // MARK: - Native Sidebar Collapse Methods

        func toggleSidebar() {
            guard let leftHost else { return }
            if isFixedSidebar || isAnimating { return }

            if leftHost.isHidden {
                expandSidebar(leftHost)
            } else {
                collapseSidebar(leftHost)
            }
        }

        private func expandSidebar(_ leftHost: NSView) {
            let expandWidth = max(lastUserSidebarWidth, minSidebarWidth)
            leftHost.isHidden = false
            leftHost.wantsLayer = true
            leftHost.alphaValue = 1.0
            isCollapsing = false
            sidebarVisibilityBinding?.wrappedValue = true

            // Enable rasterization on right content to avoid live layout during animation
            enableContentRasterization()

            // Notify that animation is starting (for table performance optimization)
            NotificationCenter.default.post(name: .sidebarAnimationWillStart, object: splitView?.window)

            animateSidebarPosition(from: 0, to: expandWidth, collapsing: false)
        }

        private func collapseSidebar(_ leftHost: NSView) {
            lastUserSidebarWidth = leftHost.frame.width
            isFadeAnimating = true
            isCollapsing = true
            leftHost.wantsLayer = true

            // Enable rasterization on right content to avoid live layout during animation
            enableContentRasterization()

            // Notify that animation is starting (for table performance optimization)
            NotificationCenter.default.post(name: .sidebarAnimationWillStart, object: splitView?.window)

            // Fade out using Core Animation directly (more efficient)
            let fadeAnim = CABasicAnimation(keyPath: "opacity")
            fadeAnim.fromValue = 1.0
            fadeAnim.toValue = 0.0
            fadeAnim.duration = fadeDuration
            fadeAnim.timingFunction = CAMediaTimingFunction(name: .easeOut)
            fadeAnim.fillMode = .forwards
            fadeAnim.isRemovedOnCompletion = false
            leftHost.layer?.add(fadeAnim, forKey: "fade")
            leftHost.alphaValue = 0.0

            // Start width collapse after 30% of fade (creates overlap)
            let phase2Delay = fadeDuration * 0.3
            DispatchQueue.main.asyncAfter(deadline: .now() + phase2Delay) { [weak self] in
                guard let self else { return }
                self.isFadeAnimating = false
                self.sidebarVisibilityBinding?.wrappedValue = false
                self.animateSidebarPosition(from: self.lastUserSidebarWidth, to: 0, collapsing: true)
            }
        }

        private func animateSidebarPosition(from startPos: CGFloat, to endPos: CGFloat, collapsing: Bool, onComplete: (() -> Void)? = nil) {
            isAnimating = true
            isCollapsing = collapsing
            animationStartPosition = startPos
            animationTargetPosition = endPos
            animationStartTime = CACurrentMediaTime()
            animationCompletionHandler = onComplete

            // Use DispatchSourceTimer for precise timing (better than Timer)
            stopAnimation()
            let timer = DispatchSource.makeTimerSource(queue: .main)
            timer.schedule(deadline: .now(), repeating: .milliseconds(8)) // ~120fps
            timer.setEventHandler { [weak self] in
                self?.updateAnimation()
            }
            animationTimer = timer
            timer.resume()
        }

        private func updateAnimation() {
            guard let splitView = splitView else {
                finishAnimation()
                return
            }

            let elapsed = CACurrentMediaTime() - animationStartTime
            let progress = min(1.0, elapsed / animationDuration)

            // EaseOut curve: 1 - (1 - t)^3 (cubic ease out - fast start, smooth end)
            let easedProgress = 1.0 - pow(1.0 - progress, 3)

            let currentPosition = animationStartPosition + (animationTargetPosition - animationStartPosition) * easedProgress

            splitView.setPosition(currentPosition, ofDividerAt: 0)

            if progress >= 1.0 {
                finishAnimation()
            }
        }

        private func stopAnimation() {
            animationTimer?.cancel()
            animationTimer = nil
        }

        private func enableContentRasterization() {
            guard let rightHost = rightHost else { return }
            rightHost.wantsLayer = true
            rightHost.layer?.shouldRasterize = true
            rightHost.layer?.rasterizationScale = NSScreen.main?.backingScaleFactor ?? 2.0
            rightHost.layerContentsRedrawPolicy = .onSetNeedsDisplay
        }

        private func disableContentRasterization() {
            guard let rightHost = rightHost else { return }
            rightHost.layer?.shouldRasterize = false
            rightHost.layerContentsRedrawPolicy = .duringViewResize
        }

        private func finishAnimation() {
            stopAnimation()
            isAnimating = false

            // Ensure final position is exact
            splitView?.setPosition(animationTargetPosition, ofDividerAt: 0)

            // Hide the view after collapse animation completes
            if isCollapsing {
                leftHost?.isHidden = true
                leftHost?.layer?.removeAnimation(forKey: "fade")
                leftHost?.alphaValue = 1.0  // Reset for next show
            }

            // Remove rasterization to return to live rendering
            disableContentRasterization()

            // Notify that animation has ended (for table performance optimization)
            NotificationCenter.default.post(name: .sidebarAnimationDidEnd, object: splitView?.window)

            // Call completion handler if set
            animationCompletionHandler?()
            animationCompletionHandler = nil
        }

        // MARK: - NSSplitViewDelegate

        func splitView(_ splitView: NSSplitView, constrainMinCoordinate proposedMinimumPosition: CGFloat, ofSubviewAt dividerIndex: Int) -> CGFloat {
            if isFixedSidebar {
                return fixedSidebarWidth // Fixed width
            }
            // During animation, allow position to go to 0
            if isAnimating {
                return 0
            }
            return minSidebarWidth // Minimum width for resizable sidebars
        }

        func splitView(_ splitView: NSSplitView, constrainMaxCoordinate proposedMaximumPosition: CGFloat, ofSubviewAt dividerIndex: Int) -> CGFloat {
            if isFixedSidebar {
                return fixedSidebarWidth // Fixed width
            }
            // Allow sidebar to take up to half the window width
            return splitView.frame.width / 2
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

            // During animation, let the split view handle its own layout
            if isAnimating {
                splitView.adjustSubviews()
                return
            }

            let newSize = splitView.frame.size
            let totalWidth = newSize.width
            let totalHeight = newSize.height
            let dividerWidth = splitView.dividerThickness

            if isFixedSidebar {
                // Fixed sidebar: simple fixed width
                let sidebarWidth = fixedSidebarWidth
                let contentWidth = totalWidth - sidebarWidth

                leftHost.frame = NSRect(x: 0, y: 0, width: sidebarWidth, height: totalHeight)
                rightHost.frame = NSRect(x: sidebarWidth, y: 0, width: contentWidth, height: totalHeight)
            } else {
                // Keep sidebar at its current width, only resize content
                let currentSidebarWidth = leftHost.frame.width
                let sidebarWidth = max(minSidebarWidth, currentSidebarWidth)

                // Track user's preferred width
                if !leftHost.isHidden && sidebarWidth > minSidebarWidth {
                    lastUserSidebarWidth = sidebarWidth
                }

                let contentWidth = totalWidth - sidebarWidth - dividerWidth

                leftHost.frame = NSRect(x: 0, y: 0, width: sidebarWidth, height: totalHeight)
                rightHost.frame = NSRect(x: sidebarWidth + dividerWidth, y: 0, width: contentWidth, height: totalHeight)
            }
        }

        // Track when user manually resizes to update binding
        @objc func splitViewDidResizeSubviews(_ notification: Notification) {
            guard let splitView = notification.object as? NSSplitView,
                  splitView == self.splitView,
                  let leftHost = leftHost else { return }

            // Don't update binding during animation - we control it explicitly
            if isCurrentlyAnimating {
                return
            }

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
            animationTimer?.cancel()
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
