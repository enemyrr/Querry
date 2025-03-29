//
//  SwipeDetection.swift
//  Collection
//
//  Created by Fauzaan on 1/17/25.
//

import SwiftUI
import MongoKitten
import AppKit

struct SwipeDetectionView: NSViewRepresentable {
    @Binding var sidebarActiveTab: SidebarTab
    @Binding var scrollOffset: CGFloat
    let viewWidth: CGFloat
    
    class Coordinator: NSObject {
        var parent: SwipeDetectionView
        var accumulatedScrollDeltaX: CGFloat = 0
        let threshold: CGFloat
        var lastScrollTime: TimeInterval = 0
        var scrollVelocity: CGFloat = 0
        var hasTransitioned = false
        var monitor: Any?
        weak var trackingView: NSView?
        
        init(parent: SwipeDetectionView) {
            self.parent = parent
            self.threshold = parent.viewWidth * 0.4
        }
        
        func startMonitoring() {
            monitor = NSEvent.addLocalMonitorForEvents(matching: [.scrollWheel]) { [weak self] event in
                guard let self = self, let view = self.trackingView else { return event }
                
                // Convert screen coordinates to view coordinates
                let locationInWindow = event.locationInWindow
                let locationInView = view.convert(locationInWindow, from: nil)
                
                // Only process if mouse is within view bounds
                if view.bounds.contains(locationInView) {
                    self.handleEvent(event)
                }
                
                return event
            }
        }
        
        func stopMonitoring() {
            if let monitor = monitor {
                NSEvent.removeMonitor(monitor)
                self.monitor = nil
            }
        }
        
        deinit {
            stopMonitoring()
        }
        
        func handleEvent(_ event: NSEvent) {
            // Early return if vertical scroll is within ignore threshold
            let verticalScrollThreshold: CGFloat = 0
            if abs(event.scrollingDeltaY) > verticalScrollThreshold {
                // Ignore small vertical scrolls
                return
            }
            
            let currentTime = ProcessInfo.processInfo.systemUptime
            let timeDelta = currentTime - lastScrollTime
            lastScrollTime = currentTime
            
            let dampingFactor: CGFloat = 0.3
            let scaledDelta = event.scrollingDeltaX * dampingFactor
            
            if timeDelta > 0 {
                scrollVelocity = scaledDelta / CGFloat(timeDelta)
            }
            
            accumulatedScrollDeltaX += scaledDelta
            
            // Update position
            switch parent.sidebarActiveTab {
            case .connections:
                parent.scrollOffset = min(0, accumulatedScrollDeltaX)
            case .connection_details:
                parent.scrollOffset = max(-parent.viewWidth, -parent.viewWidth + accumulatedScrollDeltaX)
            }
            
            // Process transitions
            let isFastScroll = abs(scrollVelocity) > 350
            let shouldTransition = abs(accumulatedScrollDeltaX) > (isFastScroll ? 0 : threshold)

            if (shouldTransition) {
                handleTransition()
            }
            
            if event.phase == .ended || event.momentumPhase == .ended {
                handleScrollEnd(shouldTransition: shouldTransition)
            }
        }
        
        private func handleTransition() {
            switch parent.sidebarActiveTab {
            case .connections where accumulatedScrollDeltaX < 0:
                withAnimation(.spring(duration: 0.3)) {
                    parent.scrollOffset = -parent.viewWidth
                    parent.sidebarActiveTab = .connection_details
                }
                hasTransitioned = true
            case .connection_details where accumulatedScrollDeltaX > 0:
                withAnimation(.spring(duration: 0.3)) {
                    parent.scrollOffset = 0
                    parent.sidebarActiveTab = .connections
                }
                hasTransitioned = true
            default:
                break
            }
        }
        
        private func handleScrollEnd(shouldTransition: Bool) {
            if !hasTransitioned {
                if shouldTransition {
                    switch parent.sidebarActiveTab {
                    case .connections where accumulatedScrollDeltaX < 0:
                        withAnimation(.spring(duration: 0.3)) {
                            parent.scrollOffset = -parent.viewWidth
                            parent.sidebarActiveTab = .connection_details
                        }
                    case .connection_details where accumulatedScrollDeltaX > 0:
                        withAnimation(.spring(duration: 0.3)) {
                            parent.scrollOffset = 0
                            parent.sidebarActiveTab = .connections
                        }
                    default:
                        resetPosition()
                    }
                } else {
                    resetPosition()
                }
            }
            
            accumulatedScrollDeltaX = 0
            hasTransitioned = false
        }
        
        private func resetPosition() {
            withAnimation(.spring(duration: 0.1)) {
                parent.scrollOffset = parent.sidebarActiveTab == .connections ? 0 : -parent.viewWidth
            }
        }
    }
    
    func makeCoordinator() -> Coordinator {
        return Coordinator(parent: self)
    }
    
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        context.coordinator.trackingView = view
        context.coordinator.startMonitoring()
        return view
    }
    
    func updateNSView(_ nsView: NSView, context: Context) {}
    
    static func dismantleNSView(_ nsView: NSView, coordinator: Coordinator) {
        coordinator.stopMonitoring()
    }
}


struct SwipePageIndicator: View {
    let scrollOffset: CGFloat
    let width: CGFloat
    var onPageChange: (Int) -> Void
    
    private let dotSize: CGFloat = 6
    private let spacing: CGFloat = 8
    
    private var leftDotOpacity: Double {
        let progress = -scrollOffset / width
        return 0.8 - (progress * 0.5)
    }
    
    private var rightDotOpacity: Double {
        let progress = -scrollOffset / width
        return 0.3 + (progress * 0.5)
    }
    
    var body: some View {
        HStack(spacing: spacing) {
            Circle()
                .fill(Color.secondary.opacity(leftDotOpacity))
                .frame(width: dotSize, height: dotSize)
                .onTapGesture {
                    onPageChange(0)  // Navigate to databases
                }
            
            Circle()
                .fill(Color.secondary.opacity(rightDotOpacity))
                .frame(width: dotSize, height: dotSize)
                .onTapGesture {
                    onPageChange(1)  // Navigate to collections
                }
        }
    }
}

extension CGFloat {
    func clamp(min minValue: CGFloat, max maxValue: CGFloat) -> CGFloat {
        return Swift.min(maxValue, Swift.max(minValue, self))
    }
}
