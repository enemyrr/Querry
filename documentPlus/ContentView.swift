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
    @Environment(\.modelContext) private var modelContext
    @StateObject private var viewModel = DatabaseViewModel()
    @Query private var items: [Item]
    @State private var itemToDelete: Item?
    @State private var showDeleteConfirmation = false
    @State private var showingConnectionDialog = false
    @State private var tabs: [ContentItem] = []
    @State private var selectedTab: ContentItem? = nil
    
    @State private var documents: [ProcessedDocument] = []
    
    var body: some View {
        
        NavigationView {
            SidebarView(tabs: $tabs, selectedTab: $selectedTab)
            VStack(spacing: 0) {
                Divider()
                TabBar(tabs: $tabs, selectedTab: $selectedTab, removeTab: removeTab)
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
        .task {
            viewModel.setupDatabase()
        }
        .onChange(of: selectedTab, { oldValue, newValue in
            guard let collection = newValue else { return }
            Task { documents = await collection.databaseViewModel.getDocumentsAsync(byCollectionName: collection.title) }
        })
        .environmentObject(viewModel)
    }
    
    
    private func addItem() {
        withAnimation {
            let newItem = Item(timestamp: Date())
            modelContext.insert(newItem)
        }
    }
    
    
    private func removeTab(_ item: ContentItem) {
        if let index = tabs.firstIndex(where: { $0.id == item.id }) {
            tabs.remove(at: index)
            if selectedTab == item {
                selectedTab = tabs.last // Switch to the last tab, or nil if no tabs are left
            }
        }
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
