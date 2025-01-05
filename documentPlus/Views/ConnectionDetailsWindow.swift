//
//  ConnectionDetailsWindow.swift
//  documentPlus
//
//  Created by Fauzaan on 12/31/24.
//
import SwiftUI
import SwiftData
import MongoKitten
import Combine

struct ConnectionDetailsWindow: View {
    @State private var tabs: [String] = []
    @State private var selectedTab: String? = nil
    @State private var collections: [MongoCollection] = []
    @State private var documents: [ProcessedDocument] = []
    
    var body: some View {
        NavigationView {
            Sidebar(
                tabs: $tabs,
                selectedTab: $selectedTab,
                collections: $collections
            )
            VStack(spacing: 0) {
                TabBar(tabs: $tabs, selectedTab: $selectedTab)
                
                if selectedTab != nil {
                    DocumentView(documents: $documents)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    Text("No item found")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .edgesIgnoringSafeArea(.all)
                        .background(Color(NSColor.controlBackgroundColor))
                }
            }
        }
        .onAppear(perform: {
            Task {
                await DatabaseProvider.shared.setupDatabase()
                self.collections = await DatabaseProvider.shared
                    .fetchCollections()
                
            }
        })
        .onChange(of: selectedTab) {_oldValue, newValue in
            guard let collection = newValue else { return }
            Task {
                documents = await DatabaseProvider.shared
                    .getDocumentsAsync(byCollectionName: collection)
            }
        }
        .toolbar {
            ToolbarItem(placement: .navigation) {
                Menu {
                    Button("New...") {
                        // action
                    }
                    
                    Button("Edit...") {
                        // action
                    }
                    Divider()
                    Button("Reload Current Tab") {
                        // action
                    }
                    Button("Reconnect") {
                        // action
                    }
                    Divider()
                    Button("Disonnect") {
                        // action
                    }
                } label: {
                    Text("Innovation Servers")
                }.menuStyle(.borderlessButton)
            }
            
            ToolbarItem(placement: .principal) {
                HStack(alignment: .center) {
                    Text("Mongo 8.0 : New Connection : test : teams")
                        .font(.subheadline)
                        .padding(.leading, 4)
                    
                    Spacer()
                    
                    HStack(spacing: 4) {
                        Text("Connecting")
                            .font(.subheadline)
                        
                        ProgressView()
                            .scaleEffect(0.5)
                            .controlSize(.small)
                    }
                    
                }
                .frame(minWidth: 450)
                .padding(4)
                .background(Color(NSColor.systemFill))
                .cornerRadius(4)
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
