//
//  Paywall.swift
//  Pluk
//

import AppKit
import SwiftUI

/// Central entry point for surfacing the paywall from anywhere in the app.
/// The paywall lives in the Account pane of Settings.
@MainActor
enum Paywall {
    enum Reason {
        /// Explicit upgrade tap (e.g. home-screen "Upgrade" badge). Opens
        /// Settings → Account directly with no confirmation.
        case userRequestedUpgrade
        /// A feature gate was hit (e.g. 5th concurrent tab). Shows a native
        /// alert first so the user can dismiss without leaving their flow.
        case openLimitReached
    }

    static func present(reason: Reason = .userRequestedUpgrade, source: String? = nil) {
        switch reason {
        case .userRequestedUpgrade:
            openAccountPane(source: source ?? "upgrade_cta")
        case .openLimitReached:
            showLimitAlert(source: source ?? "connection_limit_alert")
        }
    }

    private static func openAccountPane(source: String) {
        SettingsWindowController.shared.show(pane: .account, source: source)
    }

    private static func showLimitAlert(source: String) {
        let alert = NSAlert()
        alert.messageText = "You've reached the Free plan limit"
        alert.informativeText = "The Free plan allows up to 4 open connections at a time. Upgrade to Pluk Pro for unlimited."
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Upgrade")
        alert.addButton(withTitle: "Cancel")

        if alert.runModal() == .alertFirstButtonReturn {
            openAccountPane(source: source)
        }
    }
}

// MARK: - SwiftUI gate

extension View {
    /// Gates `action` behind a Pro check. If the user is Pro, runs `action`
    /// directly. Otherwise presents the paywall.
    ///
    /// ```
    /// Button("New Connection") { }
    ///     .requiresPro {
    ///         // runs only for Pro users
    ///         createNewConnection()
    ///     }
    /// ```
    func requiresPro(
        authService: WorkOSAuthService = .shared,
        _ action: @escaping () -> Void
    ) -> some View {
        onTapGesture {
            if authService.isPro {
                action()
            } else {
                Paywall.present()
            }
        }
    }
}
