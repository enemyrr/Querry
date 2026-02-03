//
//  TableAppearanceSettings.swift
//  Pluk
//

import AppKit

enum TableAppearanceSettings {
    private(set) static var alternatingRowColors = UserDefaults.standard.bool(forKey: "alternatingRowColors")

    private static let observer: NSObjectProtocol = {
        NotificationCenter.default.addObserver(
            forName: UserDefaults.didChangeNotification,
            object: nil,
            queue: .main
        ) { _ in
            let newValue = UserDefaults.standard.bool(forKey: "alternatingRowColors")
            if newValue != alternatingRowColors {
                alternatingRowColors = newValue
                NotificationCenter.default.post(name: .tableReloadData, object: nil)
            }
        }
    }()

    static func initialize() {
        _ = observer
    }
}

extension NSAppearance {
    var isDarkMode: Bool {
        bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
    }
}

extension NSColor {
    static var cellModificationColor: NSColor {
        let isDarkMode = NSApp.effectiveAppearance.isDarkMode
        if isDarkMode {
            return NSColor(red: 0x7C/255.0, green: 0x59/255.0, blue: 0x2C/255.0, alpha: 1.0)
        } else {
            return NSColor(red: 0xFF/255.0, green: 0xE5/255.0, blue: 0x99/255.0, alpha: 1.0)
        }
    }

    static var alternatingRowStripeColor: NSColor {
        let isDarkMode = NSApp.effectiveAppearance.isDarkMode
        if isDarkMode {
            return NSColor.white.withAlphaComponent(0.02)
        } else {
            return NSColor.black.withAlphaComponent(0.02)
        }
    }
}
