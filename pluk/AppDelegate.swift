//
//  AppDelegate.swift
//  Pluk
//
//  Created by Fauzaan on 1/3/25.
//
import Cocoa
import SwiftUI
import SwiftData
import Sparkle
import PostHog
import Sentry
import OSLog

@main
class AppDelegate: NSObject, NSApplicationDelegate {
    
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Connection.self,
            QueryHistoryEntry.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            let container = try ModelContainer(for: schema, configurations: [modelConfiguration])
            return container
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()
    
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        let _ = SparkleUpdaterManager.shared
        // Analytics and crash reporting init
        let POSTHOG_API_KEY = "phc_sUeCOX55NMF1KRMylcacBuRrAdZmOtPLLQE0To9eeSK"
        let POSTHOG_HOST = "https://us.i.posthog.com"
        let config = PostHogConfig(apiKey: POSTHOG_API_KEY, host: POSTHOG_HOST)
        PostHogSDK.shared.setup(config)
        
        #if DEBUG
        config.optOut = true
        #endif
        
        SentrySDK.start { options in
            options.dsn = "https://40e927154f63ee358ef2919ad04308a0@o4509530813890560.ingest.us.sentry.io/4509530897252352"
            options.sendDefaultPii = false
            options.enableUncaughtNSExceptionReporting = true
            options.debug = false
        }
        
        // Ensure the app has a basic main menu and is frontmost
        if NSApp.mainMenu == nil {
            let mainMenu = NSMenu()
            let appMenuItem = NSMenuItem()
            mainMenu.addItem(appMenuItem)
            let appMenu = NSMenu()
            appMenu.addItem(withTitle: "Quit Pluk", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
            appMenuItem.submenu = appMenu
            NSApp.mainMenu = mainMenu
        }
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        
        // Create the main window using WindowController (which loads TerminalTabsTitlebarVentura.xib)
        let windowController = WindowController(tabType: .home)
        windowController.showWindow(nil)
        windowController.window?.setContentSize(NSSize(width: 850, height: 950))
        windowController.window?.center()
        windowController.window?.makeKeyAndOrderFront(nil)
        
        // Install Command-[ shortcut in the menu
        installToggleSidebarMenuShortcut()
    }

    // Ensure toolbar items are enabled
    func validateToolbarItem(_ item: NSToolbarItem) -> Bool {
        return true
    }

    // Also validate via NSUserInterfaceValidations to be safe
    func validateUserInterfaceItem(_ item: NSValidatedUserInterfaceItem) -> Bool {
        return true
    }
    
    private func installToggleSidebarMenuShortcut() {
        guard let mainMenu = NSApp.mainMenu else { return }

        // Find and update the existing "Show Sidebar" menu item from XIB
        if let viewItem = mainMenu.items.first(where: { $0.title == "View" }),
           let submenu = viewItem.submenu,
           let sidebarItem = submenu.items.first(where: { $0.title == "Toggle Sidebar" }) {
            // Update to use Cmd+[ shortcut
            sidebarItem.keyEquivalent = "["
            sidebarItem.keyEquivalentModifierMask = [.command]
            sidebarItem.action = #selector(toggleSidebar(_:))
            sidebarItem.target = self
        }
    }

    // Handle the toggleSidebar: action from menu
    @objc func toggleSidebar(_ sender: Any?) {
        if let window = NSApp.keyWindow,
           let windowController = WindowController.getController(for: window) {
            windowController.toggleSidebarNatively(sender)
        }
    }

    // Handle the toggleRightSidebar: action from menu
    @objc func toggleRightSidebar(_ sender: Any?) {
        NotificationCenter.default.post(name: .toggleRightSidebar, object: nil)
    }

    // Validate menu items to keep them enabled
    @objc func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        if menuItem.action == #selector(toggleSidebar(_:)) ||
           menuItem.action == #selector(toggleRightSidebar(_:)) {
            return true
        }
        return true
    }

    // Show custom About window
    @objc func showAboutPanel(_ sender: Any?) {
        let aboutWindowController = AboutWindowController()
        aboutWindowController.window?.center()
        aboutWindowController.showWindow(nil)
    }
    
    @IBAction func checkForUpdates(_ sender: Any?) {
        Task { @MainActor in
            SparkleUpdaterManager.shared.checkForUpdates()
        }
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        // No-op
    }
    
    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        return false
    }
    
    func application(_ application: NSApplication, open urls: [URL]) {
        for url in urls {
            handleOAuthCallback(url)
        }
    }
    
    private func handleOAuthCallback(_ url: URL) {
        if url.path.contains("/callback") {
            if let urlComponents = URLComponents(url: url, resolvingAgainstBaseURL: false),
               let queryItems = urlComponents.queryItems {
                for item in queryItems {
                    if item.name == "code", let code = item.value {
                        NotificationCenter.default.post(
                            name: NSNotification.Name("ConvexOAuthCallback"),
                            object: nil,
                            userInfo: ["code": code]
                        )
                        break
                    }
                }
            }
        }
    }
}

