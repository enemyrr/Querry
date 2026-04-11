import AppKit
import SwiftUI

@MainActor
final class QuickLookViewController: NSViewController {
    private static let defaultContentSize = NSSize(width: 450, height: 150)
    private static var lastUsedContentSize: NSSize?
    private static let minimumContentSize = NSSize(width: 360, height: 140)
    private static let resizeHandleEdgeInset: CGFloat = 2
    private static let resizeHandleSize: CGFloat = 20
    private static let resizeHandleGutterWidth: CGFloat = 28
    private static let contentWidthDefaultsKey = "quickLookPopover.contentWidth"
    private static let contentHeightDefaultsKey = "quickLookPopover.contentHeight"

    private let displayedInitialContent: String
    private let allowsSaveWithoutTextChanges: Bool
    private let onResizeStart: () -> Void
    private let onResize: (NSSize) -> Void
    private let onResizeEnd: () -> Void
    private let onSave: (String) -> Void
    private let onDismiss: () -> Void

    private weak var positioningView: NSView?
    private var positioningRect: NSRect = .zero
    private var isPopoverHovered = false
    private var textView: NSTextView!
    private var widthConstraint: NSLayoutConstraint!
    private var heightConstraint: NSLayoutConstraint!
    private var resizeHandleTopConstraint: NSLayoutConstraint!
    private var resizeHandleBottomConstraint: NSLayoutConstraint!
    private var resizeHandle: QuickLookResizeHandleView!
    private var lockedResizeHandlePlacement: ResizeHandlePlacement?
    private let buttonState = QuickLookButtonState()

    init(
        content: String,
        onResizeStart: @escaping () -> Void,
        onResize: @escaping (NSSize) -> Void,
        onResizeEnd: @escaping () -> Void,
        onSave: @escaping (String) -> Void,
        onDismiss: @escaping () -> Void
    ) {
        self.displayedInitialContent = Self.prettyJSON(content)
        self.allowsSaveWithoutTextChanges = self.displayedInitialContent != content
        self.onResizeStart = onResizeStart
        self.onResize = onResize
        self.onResizeEnd = onResizeEnd
        self.onSave = onSave
        self.onDismiss = onDismiss
        super.init(nibName: nil, bundle: nil)
        buttonState.isSaveEnabled = allowsSaveWithoutTextChanges
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError()
    }

