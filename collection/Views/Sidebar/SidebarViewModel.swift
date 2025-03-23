//
//  SidebarViewModel.swift
//  Collection
//
//  Created by Fauzaan on 1/31/25.
//

import SwiftUI
import MongoKitten

@Observable
final class SidebarViewModel {
    private let connectionManager: ConnectionManager
    
    // UI State
    var activeSidebarItem: SidebarItem = .home
    var searchText: String = ""
    
    // Computed Properties
    var allInstances: [ConnectionInstance] {
        connectionManager.connectionInstances
    }
    
    var activeInstance: ConnectionInstance? {
        connectionManager.activeConnectionInstance
    }
    
    init(connectionManager: ConnectionManager) {
        self.connectionManager = connectionManager
    }
    
    // Actions
    func changeActiveSidebarItem(_ item: SidebarItem) {
        activeSidebarItem = item
        if case .connection(let instanceId) = item {
            connectionManager.activeConnectionInstanceId = instanceId
        }
    }
    
    func createNewConnectionInstance(for connection: Connection) -> UUID {
        return connectionManager.createNewConnectionInstance(for: connection)
    }
    
    func disconnectConnectionInstance(_ instanceId: UUID) async {
        await connectionManager.removeConnectionInstance(instanceId)
        
        if connectionManager.activeConnectionInstanceId == instanceId {
            if let firstActiveInstance = connectionManager.connectionInstances.last {
                changeActiveSidebarItem(.connection(firstActiveInstance.id))
            } else {
                changeActiveSidebarItem(.home)
            }
        }
    }
    
    func loadActiveConnection() async {
        try? await activeInstance?.connect()
    }
}

enum SidebarItem: Hashable {
    case home
    case connection(UUID)
}

enum SidebarTab: Equatable {
    case connections
    case connection_details
}
