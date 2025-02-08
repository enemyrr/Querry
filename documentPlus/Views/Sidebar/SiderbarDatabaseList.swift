//
//  SiderbarDatabaseList.swift
//  DocumentPlus
//
//  Created by Fauzaan on 1/18/25.
//

import SwiftUI
import MongoKitten

struct SiderbarDatabaseList: View {
    @Environment(SidebarViewModel.self) private var sidebarViewModel
    
    var body: some View {
        VStack(spacing: 0) {
            // Content container
            ZStack(alignment: .top) {
                connectionContent
//                    .opacity(isLoading ? 0.3 : 1)
                
//                if isLoading {
//                    ProgressView()
//                        .controlSize(.small)
//                        .padding(.top)
//                }
            }
//            .animation(.easeInOut(duration: 0.2), value: isLoading)
        }
        .task(id: sidebarViewModel.activeSidebarItem.hashValue) {
            await sidebarViewModel.loadActiveConnection()
        }
    }
    
    private var connectionContent: some View {
        VStack(spacing: 0) {
            if let activeInstance = sidebarViewModel.activeInstance {
                if let selectedDb = sidebarViewModel.activeInstance?.database {
                    CollectionsSection(
                        instance: activeInstance,
                        collections: activeInstance.collections[selectedDb.name] ?? []
                    )
                }
                
                if activeInstance.collections.isEmpty {
                    ContentUnavailableView {
                    } description: {
                        Text("Select a database to view collections")
                    }
                    .padding()
                }
            }
            
            if sidebarViewModel.isLoading {
                    ProgressView()
                        .controlSize(.small)
                        .padding()
                }
            
            Spacer()
        }
//        .alert("Connection Error",
//               isPresented: Binding(
//                get: { sidebarViewModel.activeInstance.lastError != nil },
//                set: { _ in sidebarViewModel.activeInstance.lastError = nil }
//               ),
//               presenting: sidebarViewModel.activeInstance.lastError
//        ) { _ in
//            Button("Retry") {
//                Task {
//                    await sidebarViewModel.loadActiveConnection()
//                }
//            }
//            Button("Cancel", role: .cancel) {}
//        } message: { error in
//            Text(error.localizedDescription)
//        }
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

