//
//  SiderbarDatabaseList.swift
//  Collection
//
//  Created by Fauzaan on 1/18/25.
//

import SwiftUI
import MongoKitten

struct DatabaseList: View {
    var viewModel: SidebarViewModel
    
    var body: some View {
        VStack(spacing: 0) {
            ZStack(alignment: .top) {
                connectionContent
            }
        }
    }
    
    private var connectionContent: some View {
        VStack(spacing: 0) {
            if let activeConnection = viewModel.activeConnection {
                if let selectedDb = activeConnection.database {
                    let filteredCollections = (activeConnection.collections[selectedDb.name] ?? [])
                        .filter {
                            viewModel.searchText.isEmpty ||
                            $0.name.localizedCaseInsensitiveContains(viewModel.searchText)
                        }
                    
                    CollectionsSection(
                            instance: activeConnection,
                            collections: filteredCollections
                        ).padding(.horizontal, 16)
                } else {
                    if activeConnection.connectionStatus != .error {
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
                get: { viewModel.activeConnection?.lastError != nil },
                set: { _ in viewModel.activeConnection?.lastError = nil }
               ),
               presenting: viewModel.activeConnection?.lastError
        ) { _ in
            Button("Retry") {
                Task {
                    await viewModel.loadActiveConnection()
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
//                    Image(systemName: "tablecells")
//                        .opacity(0.7)
                    
                    Image(systemName: "folder")
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

