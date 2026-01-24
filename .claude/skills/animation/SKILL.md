# macOS Animation Best Practices

> Adapted from Emil Kowalski's "7 Practical Animation Tips" for Swift/SwiftUI/AppKit development

## Overview

This skill provides practical animation guidelines for building polished macOS applications. These principles help create interfaces that feel responsive, natural, and professional without requiring deep animation expertise.

**Core Philosophy**: Animations should feel like magic to users, but they're built on learnable principles. Good animation makes interfaces feel responsive and alive.

---

## 1. Scale Buttons on Press

**Principle**: The interface should feel like it's listening to the user. Provide immediate feedback on all interactions.

### SwiftUI Implementation

```swift
struct ScalableButton: View {
    let title: String
    let action: () -> Void

    @State private var isPressed = false

    var body: some View {
        Button(action: action) {
            Text(title)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color.accentColor)
                .foregroundColor(.white)
                .cornerRadius(8)
        }
        .buttonStyle(.plain)
        .scaleEffect(isPressed ? 0.97 : 1.0)
        .animation(.easeOut(duration: 0.1), value: isPressed)
        .onLongPressGesture(minimumDuration: .infinity, pressing: { pressing in
            isPressed = pressing
        }, perform: {})
    }
}

// Reusable button style
struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.easeOut(duration: 0.1), value: configuration.isPressed)
    }
}

// Usage
Button("Submit") { }
    .buttonStyle(ScaleButtonStyle())
```

### AppKit Implementation

```swift
class ScalableButton: NSButton {
    override func mouseDown(with event: NSEvent) {
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.1
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            self.animator().layer?.setAffineTransform(CGAffineTransform(scaleX: 0.97, y: 0.97))
        }
        super.mouseDown(with: event)
    }

    override func mouseUp(with event: NSEvent) {
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.1
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            self.animator().layer?.setAffineTransform(.identity)
        }
        super.mouseUp(with: event)
    }
}
```

**Key Value**: `0.97` scale factor — subtle but noticeable feedback.

---

## 2. Never Animate from scale(0)

**Principle**: Elements animating from `scale(0)` feel unnatural. Start from `0.9+` for gentle, elegant motion.

### Why It Matters

- `scale(0)` makes elements appear from nowhere — feels jarring
- Higher initial scale resembles real-world physics (like a balloon — even deflated, it has shape)
- Creates smoother, more professional transitions

### SwiftUI Implementation

```swift
struct PopoverContent: View {
    @Binding var isPresented: Bool

    var body: some View {
        VStack {
            // Content
        }
        .scaleEffect(isPresented ? 1.0 : 0.93)  // NOT 0.0!
        .opacity(isPresented ? 1.0 : 0.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isPresented)
    }
}

// Transition modifier for appearing views
extension AnyTransition {
    static var gentleScale: AnyTransition {
        .scale(scale: 0.93)  // Start from 0.93, not 0
        .combined(with: .opacity)
    }
}

// Usage
if showPopover {
    PopoverView()
        .transition(.gentleScale)
}
```

### AppKit Implementation

```swift
func showPopover(_ view: NSView) {
    view.alphaValue = 0
    view.layer?.transform = CATransform3DMakeScale(0.93, 0.93, 1)  // NOT 0!

    NSAnimationContext.runAnimationGroup { context in
        context.duration = 0.2
        context.timingFunction = CAMediaTimingFunction(name: .easeOut)
        view.animator().alphaValue = 1
        view.animator().layer?.transform = CATransform3DIdentity
    }
}
```

**Key Value**: Start scale at `0.93` or higher, never `0`.

---

## 3. Skip Delays on Subsequent Tooltips

**Principle**: Once a tooltip is shown, hovering over other tooltips should be instant — no delay, no animation.

### SwiftUI Implementation

