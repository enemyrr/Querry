//
//  ConnectionManager.swift
//  Collection
//
//  Created by Fauzaan on 1/21/25.
//

import Foundation
import MongoKitten
import SwiftUI
import AppKit

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
        // Always create a new instance for each call to get a new tab
        let newInstance = ConnectionInstance(connection: connection)
        connectionInstances.append(newInstance)
        activeConnectionInstanceId = newInstance.id
        
        // Create new tab for the new connection instance
        _ = TabManager.shared.createConnectionTab(for: newInstance)
        
        return newInstance.id
    }
    
    func removeConnectionInstance(_ instanceId: UUID) async {
        // First perform any cleanup needed on the instance
        if let instanceToDisconnect = getInstance(instanceId) {
            await disconnectDBInstance(instanceToDisconnect)
            
            // Close the tab
            TabManager.shared.closeTab(instanceId)
            
            // Now remove from the array
            connectionInstances.removeAll(where: { $0.id == instanceToDisconnect.id })
        }
    }
    
    @discardableResult
    func disconnectDBInstance(_ instance: ConnectionInstance) async -> ConnectionStatus {
        guard instance.connectionStatus == .connected else { return .error }
        
        // Use the new driver architecture for disconnection
        if let driver = instance.databaseDriver {
            await driver.disconnect()
            instance.connectionStatus = .disconnected
            return instance.connectionStatus
        }
        
        // Fallback to MongoDB-specific disconnection for backward compatibility
        if let db = instance.database, let cluster = db.pool as? MongoCluster {
            await cluster.disconnect()
            instance.connectionStatus = .disconnected
            return instance.connectionStatus
        }
        
        return .error
    }
    
    func getInstance(_ instanceId: UUID) -> ConnectionInstance? {
        connectionInstances.first { $0.id == instanceId }
    }
    
    func getExistingInstance(for connection: Connection) -> ConnectionInstance? {
        connectionInstances.first { $0.connection.persistentModelID == connection.persistentModelID }
    }
    
    func connect(to instance: ConnectionInstance) async {
        do {
            try await instance.connect()
        } catch {
            debugLog("Connection failed: \(error)")
        }
    }
    
    func reconnect(to instance: ConnectionInstance) async {
        do {
            try await instance.reconnect()
        } catch {
            debugLog("Reconnection failed: \(error)")
        }
    }
    
    // MARK: - Tab Management
    
    func updateTabTitle(for instanceId: UUID, title: String) {
        TabManager.shared.updateTabTitle(instanceId, title: title)
    }
    
    func closeTab(for instanceId: UUID) async {
        await removeConnectionInstance(instanceId)
    }
}
