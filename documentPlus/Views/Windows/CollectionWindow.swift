//
//  CollectionWindow.swift
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

struct CollectionWindow: View {
    let connectionId: PersistentIdentifier
    
    @State private var connection: Connection? = nil
    @State private var tabs: [String] = []
    @State private var selectedTab: String? = nil
    @State private var collections: [MongoCollection] = []
    @State private var databases: [MongoDatabase] = []
    @StateObject private var documentState = DocumentState()
    @State private var isConnecting: Bool = false
    @Query private var connections: [Connection]
    
    var body: some View {
        NavigationView {
//            Sidebar(
//                tabs: $tabs,
//                selectedTab: $selectedTab,
//                collections: $collections,
//                databases: $databases
//                
//            )
            VStack(spacing: 0) {
//                TabBar(tabs: $tabs, selectedTab: $selectedTab)
                
                if let selectedTab {
//                    DocumentView(
//                        instance: instance,
//                        collection: selectedTab
//                    )
//                    .frame(maxWidth: .infinity, maxHeight: .infinity)
//                    .id(selectedTab)
                } else {
                    HStack {
                        Text("No item found")
                            .edgesIgnoringSafeArea(.all)
                            .background(Color(NSColor.red))
                            .border(.background)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .edgesIgnoringSafeArea(.all)
                    .background(Color(NSColor.yellow))
                    .border(.background)
                }
            }.ignoresSafeArea(.all)
        }
//        .task {
//            isConnecting = true
//            self.connection = connections.first { $0.id == connectionId }
//            
//            if let connection {
//                await DatabaseProvider.shared.setupDatabase(
//                    connectionString: connection.url, databaseName: connection.name
//                )
//                self.collections = await DatabaseProvider.shared
//                    .fetchCollections()
//                self.databases = await DatabaseProvider.shared
//                    .fetchDatabases()
//            }
//            
//            isConnecting = false
//            
//        }
    }
}

// You'll need this for the window title bar color
extension NSWindow {
    static var allowsAutomaticWindowFrame: Bool {
        get { true }
        set { }
    }
}
