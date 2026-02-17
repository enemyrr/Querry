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
        SidebarItemRegistry.shared.addConnection(newInstance.id)

        return newInstance.id
    }
    
    func removeConnectionInstance(_ instanceId: UUID) async {
        // First perform any cleanup needed on the instance
        if let instanceToDisconnect = getInstance(instanceId) {
            await disconnectDBInstance(instanceToDisconnect)
            await closeNativeTab(for: instanceId)
            
            // Now remove from the array
            connectionInstances.removeAll(where: { $0.id == instanceToDisconnect.id })
            SidebarItemRegistry.shared.removeConnection(instanceId)
        }
    }

    @MainActor
    private func closeNativeTab(for instanceId: UUID) {
        // Find the native tab window for this connection instance
        let windows = NSApp.windows.filter { $0.isVisible }

        for window in windows {
            if let windowController = WindowController.getController(for: window),
               case .connection(let windowInstanceId) = windowController.tabType,
               windowInstanceId == instanceId {
                // Close the native tab window
                window.close()
                break
            }
        }
    }
    
    @discardableResult
    func disconnectDBInstance(_ instance: ConnectionInstance) async -> ConnectionStatus {
        guard instance.connectionStatus == .connected else { return .error }

        await instance.databaseService.disconnect()
        instance.connectionStatus = .disconnected
        return instance.connectionStatus
    }
    
    func getInstance(_ instanceId: UUID) -> ConnectionInstance? {
        connectionInstances.first { $0.id == instanceId }
    }
    
    func getExistingInstance(for connection: Connection) -> ConnectionInstance? {
        connectionInstances.first { $0.connection.persistentModelID == connection.persistentModelID }
    }
    
    func connect(to instance: ConnectionInstance, targetDatabase: String? = nil) async {
        do {
            try await instance.connect(targetDatabaseName: targetDatabase)
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
    
    // MARK: - Environment / Deployment Tabs (Convex)
    /// Opens a new connection tab for the same connection targeting a specific database/environment.
    /// For Convex, this maps to deployments (e.g., Production, Preview: <id>, Development).
    /// - Returns: The existing or newly created connection instance ID.
    func openEnvironmentInNewTab(from instance: ConnectionInstance, databaseName: String) async -> UUID? {
        // Check if a tab already exists for this connection and environment
        for existingInstance in connectionInstances {
            if existingInstance.connection.persistentModelID == instance.connection.persistentModelID &&
               existingInstance.connectedDatabase?.name == databaseName {
                // Tab already exists, return its ID
                return existingInstance.id
            }
        }

        // No existing tab found, create a new connection instance
        let newId = createNewConnectionInstance(for: instance.connection)
        guard let newInstance = getInstance(newId) else { return nil }

        // Set the target database in the database service
        // Find the target database from the source instance
        if let targetDb = instance.databases.first(where: { $0.name == databaseName }) {
            newInstance.databaseService.connectedDatabase = targetDb
        }

        // Set tab title immediately to show the environment being loaded
        await updateTabTitle(for: newId, title: "\(newInstance.connection.name) – \(databaseName)")

        return newId
    }
    
    // MARK: - Tab Management
    
    @MainActor
    func updateTabTitle(for instanceId: UUID, title: String) {
        for window in NSApp.windows where window.isVisible {
            guard let windowController = WindowController.getController(for: window),
                  case .connection(let windowInstanceId) = windowController.tabType,
                  windowInstanceId == instanceId else { continue }
            window.title = title
            break
        }
    }
    
    func closeTab(for instanceId: UUID) async {
        await removeConnectionInstance(instanceId)
    }
}
