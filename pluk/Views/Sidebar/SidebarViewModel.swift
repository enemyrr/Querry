//
//  SidebarViewModel.swift
//  Collection
//
//  Created by Fauzaan on 1/31/25.
//

import SwiftUI
import MongoKitten

@Observable final class SidebarViewModel {
    private let connectionService: ConnectionService
    
    enum SidebarItem: Hashable {
        case home
        case connection(UUID)
    }
    
    // UI State
    var activeSidebarItem: SidebarItem = .home
    var searchText: String = ""
    
    // Computed Properties
    var connections: [ConnectionInstance] {
        connectionService.connectionInstances
    }
    var activeConnection: ConnectionInstance? {
        connectionService.activeConnectionInstance
    }

    init(connectionService: ConnectionService = .shared) {
        self.connectionService = connectionService
    }
    
    // Actions
    func changeActiveSidebarItem(_ item: SidebarItem) {
        activeSidebarItem = item
        if case .connection(let instanceId) = item {
            connectionService.activeConnectionInstanceId = instanceId
        }
    }
    
    func createNewConnectionInstance(for connection: Connection) -> UUID {
        return connectionService.createNewConnectionInstance(for: connection)
    }
    
    func disconnectConnectionInstance(_ instanceId: UUID) async {
        await connectionService.removeConnectionInstance(instanceId)
        
        if let lastActiveConnection = connectionService.connectionInstances.last {
            changeActiveSidebarItem(.connection(lastActiveConnection.id))
        } else {
            changeActiveSidebarItem(.home)
        }
    }
    
    func createCollection(withName: String) async throws {
        guard let activeConnection = activeConnection else {
            return
        }
        
        try await activeConnection.createCollection(withName: withName)
    }
    
    func loadActiveConnection() async {
        try? await activeConnection?.connect()
    }
}
