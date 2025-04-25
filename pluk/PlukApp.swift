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

@main
struct Pluk: App {
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
    }
    
    var body: some Scene {
        WindowGroup("Home", id: "mainWindow") {
            MainWindow()
                .onAppear {
                    NSWindow.allowsAutomaticWindowTabbing = false
                }
        }
        .defaultSize(width: 850, height: 650)
        .modelContainer(sharedModelContainer)
        .windowStyle(.hiddenTitleBar)
        .windowToolbarStyle(.unifiedCompact(showsTitle: false))
        .commands {
            CommandGroup(after: .appInfo) {
                CheckForUpdatesView(updater: updaterController.updater)
            }
        }
    }
}

