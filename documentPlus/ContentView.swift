//
//  ContentView.swift
//  documentPlus
//
//  Created by Fauzaan on 12/31/24.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var items: [Item]
    @State private var searchText = ""
    @State private var selectedItem: Item?
    @State private var itemToDelete: Item?
    @State private var showDeleteConfirmation = false
    
    // Add this for the dark theme
    init() {
        NSWindow.allowsAutomaticWindowFrame = true
    }
    
    var body: some View {
        HSplitView {
            // Left Sidebar
            VStack(spacing: 0) {
                List {
                    // Search bar in sidebar
                    HStack {
                        TextField("Search for item...", text: $searchText)
                            .textFieldStyle(.roundedBorder)
                    }
                    
                    ForEach(items) { item in
                        HStack {
                            Image(systemName: "folder.fill")
                            Text(item.timestamp.description)
                        }                    }
                }
                .listStyle(.sidebar)
                .scrollContentBackground(.automatic)
            }
            .frame(minWidth: .zero, maxWidth: 300)
            .background(Color.clear)
            
            // Main Content Area
            ScrollView {
                VStack {
                    ForEach(items) { item in
                        DocumentCardView()
                            .frame(maxWidth: .infinity)
                            .padding(.horizontal)
                    }
                    
                }.padding(.vertical)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .toolbar {
            ToolbarItemGroup(placement: .principal) {
                VStack {
                    Text("Mongo 8.0 : New Connection : test : teams")
                        .font(.subheadline)
                        .padding(.leading, 4)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(minWidth: 450)
                .padding(4)
                .background(Color(NSColor.systemFill))
                .cornerRadius(4)
                
            }
            
            ToolbarItem(placement: .automatic) {
                Button(action: addItem) {
                    Image(systemName: "plus")
                }
            }
        }
        .toolbarBackground(Color(NSColor.windowBackgroundColor))
        .overlay(alignment: .top) {
            Rectangle()
                .frame(height: 1)
                .foregroundColor(.black)
        }
        .preferredColorScheme(.dark) // For dark mode
    }
    
    private func toggleSidebar() {
        NSApp.keyWindow?.firstResponder?.tryToPerform(#selector(NSSplitViewController.toggleSidebar(_:)), with: nil)
    }
    
    private func addItem() {
        withAnimation {
            let newItem = Item(timestamp: Date())
            modelContext.insert(newItem)
        }
    }
    
    private func deleteItems() {
        withAnimation {
            
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
