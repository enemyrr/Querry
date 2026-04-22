import AppKit

private enum WindowChromeDoubleClickAction {
    case none
    case minimize
    case zoom
}

extension NSWindow {
    @MainActor
    @discardableResult
    func performConfiguredDoubleClickAction() -> Bool {
        let action: WindowChromeDoubleClickAction

        if let configuredAction = UserDefaults.standard.string(forKey: "AppleActionOnDoubleClick") {
            switch configuredAction {
            case "Minimize":
                action = .minimize
            case "Maximize", "Zoom":
                action = .zoom
            default:
                action = .none
            }
        } else if UserDefaults.standard.bool(forKey: "AppleMiniaturizeOnDoubleClick") {
            action = .minimize
        } else {
            return false
        }

        switch action {
        case .minimize:
            guard styleMask.contains(.miniaturizable) else { return false }
            performMiniaturize(nil)
        case .zoom:
            guard styleMask.contains(.resizable) else { return false }
            performZoom(nil)
        case .none:
            return false
        }

        return true
    }
}

class WindowChromeInteractionView: NSView {
    override var mouseDownCanMoveWindow: Bool { false }

    override func mouseDown(with event: NSEvent) {
        guard event.type == .leftMouseDown,
              let window
        else {
            super.mouseDown(with: event)
            return
        }

        if event.clickCount == 2, window.performConfiguredDoubleClickAction() {
            return
        }

        if event.clickCount == 1 {
            window.performDrag(with: event)
            return
        }

        super.mouseDown(with: event)
    }
}
