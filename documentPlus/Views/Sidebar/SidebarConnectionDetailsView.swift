//
//  SidebarConnectionDetailsView.swift
//  DocumentPlus
//
//  Created by Fauzaan on 1/18/25.
//

import SwiftUI
import MongoKitten

struct SidebarConnectionDetailsView: View {
    @State private var appState = AppState.shared
    @State private var collections: [MongoCollection] = []
    @State private var databases: [MongoDatabase] = []
    @State private var isConnecting: Bool = false
    
    var body: some View {
            VStack(spacing: 0) {
                // Content container
                ZStack(alignment: .top) {
                    // Collections list
                    VStack(spacing: 0) {
                        ForEach(collections, id: \.name) { collection in
                            Button(action: {
                                addTab(for: collection.name)
                            }) {
                                HStack {
                                    Image(systemName: "tablecells").opacity(0.7)
                                    Text(collection.name)
                                    Spacer()
                                }
                            }
                            .buttonStyle(SidebarButtonStyle(isActive: false))
                        }
                        
                        if collections.isEmpty {
                            Text("No collections found")
                                .font(.system(size: 12))
                                .foregroundStyle(.secondary)
                                .padding(.top, 4)
                        }
                    }
                    .opacity(isConnecting ? 0.3 : 1)
                }
                .animation(.easeInOut(duration: 0.2), value: isConnecting)
                .task(id: appState.activeConnection?.id) {
                    guard let connection = appState.activeConnection else { return }
                    
                    withAnimation {
                        isConnecting = true
                    }
                    
                    do {
                        await DatabaseProvider.shared.setupDatabase(
                            connectionString: connection.url,
                            databaseName: connection.name
                        )
                        
                        async let collectionsTask = DatabaseProvider.shared.fetchCollections()
                        async let databasesTask = DatabaseProvider.shared.fetchDatabases()
                        
                        let (newCollections, newDatabases) = await (collectionsTask, databasesTask)
                        
                        withAnimation {
                            collections = newCollections
                            databases = newDatabases
                            isConnecting = false
                        }
                    } catch {
                        // Handle error appropriately
                        withAnimation {
                            isConnecting = false
                        }
                    }
                }
                
                Spacer()
            }
        }
    
    
    private func addTab(for item: String) {
        if !appState.tabs.contains(where: { $0 == item }) {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    appState.tabs.append(item)
                }
            }
            
            appState.selectedTab = item
        }
}

struct SiderbarConnectionDetailsHeader: View {
    @State private var appState = AppState.shared
    
    var body: some View {
        Text(appState.activeConnection?.name ?? "Select a connection")
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(.secondary)
            .padding(.leading, 4)
        Image(systemName: "chevron.down")
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(.secondary)
        
        
        Spacer()
        Button(action: {}) {
            Image(systemName: "magnifyingglass")
        }
        .buttonStyle(ActionButtonStyle())
        .tint(.secondary)
        .foregroundStyle(.secondary)
    }
}