    override func loadView() {
        let container = QuickLookHoverTrackingView()
        container.onHoverChange = { [weak self] isHovered in
            self?.isPopoverHovered = isHovered
            self?.updateResizeHandleVisibility()
        }
        let footerContainer = NSView()
        footerContainer.translatesAutoresizingMaskIntoConstraints = false

        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.borderType = .noBorder
        scrollView.drawsBackground = false
        scrollView.translatesAutoresizingMaskIntoConstraints = false

        let textView = NSTextView()
        textView.isEditable = true
        textView.isSelectable = true
        textView.isRichText = false
        textView.allowsUndo = true
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.textContainerInset = NSSize(width: 4, height: 4)
        textView.drawsBackground = false
        textView.font = .systemFont(ofSize: NSFont.systemFontSize)
        textView.string = displayedInitialContent
        textView.delegate = self
        textView.autoresizingMask = [.width]
        textView.textContainer?.widthTracksTextView = true

        scrollView.documentView = textView
        self.textView = textView

        let buttonBar = QuickLookButtonBar(
            state: buttonState,
            onSave: { [weak self] in self?.saveAction() },
            onCancel: { [weak self] in self?.cancelAction() }
        )
        let buttonHostingView = NSHostingView(rootView: buttonBar)
        buttonHostingView.translatesAutoresizingMaskIntoConstraints = false

        let resizeHandle = QuickLookResizeHandleView()
        resizeHandle.translatesAutoresizingMaskIntoConstraints = false
        resizeHandle.currentSize = { [weak self] in
            self?.currentContentSize ?? Self.defaultContentSize
        }
        resizeHandle.onResizeStart = { [weak self] in
            self?.onResizeStart()
        }
        resizeHandle.onResize = { [weak self] proposedSize in
            self?.updateContentSize(to: proposedSize)
        }
        resizeHandle.onResizeEnd = { [weak self] in
            self?.onResizeEnd()
        }
        resizeHandle.onDragStateChange = { [weak self] _ in
            self?.updateResizeHandleVisibility()
        }
        self.resizeHandle = resizeHandle

        container.addSubview(scrollView)
        container.addSubview(footerContainer)
        container.addSubview(resizeHandle)
        footerContainer.addSubview(buttonHostingView)

        let initialSize = Self.lastUsedContentSize ?? Self.restoredContentSize ?? Self.defaultContentSize
        widthConstraint = container.widthAnchor.constraint(equalToConstant: initialSize.width)
        heightConstraint = container.heightAnchor.constraint(equalToConstant: initialSize.height)
        resizeHandleTopConstraint = resizeHandle.topAnchor.constraint(equalTo: container.topAnchor, constant: Self.resizeHandleEdgeInset)
        resizeHandleBottomConstraint = resizeHandle.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -Self.resizeHandleEdgeInset)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: container.topAnchor, constant: 10),
            scrollView.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 8),
            scrollView.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -Self.resizeHandleGutterWidth),
            scrollView.bottomAnchor.constraint(equalTo: footerContainer.topAnchor, constant: -8),

            footerContainer.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 10),
            footerContainer.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -10),
            footerContainer.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -8),
            footerContainer.heightAnchor.constraint(equalToConstant: 28),

            buttonHostingView.leadingAnchor.constraint(equalTo: footerContainer.leadingAnchor),
            buttonHostingView.centerYAnchor.constraint(equalTo: footerContainer.centerYAnchor),

            resizeHandle.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -Self.resizeHandleEdgeInset),
            resizeHandle.widthAnchor.constraint(equalToConstant: Self.resizeHandleSize),
            resizeHandle.heightAnchor.constraint(equalToConstant: Self.resizeHandleSize),

            widthConstraint,
            heightConstraint,
        ])

        resizeHandleBottomConstraint.isActive = true
        preferredContentSize = initialSize
        self.view = container
        updateResizeHandleVisibility()
    }

    override func viewDidAppear() {
        super.viewDidAppear()
        updateContentSize(to: currentContentSize)
        resolveInitialResizeBehaviorIfNeeded()
        (view as? QuickLookHoverTrackingView)?.refreshHoverState()
        view.window?.makeFirstResponder(textView)
        textView.setSelectedRange(NSRange(location: textView.string.count, length: 0))
    }

    override func viewDidLayout() {
        super.viewDidLayout()
        resolveInitialResizeBehaviorIfNeeded()
    }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 { // Escape
            cancelAction()
            return
        }

        if event.modifierFlags.contains(.command), event.keyCode == 36 { // Cmd+Return
            if buttonState.isSaveEnabled {
                saveAction()
            }
            return
        }

        super.keyDown(with: event)
    }

    private func saveAction() {
        onSave(Self.compactJSON(textView.string))
        onDismiss()
    }

    private func cancelAction() {
        onDismiss()
    }

    private var currentContentSize: NSSize {
        NSSize(width: widthConstraint.constant, height: heightConstraint.constant)
    }

    private func updateContentSize(to proposedSize: NSSize) {
        resolveInitialResizeBehaviorIfNeeded()
        let clampedSize = clampedContentSize(for: proposedSize)
        guard clampedSize != currentContentSize else {
            return
        }

        widthConstraint.constant = clampedSize.width
        heightConstraint.constant = clampedSize.height
        preferredContentSize = clampedSize
        Self.lastUsedContentSize = clampedSize
        Self.persistContentSize(clampedSize)
        onResize(clampedSize)
    }

    private func clampedContentSize(for proposedSize: NSSize) -> NSSize {
        let visibleFrame = view.window?.screen?.visibleFrame
            ?? NSScreen.main?.visibleFrame
            ?? NSRect(x: 0, y: 0, width: 1200, height: 900)

        let maximumWidth = max(Self.minimumContentSize.width, min(visibleFrame.width * 0.75, 1000))
        let generalMaximumHeight = max(Self.minimumContentSize.height, min(visibleFrame.height * 0.7, 720))
        let maximumHeight = min(generalMaximumHeight, maximumContentHeight(for: visibleFrame))
        let minimumHeight = min(Self.minimumContentSize.height, maximumHeight)

        return NSSize(
            width: min(max(proposedSize.width, Self.minimumContentSize.width), maximumWidth),
            height: min(max(proposedSize.height, minimumHeight), maximumHeight)
        )
    }

    func configureResizeBehavior(relativeTo positioningRect: NSRect, of positioningView: NSView) {
        self.positioningRect = positioningRect
        self.positioningView = positioningView
        resolveInitialResizeBehaviorIfNeeded()
    }

    private func resolveInitialResizeBehaviorIfNeeded() {
        guard lockedResizeHandlePlacement == nil else {
            return
        }

        guard let popoverWindow = view.window,
              let positioningView,
              let anchorWindow = positioningView.window else {
            return
        }

        let resolvedPositioningRect = positioningRect.isEmpty ? positioningView.bounds : positioningRect
        let anchorRectInWindow = positioningView.convert(resolvedPositioningRect, to: nil)
        let anchorRectOnScreen = anchorWindow.convertToScreen(anchorRectInWindow)

        let placement: ResizeHandlePlacement
        if popoverWindow.frame.minY >= anchorRectOnScreen.maxY {
            placement = .topTrailing
        } else if popoverWindow.frame.maxY <= anchorRectOnScreen.minY {
            placement = .bottomTrailing
        } else {
            placement = popoverWindow.frame.midY >= anchorRectOnScreen.midY
                ? .topTrailing
                : .bottomTrailing
        }

        lockedResizeHandlePlacement = placement
        updateResizeHandlePlacement(to: placement)
    }

    private func updateResizeHandlePlacement(to placement: ResizeHandlePlacement) {
        resizeHandle.verticalResizeDirection = placement.verticalResizeDirection
        resizeHandle.drawsFromTop = placement == .topTrailing
        resizeHandleTopConstraint.isActive = placement == .topTrailing
        resizeHandleBottomConstraint.isActive = placement == .bottomTrailing
        resizeHandle.window?.invalidateCursorRects(for: resizeHandle)
        resizeHandle.needsDisplay = true
        view.layoutSubtreeIfNeeded()
    }

    private func updateResizeHandleVisibility() {
        let isVisible = isPopoverHovered || resizeHandle.isDragging
        resizeHandle.isHidden = !isVisible
        if isVisible {
            resizeHandle.window?.invalidateCursorRects(for: resizeHandle)
        }
    }

    private func maximumContentHeight(for visibleFrame: NSRect) -> CGFloat {
        guard let lockedResizeHandlePlacement,
              let anchorRectOnScreen = anchorRectOnScreen() else {
            return max(Self.minimumContentSize.height, min(visibleFrame.height * 0.7, 720))
        }

        let currentWindowHeight = view.window?.frame.height ?? currentContentSize.height
        let chromeHeight = max(0, currentWindowHeight - currentContentSize.height)
        let verticalPadding: CGFloat = 8

        let availableWindowHeight: CGFloat
        switch lockedResizeHandlePlacement {
        case .topTrailing:
            availableWindowHeight = visibleFrame.maxY - anchorRectOnScreen.maxY - verticalPadding
        case .bottomTrailing:
            availableWindowHeight = anchorRectOnScreen.minY - visibleFrame.minY - verticalPadding
        }

        return max(Self.minimumContentSize.height, availableWindowHeight - chromeHeight)
    }

    private func anchorRectOnScreen() -> NSRect? {
        guard let positioningView,
              let anchorWindow = positioningView.window else {
            return nil
        }

        let resolvedPositioningRect = positioningRect.isEmpty ? positioningView.bounds : positioningRect
        let anchorRectInWindow = positioningView.convert(resolvedPositioningRect, to: nil)
        return anchorWindow.convertToScreen(anchorRectInWindow)
    }

    // MARK: - JSON Helpers

    private static func looksLikeJSON(_ content: String) -> Bool {
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        return (trimmed.hasPrefix("{") && trimmed.hasSuffix("}")) ||
               (trimmed.hasPrefix("[") && trimmed.hasSuffix("]"))
    }

    static func prettyJSON(_ string: String) -> String {
        guard looksLikeJSON(string),
              let data = string.data(using: .utf8),
              let jsonObject = try? JSONSerialization.jsonObject(with: data),
              let prettyData = try? JSONSerialization.data(withJSONObject: jsonObject, options: [.prettyPrinted, .sortedKeys]),
              let result = String(data: prettyData, encoding: .utf8) else {
            return string
        }
        return result
    }

    static func compactJSON(_ string: String) -> String {
        guard looksLikeJSON(string),
              let data = string.data(using: .utf8),
              let jsonObject = try? JSONSerialization.jsonObject(with: data),
              let compactData = try? JSONSerialization.data(withJSONObject: jsonObject),
              let result = String(data: compactData, encoding: .utf8) else {
            return string
        }
        return result
    }

    private static var restoredContentSize: NSSize? {
        guard let storedWidth = UserDefaults.standard.object(forKey: contentWidthDefaultsKey) as? Double,
              let storedHeight = UserDefaults.standard.object(forKey: contentHeightDefaultsKey) as? Double,
              storedWidth >= Double(minimumContentSize.width),
              storedHeight >= Double(minimumContentSize.height) else {
            return nil
        }

        return NSSize(width: CGFloat(storedWidth), height: CGFloat(storedHeight))
    }

    private static func persistContentSize(_ size: NSSize) {
        UserDefaults.standard.set(Double(size.width), forKey: contentWidthDefaultsKey)
        UserDefaults.standard.set(Double(size.height), forKey: contentHeightDefaultsKey)
    }
}

