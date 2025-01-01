//
//  ContentView.swift
//  documentPlus
//
//  Created by Fauzaan on 12/31/24.
//

import SwiftUI
import SwiftData
import MongoKitten

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @StateObject private var viewModel = DatabaseViewModel()
    @Query private var items: [Item]
    @State private var itemToDelete: Item?
    @State private var showDeleteConfirmation = false
    @State private var showingConnectionDialog = false
    
    var body: some View {
        HSplitView {
            // Left Sidebar
            VStack(spacing: 0) {
                SidebarView(viewModel: viewModel)
            }
            
            // Main Content Area
            ScrollView {
                VStack {
                    ForEach(Array(viewModel.currentDocuments.enumerated()), id: \.offset) { index, document in
                        DocumentCardView(document: document)
                            .frame(maxWidth: .infinity)
                            .padding(.horizontal)
                    }
                }.padding(.vertical)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .task {
            viewModel.setupDatabase()
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
    }
    
    private func addItem() {
        withAnimation {
            let newItem = Item(timestamp: Date())
            modelContext.insert(newItem)
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
