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
    @State private var connectionManager: ConnectionManager = ConnectionManager.shared
    @State private var currentInstance: ConnectionInstance?
    
    // Local state for UI
    @State private var isLoading: Bool = false
    @State private var error: Error?
    
    var body: some View {
        VStack(spacing: 0) {
            // Content container
            ZStack(alignment: .top) {
                if let instance = currentInstance {
                    ConnectionContentView(instance: instance)
                        .opacity(isLoading ? 0.3 : 1)
                } else {
                    ContentUnavailableView {
                    } description: {
                        Text("Select a connection to view details")
                    }
                }
                
                if isLoading {
                    ProgressView()
                        .controlSize(.small)
                        .padding(.top)
                }
            }
            .animation(.easeInOut(duration: 0.2), value: isLoading)
        }
        .task(id: appState.activeConnectionInstanceId) {
            await loadActiveConnection()
        }
    }
    
    private func loadActiveConnection() async {
        guard let instanceId = appState.activeConnectionInstanceId,
              let instance = ConnectionManager.shared.getInstance(instanceId) else {
            currentInstance = nil
            return
        }
        
        isLoading = true
        do {
            try await instance.connect()
            currentInstance = instance
        } catch {
            self.error = error
        }
        isLoading = false
    }
}

struct ConnectionContentView: View {
    @State private var appState = AppState.shared
    var instance: ConnectionInstance
    
    
    var body: some View {
        VStack(spacing: 0) {
            // Databases Section
            if !instance.databases.isEmpty {
                DatabasesSection(instance: instance)
            }
            
            // Collections Section
            if let selectedDb = instance.database {
                CollectionsSection(
                    instance: instance,
                    collections: instance.collections[selectedDb.name] ?? []
                )
            }
            
            if instance.isLoading {
                ProgressView()
                    .controlSize(.small)
                    .padding()
            } else if instance.collections.isEmpty {
                ContentUnavailableView {
                } description: {
                    Text("Select a database to view collections")
                }
                .padding()
            }
            
            Spacer()
        }
        .alert("Connection Error",
               isPresented: Binding(
                get: { instance.lastError != nil },
                set: { _ in instance.lastError = nil }
               ),
               presenting: instance.lastError
        ) { _ in
            Button("Retry") {
                Task {
                    //                    await loadActiveConnection()
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

struct SiderbarConnectionDetailsHeader: View {
    @State private var appState = AppState.shared
    @State private var showConnectionMenu = false
    
    var body: some View {
        HStack {
            if let instance = ConnectionManager.shared.getInstance(appState.activeConnectionInstanceId ?? UUID()) {
                Button(action: { showConnectionMenu.toggle() }) {
                    HStack {
                        Text(instance.connection.name)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.secondary)
                        Image(systemName: "chevron.down")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(.secondary)
                    }
                }
                .buttonStyle(.plain)
                .popover(isPresented: $showConnectionMenu) {
                    //                    ConnectionMenuView()
                }
                
                Spacer()
                
                Button(action: {
                    // Implement search
                }) {
                    Image(systemName: "magnifyingglass")
                }
                .buttonStyle(ActionButtonStyle())
                .tint(.secondary)
            }
        }
        .padding(.horizontal, 4)
    }
}