private enum ResizeHandlePlacement {
    case topTrailing
    case bottomTrailing

    var verticalResizeDirection: CGFloat {
        switch self {
        case .topTrailing:
            return 1
        case .bottomTrailing:
            return -1
        }
    }
}

private final class QuickLookResizeHandleView: NSView {
    var currentSize: (() -> NSSize)?
    var onResizeStart: (() -> Void)?
    var onResize: ((NSSize) -> Void)?
    var onResizeEnd: (() -> Void)?
    var onDragStateChange: ((Bool) -> Void)?
    var verticalResizeDirection: CGFloat = -1
    var drawsFromTop = false

    private var dragStartLocation: NSPoint?
    private var dragStartSize: NSSize = .zero
    private(set) var isDragging = false

    override var isOpaque: Bool {
        false
    }

    override func resetCursorRects() {
        addCursorRect(bounds, cursor: resizeCursor())
    }

    override func mouseDown(with event: NSEvent) {
        dragStartLocation = screenLocation(for: event)
        dragStartSize = currentSize?() ?? .zero
        isDragging = true
        onDragStateChange?(true)
        onResizeStart?()
    }

    override func mouseDragged(with event: NSEvent) {
        guard let dragStartLocation,
              let currentLocation = screenLocation(for: event) else {
            return
        }

        let proposedSize = NSSize(
            width: dragStartSize.width + (currentLocation.x - dragStartLocation.x),
            height: dragStartSize.height + (verticalResizeDirection * (currentLocation.y - dragStartLocation.y))
        )

        onResize?(proposedSize)
    }

