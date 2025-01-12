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

@MainActor class DocumentState: ObservableObject {
    @Published private(set) var documents: [String: [Document]] = [:]
    @Published private(set) var loadingStates: [String: Bool] = [:]
    
    func setDocuments(_ newDocuments: [Document], for tab: String) {
        documents[tab] = newDocuments
    }
    
    func getDocuments(for tab: String) -> [Document] {
        return documents[tab] ?? []
    }
}

struct ConnectionDetailsWindow: View {
    let connectionId: PersistentIdentifier
    
    @State private var connection: Connection? = nil
    @State private var tabs: [String] = []
    @State private var selectedTab: String? = nil
    @State private var collections: [MongoCollection] = []
    @StateObject private var documentState = DocumentState()
    @State private var isConnecting: Bool = false
    @Query private var connections: [Connection]
    
    var body: some View {
        NavigationView {
            Sidebar(
                tabs: $tabs,
                selectedTab: $selectedTab,
                collections: $collections
            )
            VStack(spacing: 0) {
                TabBar(tabs: $tabs, selectedTab: $selectedTab)
                
                if let selectedTab {
                    DocumentView(
                        documents:
                                .constant(
                                    documentState.getDocuments(for: selectedTab)
                                )
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .id(selectedTab)
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
                isConnecting = true
                self.connection = connections.first { $0.id == connectionId }
                
                if let connection {
                    await DatabaseProvider.shared.setupDatabase(
                        connectionString: connection.url, databaseName: connection.name
                    )
                    self.collections = await DatabaseProvider.shared
                        .fetchCollections()
                }
                
                isConnecting = false
            }
        })
        .onChange(of: selectedTab) {_oldValue, newValue in
            guard let collection = newValue else { return }
            Task {
                let newDocuments = await DatabaseProvider.shared
                    .getDocuments(byCollectionName: collection)
                documentState.setDocuments(newDocuments, for: collection)
            }
        }
        .navigationTitle("")
        .toolbar {
            Toolbar(connection: $connection, isConnecting: $isConnecting)
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