```swift
class TooltipManager: ObservableObject {
    @Published var activeTooltip: String?
    @Published var hasRecentlyShownTooltip = false

    private var hideTimer: Timer?
    private let initialDelay: TimeInterval = 0.5
    private let groupTimeout: TimeInterval = 0.3

    func showTooltip(id: String) {
        hideTimer?.invalidate()

        if hasRecentlyShownTooltip {
            // Instant switch — no delay, no animation
            activeTooltip = id
        } else {
            // First tooltip — use delay
            DispatchQueue.main.asyncAfter(deadline: .now() + initialDelay) { [weak self] in
                self?.activeTooltip = id
                self?.hasRecentlyShownTooltip = true
            }
        }
    }

    func hideTooltip() {
        hideTimer = Timer.scheduledTimer(withTimeInterval: groupTimeout, repeats: false) { [weak self] _ in
            self?.activeTooltip = nil
            self?.hasRecentlyShownTooltip = false
        }
    }
}

struct TooltipButton: View {
    let id: String
    let icon: String
    let tooltip: String
    @EnvironmentObject var tooltipManager: TooltipManager

    var body: some View {
        Button(action: {}) {
            Image(systemName: icon)
        }
        .onHover { hovering in
            if hovering {
                tooltipManager.showTooltip(id: id)
            } else {
                tooltipManager.hideTooltip()
            }
        }
        .overlay(alignment: .bottom) {
            if tooltipManager.activeTooltip == id {
                TooltipView(text: tooltip)
                    .transition(tooltipManager.hasRecentlyShownTooltip
                        ? .identity  // No animation for subsequent
                        : .scale(scale: 0.97).combined(with: .opacity))
            }
        }
    }
}
```

**Key Insight**: Track tooltip group state to skip animations after the first one.

---

## 4. Choose the Right Easing

**Principle**: Easing is the most important part of any animation. It can make a bad animation look great, and vice versa.

### Easing Guidelines

| Animation Type   | Recommended Easing | Why                              |
| ---------------- | ------------------ | -------------------------------- |
| **Enter/Appear** | `easeOut`          | Fast start feels responsive      |
| **Exit/Dismiss** | `easeIn`           | Accelerates away naturally       |
| **State change** | `easeInOut`        | Smooth for on-screen transitions |
| **Interactive**  | `spring`           | Natural, physics-based feel      |

### SwiftUI Custom Easings

```swift
// Built-in easings are often too subtle. Use custom curves for more impact.

extension Animation {
    // Snappy ease-out for responsive UI
    static let snappyEaseOut = Animation.timingCurve(0.25, 1, 0.5, 1, duration: 0.2)

    // Energetic ease-in-out
    static let energeticEaseInOut = Animation.timingCurve(0.4, 0, 0.2, 1, duration: 0.25)

    // Quick spring for interactive elements
    static let quickSpring = Animation.spring(response: 0.3, dampingFraction: 0.7)

    // Smooth spring for larger movements
    static let smoothSpring = Animation.spring(response: 0.5, dampingFraction: 0.8)
}

// Usage
struct DropdownMenu: View {
    @State private var isOpen = false

    var body: some View {
        VStack {
            Button("Options") { isOpen.toggle() }

            if isOpen {
                MenuContent()
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        // Use snappy ease-out, NOT ease-in
        .animation(.snappyEaseOut, value: isOpen)
    }
}
```

### AppKit Custom Timing Functions

```swift
extension CAMediaTimingFunction {
    // Snappy ease-out
    static let snappyEaseOut = CAMediaTimingFunction(controlPoints: 0.25, 1, 0.5, 1)

    // Energetic ease-in-out
    static let energeticEaseInOut = CAMediaTimingFunction(controlPoints: 0.4, 0, 0.2, 1)

    // Standard Material Design easing
    static let materialStandard = CAMediaTimingFunction(controlPoints: 0.4, 0, 0.2, 1)
}

// Usage
NSAnimationContext.runAnimationGroup { context in
    context.duration = 0.2
    context.timingFunction = .snappyEaseOut
    view.animator().alphaValue = 1
}
```

**Key Insight**: Default CSS/SwiftUI easings are too weak. Use custom curves with more aggressive control points.

---

## 5. Make Animations Origin-Aware

**Principle**: Popovers and menus should scale from their trigger point, not from center.

### SwiftUI Implementation

