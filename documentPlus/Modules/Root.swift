//
//  Root.swift
//  DocumentPlus
//
//  Created by Fauzaan on 1/3/25.
//
import SwiftUI
import SwiftData

@main
struct Root: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema()
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        
        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()
    
    var body: some Scene {
        WindowGroup {
//            MainView()
            WelcomeScreen()
        }
        .modelContainer(sharedModelContainer)
        .windowStyle(.hiddenTitleBar)
        .windowToolbarStyle(.unifiedCompact(showsTitle: false))
    }
}
