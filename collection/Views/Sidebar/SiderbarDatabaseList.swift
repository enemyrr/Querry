//
//  SiderbarDatabaseList.swift
//  Collection
//
//  Created by Fauzaan on 1/18/25.
//

import SwiftUI
import MongoKitten

struct SiderbarDatabaseList: View {
    @Environment(SidebarViewModel.self) private var sidebarViewModel
    
    var body: some View {
        VStack(spacing: 0) {
            ZStack(alignment: .top) {
                connectionContent
            }
        }
    }
    
    private var connectionContent: some View {
        VStack(spacing: 0) {
            if let activeInstance = sidebarViewModel.activeInstance {
                if let selectedDb = activeInstance.database {
                    let filteredCollections = (activeInstance.collections[selectedDb.name] ?? [])
                        .filter {
                            sidebarViewModel.searchText.isEmpty ||
                            $0.name.localizedCaseInsensitiveContains(sidebarViewModel.searchText)
                        }
                    
                    CollectionsSection(
                            instance: activeInstance,
                            collections: filteredCollections
                        ).padding(.horizontal, 16)
                } else {
                    if activeInstance.connectionStatus != .error {
                        ProgressView()
                            .controlSize(.small)
                            .padding()
                    }
                }
            }
            
            Spacer()
        }
        .alert("Connection Error",
               isPresented: Binding(
                get: { sidebarViewModel.activeInstance?.lastError != nil },
                set: { _ in sidebarViewModel.activeInstance?.lastError = nil }
               ),
               presenting: sidebarViewModel.activeInstance?.lastError
        ) { _ in
            Button("Retry") {
                Task {
                    await sidebarViewModel.loadActiveConnection()
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: { error in
            Text(error.localizedDescription)
        }
    }
}

struct DatabasesSection: View {
    var instance: ConnectionInstance
    
    var body: some View {
        DisclosureGroup("Databases") {
            ForEach(instance.databases, id: \.name) { database in
                Button(action: {
                    instance.database = database
                }) {
                    HStack {
                        Image(systemName: "folder.fill")
                            .foregroundStyle(.secondary)
                        Text(database.name)
                        Spacer()
                    }
                }
                .buttonStyle(SidebarButtonStyle(
                    isActive: instance.database?.name == database.name
                ))
            }
        }
    }
}

struct CollectionsSection: View {
    var instance: ConnectionInstance
    let collections: [MongoCollection]
    
    var body: some View {
        ForEach(collections, id: \.name) { collection in
            Button(action: {
                instance.createNewTab(
                    name: collection.name
                )
            }) {
                HStack {
                    Image(systemName: "tablecells")
                        .opacity(0.7)
                    Text(collection.name)
                    Spacer()
                }
            }
            .buttonStyle(SidebarButtonStyle(
                isActive: instance.selectedTab?.name == collection.name
            ))
        }
    }
}