```swift
struct OriginAwarePopover<Content: View>: View {
    @Binding var isPresented: Bool
    let anchor: Anchor<CGRect>?
    let content: () -> Content

    var body: some View {
        GeometryReader { geometry in
            if isPresented, let anchor = anchor {
                let anchorRect = geometry[anchor]
                let origin = calculateTransformOrigin(anchorRect: anchorRect, in: geometry.size)

                content()
                    .scaleEffect(isPresented ? 1.0 : 0.93, anchor: origin)
                    .opacity(isPresented ? 1.0 : 0.0)
                    .animation(.snappyEaseOut, value: isPresented)
            }
        }
    }

    private func calculateTransformOrigin(anchorRect: CGRect, in size: CGSize) -> UnitPoint {
        let x = anchorRect.midX / size.width
        let y = anchorRect.midY / size.height
        return UnitPoint(x: x, y: y)
    }
}

// Simpler approach with explicit anchor
struct ScaleFromAnchor: ViewModifier {
    let isPresented: Bool
    let anchor: UnitPoint

    func body(content: Content) -> some View {
        content
            .scaleEffect(isPresented ? 1.0 : 0.93, anchor: anchor)
            .opacity(isPresented ? 1.0 : 0.0)
            .animation(.spring(response: 0.25, dampingFraction: 0.8), value: isPresented)
    }
}

// Usage
struct FeedbackButton: View {
    @State private var showPopover = false

    var body: some View {
        Button("Feedback") { showPopover.toggle() }
            .popover(isPresented: $showPopover) {
                FeedbackForm()
            }
        // For custom popovers, use anchor: .topLeading, .bottomTrailing, etc.
    }
}
```

### AppKit Implementation

```swift
func showPopover(from button: NSButton, content: NSView) {
    // Calculate anchor point relative to the button
    let buttonFrame = button.convert(button.bounds, to: nil)
    let windowFrame = button.window?.frame ?? .zero

    // Set anchor point (0,0 = bottom-left, 1,1 = top-right)
    let anchorX = buttonFrame.midX / windowFrame.width
    let anchorY = buttonFrame.midY / windowFrame.height

    content.layer?.anchorPoint = CGPoint(x: anchorX, y: anchorY)
    content.layer?.transform = CATransform3DMakeScale(0.93, 0.93, 1)
    content.alphaValue = 0

    NSAnimationContext.runAnimationGroup { context in
        context.duration = 0.2
        context.timingFunction = .snappyEaseOut
        content.animator().layer?.transform = CATransform3DIdentity
        content.animator().alphaValue = 1
    }
}
```

**Key Insight**: The default `center` origin is wrong for most UI. Match origin to trigger location.

---

## 6. Keep Animations Fast

**Principle**: Faster animations improve perceived performance. UI animations should stay under 300ms.

### Duration Guidelines

| Animation Type     | Recommended Duration           |
| ------------------ | ------------------------------ |
| Button feedback    | 100ms                          |
| Tooltips           | 125-150ms                      |
| Dropdowns/Popovers | 150-200ms                      |
| Page transitions   | 200-300ms                      |
| Loading spinners   | Faster = feels more responsive |

### SwiftUI Constants

```swift
enum AnimationDuration {
    static let instant: Double = 0.1
    static let fast: Double = 0.15
    static let normal: Double = 0.2
    static let slow: Double = 0.3

    // Never exceed for UI animations
    static let maximum: Double = 0.3
}

extension Animation {
    static let buttonFeedback = Animation.easeOut(duration: AnimationDuration.instant)
    static let tooltip = Animation.easeOut(duration: AnimationDuration.fast)
    static let popover = Animation.spring(response: 0.2, dampingFraction: 0.8)
    static let pageTransition = Animation.easeInOut(duration: AnimationDuration.slow)
}
```

### When to Remove Animations

Remove or minimize animations for frequently-used interactions:

```swift
struct FrequentListItem: View {
    let item: Item
    @State private var isHovered = false

    // For items interacted with 100+ times/day, skip hover animations
    var body: some View {
        HStack {
            Text(item.title)
            Spacer()
        }
        .background(isHovered ? Color.gray.opacity(0.1) : Color.clear)
        // NO animation modifier — instant feedback for frequent actions
        .onHover { isHovered = $0 }
    }
}
```

**Key Insight**: Animation that delights once becomes annoying after 100 repetitions. Remove animations from high-frequency interactions.

---

## 7. Use Blur to Mask Imperfections

