//
//  ConnectionManager.swift
//  Collection
//
//  Created by Fauzaan on 1/21/25.
//

import Foundation
import MongoKitten
import SwiftUI

@Observable
class ConnectionService {
    static let shared = ConnectionService()
    
    // Store all connection instances
    private(set) var connectionInstances: [ConnectionInstance] = []
    
    // Active connection instance
    var activeConnectionInstanceId: UUID? {
        didSet {
            if activeConnectionInstanceId == nil {
                activeConnectionInstanceId = connectionInstances.first?.id
            }
        }
    }
    
    var activeConnectionInstance: ConnectionInstance? {
        guard !connectionInstances.isEmpty, let activeId = activeConnectionInstanceId else {
            return nil
        }
        
        // Find the instance with matching ID
        return connectionInstances.first { $0.id == activeId }
    }
    
    @discardableResult
    func createNewConnectionInstance(for connection: Connection) -> UUID {
        if let existingInstance = connectionInstances.first(where: { instance in
            instance.connection.persistentModelID == connection.persistentModelID
        }) {
            activeConnectionInstanceId = existingInstance.id
            return existingInstance.id
        }
        
        let newInstance = ConnectionInstance(connection: connection)
        connectionInstances.append(newInstance)
        activeConnectionInstanceId = newInstance.id
        return newInstance.id
    }
    
    func removeConnectionInstance(_ instanceId: UUID) async {
        // First perform any cleanup needed on the instance
        if let instanceToDisconnect = getInstance(instanceId) {
            // Properly disconnect
            _ = await disconnectDBInstance(instanceToDisconnect)
            
            // Now remove from the array
            connectionInstances.removeAll(where: { $0.id == instanceToDisconnect.id })
        }
    }
    
    func disconnectDBInstance(_ instance: ConnectionInstance) async -> ConnectionStatus {
        guard instance.connectionStatus == .connected else { return .error }
        guard let db = instance.database, let cluster = db.pool as? MongoCluster else { return .error }
        
        await cluster.disconnect()
        instance.connectionStatus = .disconnected
        
        return instance.connectionStatus
    }
    
    func getInstance(_ instanceId: UUID) -> ConnectionInstance? {
        connectionInstances.first { $0.id == instanceId }
    }
    
    func connect(to instance: ConnectionInstance) async {
        do {
            try await instance.connect()
        } catch {
            print("Connection failed: \(error)")
        }
    }
}
