//
//  Root.swift
//  Collection
//
//  Created by Fauzaan on 1/3/25.
//
import Foundation
import SwiftUI
import SwiftData
import Sparkle
import PostHog
import Sentry

@main
struct Pluk: App {
    @Environment(\.openWindow) private var openWindow
    @State private var window: NSWindow!
    
    private let updaterController: SPUStandardUpdaterController
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Connection.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        
        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()
    
    init() {
        updaterController = SPUStandardUpdaterController(startingUpdater: true, updaterDelegate: nil, userDriverDelegate: nil)
        
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
    }
    
    var body: some Scene {
        WindowGroup("Home", id: "mainWindow") {
            MainWindow()
        }
        .defaultSize(width: 850, height: 750)
        .modelContainer(sharedModelContainer)
        .windowStyle(.hiddenTitleBar)
        .windowToolbarStyle(.unifiedCompact(showsTitle: false))
        
        Window("About Pluk", id: "aboutWindow") {
            AboutView()
                .toolbar(removing: .title)
                .toolbarBackground(.hidden, for: .windowToolbar)
                .containerBackground(.thinMaterial, for: .window)
                .windowMinimizeBehavior(.disabled)
                .fixedSize()
        }
        .windowResizability(.contentSize)
        .restorationBehavior(.disabled)
        .commands {
            CommandGroup(replacing: .appInfo) {
                Button("About Pluk") {
                    openWindow(id: "aboutWindow")
                }
            }
            
            CommandGroup(after: .appInfo) {
                CheckForUpdatesView(updater: updaterController.updater)
            }
        }
    }
}

