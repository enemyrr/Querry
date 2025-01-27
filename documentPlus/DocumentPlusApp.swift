//
//  Root.swift
//  DocumentPlus
//
//  Created by Fauzaan on 1/3/25.
//
import Foundation
import SwiftUI
import SwiftData

@main
struct DocumentPlus: App {
    @Environment(\.openWindow) private var openWindow
    @Environment(\.scenePhase) private var scenePhase
    
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
    
    var body: some Scene {
        WindowGroup("Welcome to DocumentPlus", id: "welcomeWindow") {
            MainWindow()
        }
        .defaultSize(width: 850, height: 650)
        .commandsRemoved()
        .modelContainer(sharedModelContainer)
        .windowStyle(.hiddenTitleBar)
        .windowToolbarStyle(.unifiedCompact(showsTitle: false))
    }
}