    override func mouseUp(with event: NSEvent) {
        dragStartLocation = nil
        isDragging = false
        onDragStateChange?(false)
        onResizeEnd?()
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        let path = NSBezierPath()
        let style = resizeHandleStyle
        path.lineWidth = style.strokeWidth
        path.lineCapStyle = .round

        let radius = max(3, style.cornerRadius - style.curveInset)
        if drawsFromTop {
            path.appendArc(
                withCenter: NSPoint(x: bounds.maxX - style.cornerRadius, y: bounds.maxY - style.cornerRadius),
                radius: radius,
                startAngle: style.startAngle,
                endAngle: style.endAngle,
                clockwise: style.clockwise
            )
        } else {
            path.appendArc(
                withCenter: NSPoint(x: bounds.maxX - style.cornerRadius, y: bounds.minY + style.cornerRadius),
                radius: radius,
                startAngle: -style.startAngle,
                endAngle: -style.endAngle,
                clockwise: !style.clockwise
            )
        }

        NSColor.secondaryLabelColor.withAlphaComponent(style.alpha).setStroke()
        path.stroke()
    }

    private func screenLocation(for event: NSEvent) -> NSPoint? {
        guard let window else {
            return nil
        }

        return window.convertPoint(toScreen: event.locationInWindow)
    }