**Principle**: When easing and duration adjustments don't feel right, blur bridges visual gaps between states.

### SwiftUI Implementation

```swift
struct BlurredTransitionButton: View {
    @State private var isLoading = false
    @State private var isComplete = false

    var body: some View {
        Button(action: { startAction() }) {
            ZStack {
                // Idle state
                Label("Submit", systemImage: "arrow.right")
                    .opacity(isLoading || isComplete ? 0 : 1)
                    .blur(radius: isLoading || isComplete ? 2 : 0)

                // Loading state
                ProgressView()
                    .opacity(isLoading ? 1 : 0)
                    .blur(radius: isLoading ? 0 : 2)

                // Complete state
                Label("Done", systemImage: "checkmark")
                    .opacity(isComplete ? 1 : 0)
                    .blur(radius: isComplete ? 0 : 2)
            }
            .animation(.easeOut(duration: 0.2), value: isLoading)
            .animation(.easeOut(duration: 0.2), value: isComplete)
        }
        .buttonStyle(ScaleButtonStyle())  // Tip #1
    }

    private func startAction() {
        isLoading = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            isLoading = false
            isComplete = true
        }
    }
}

// Reusable blur transition
struct BlurTransition: ViewModifier {
    let isVisible: Bool
    let blurRadius: CGFloat

    func body(content: Content) -> some View {
        content
            .opacity(isVisible ? 1 : 0)
            .blur(radius: isVisible ? 0 : blurRadius)
    }
}

extension View {
    func blurTransition(isVisible: Bool, radius: CGFloat = 2) -> some View {
        modifier(BlurTransition(isVisible: isVisible, blurRadius: radius))
    }
}

// Usage
Text("State A").blurTransition(isVisible: showA)
Text("State B").blurTransition(isVisible: showB)
```

### Why Blur Works

- Bridges the visual gap between old and new states
- Tricks the eye into seeing smooth transition
- Blends distinct states together naturally
- Masks timing imperfections

**Key Value**: `2px` blur radius is usually sufficient.

---

## Quick Reference Card

```swift
// 1. Scale buttons on press
.scaleEffect(isPressed ? 0.97 : 1.0)

// 2. Never animate from scale(0)
.scaleEffect(isPresented ? 1.0 : 0.93)  // NOT 0!

// 3. Skip delays on subsequent tooltips
// Track tooltip group state, use .identity transition after first

// 4. Use proper easing
.animation(.timingCurve(0.25, 1, 0.5, 1, duration: 0.2))  // snappy ease-out

// 5. Origin-aware scaling
.scaleEffect(isPresented ? 1.0 : 0.93, anchor: .topLeading)

// 6. Keep animations fast
// Max 300ms, prefer 150-200ms for UI elements

// 7. Blur to mask imperfections
.blur(radius: isVisible ? 0 : 2)
```

---

## Common Anti-Patterns to Avoid

| ❌ Don't                             | ✅ Do Instead                     |
| ------------------------------------ | --------------------------------- |
| `scale(0)` entry                     | `scale(0.93)` entry               |
| `ease-in` for appearing elements     | `ease-out` for appearing elements |
| Default `center` transform origin    | Match origin to trigger location  |
| 400ms+ UI animations                 | Keep under 300ms                  |
| Animations on high-frequency actions | Remove or minimize animations     |
| Abrupt state crossfades              | Add subtle blur (2px)             |

---

## Integration Checklist

When implementing animations:

- [ ] Buttons have press feedback (0.97 scale)
- [ ] Appearing elements start at 0.93+ scale
- [ ] Tooltips skip delay after first one shown
- [ ] Using ease-out for entries, custom curves for impact
- [ ] Transform origins match trigger locations
- [ ] All UI animations under 300ms
- [ ] High-frequency interactions have minimal/no animation
- [ ] State transitions use blur when crossfade feels off

---

## References

- Original article: [emilkowal.ski/ui/7-practical-animation-tips](https://emilkowal.ski/ui/7-practical-animation-tips)
- Custom easing curves: [easings.co](https://easings.co/)
- Apple HIG on Motion: [developer.apple.com/design/human-interface-guidelines/motion](https://developer.apple.com/design/human-interface-guidelines/motion)
