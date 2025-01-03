//
//  ContentView.swift
//  documentPlus
//
//  Created by Fauzaan on 12/31/24.
//

import SwiftUI
import SwiftData
import MongoKitten
import Combine

struct ContentView: View {
    @State private var itemToDelete: Item?
    @State private var showDeleteConfirmation = false
    @State private var showingConnectionDialog = false
    @State private var tabs: [ContentItem] = []
    @State private var selectedTab: ContentItem? = nil
    @State private var collections: [MongoCollection] = []
    
    @State private var documents: [ProcessedDocument] = []
    
    var body: some View {
        
        NavigationView {
            SidebarView(tabs: $tabs, selectedTab: $selectedTab, collections: $collections)
            VStack(spacing: 0) {
                Divider()
                TabBar(tabs: $tabs, selectedTab: $selectedTab)
                Divider()
                
                if selectedTab != nil {
                    ContentDetailView(documents: $documents)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if documents.isEmpty {
                    Text("No item found")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                else {
                    Text("Select an item from the list to open a tab.")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
        }
        .onAppear(perform: {
            Task {
                await DatabaseProvider.shared.setupDatabase()
                self.collections = await DatabaseProvider.shared.fetchCollections()
                
            }
        })
        .onChange(of: selectedTab, { oldValue, newValue in
            guard let collection = newValue else { return }
            Task { documents = await DatabaseProvider.shared.getDocumentsAsync(byCollectionName: collection.title) }
        })
    }
}

// You'll need this for the window title bar color
extension NSWindow {
    static var allowsAutomaticWindowFrame: Bool {
        get { true }
        set { }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: Item.self, inMemory: true)
}