    private func resizeCursor() -> NSCursor {
        let position: NSCursor.FrameResizePosition = drawsFromTop
            ? .topTrailing(relativeTo: userInterfaceLayoutDirection)
            : .bottomTrailing(relativeTo: userInterfaceLayoutDirection)
        return .frameResize(position: position, directions: .all)
    }

    private var resizeHandleStyle: ResizeHandleStyle {
        if #available(macOS 26, *) {
            return ResizeHandleStyle(
                strokeWidth: 4,
                alpha: 0.88,
                cornerRadius: 14,
                curveInset: 2.5,
                startAngle: 0,
                endAngle: 90,
                clockwise: false
            )
        } else {
            return ResizeHandleStyle(
                strokeWidth: 2.75,
                alpha: 0.76,
                cornerRadius: 10,
                curveInset: 2,
                startAngle: 12,
                endAngle: 72,
                clockwise: false
            )
        }
    }
}

private struct ResizeHandleStyle {
    let strokeWidth: CGFloat
    let alpha: CGFloat
    let cornerRadius: CGFloat
    let curveInset: CGFloat
    let startAngle: CGFloat
    let endAngle: CGFloat
    let clockwise: Bool
}

private final class QuickLookHoverTrackingView: NSView {
    var onHoverChange: ((Bool) -> Void)?

    private var trackingArea: NSTrackingArea?
    private var isHovered = false

    override func updateTrackingAreas() {
        super.updateTrackingAreas()

        if let trackingArea {
            removeTrackingArea(trackingArea)
        }

        let trackingArea = NSTrackingArea(
            rect: .zero,
            options: [.mouseEnteredAndExited, .activeInActiveApp, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(trackingArea)
        self.trackingArea = trackingArea
        refreshHoverState()
    }

    override func mouseEntered(with event: NSEvent) {
        super.mouseEntered(with: event)
        setHovered(true)
    }

    override func mouseExited(with event: NSEvent) {
        super.mouseExited(with: event)
        setHovered(false)
    }

    func refreshHoverState() {
        guard let window else {
            setHovered(false)
            return
        }

        let mouseLocationInView = convert(window.mouseLocationOutsideOfEventStream, from: nil)
        setHovered(bounds.contains(mouseLocationInView))
    }

    private func setHovered(_ hovered: Bool) {
        guard isHovered != hovered else {
            return
        }

        isHovered = hovered
        onHoverChange?(hovered)
    }
}

extension QuickLookViewController: NSTextViewDelegate {
    nonisolated func textDidChange(_ notification: Notification) {
        MainActor.assumeIsolated {
            buttonState.isSaveEnabled = allowsSaveWithoutTextChanges || textView.string != displayedInitialContent
        }
    }
}

// MARK: - Button Bar

@Observable
@MainActor
private class QuickLookButtonState {
    var isSaveEnabled = false
}

private struct QuickLookButtonBar: View {
    let state: QuickLookButtonState
    let onSave: () -> Void
    let onCancel: () -> Void

    var body: some View {
        HStack(spacing: 6) {
            Button(action: onSave) {
                Text("Save ⏎")
            }
            .buttonStyle(AICommandPromptPrimaryButtonStyle())
            .disabled(!state.isSaveEnabled)

            Button(action: onCancel) {
                HStack(spacing: 4) {
                    Text("Cancel")
                    Text("ESC")
                        .opacity(0.6)
                }
            }
            .buttonStyle(AICommandPromptSecondaryButtonStyle())
        }
    }
}
