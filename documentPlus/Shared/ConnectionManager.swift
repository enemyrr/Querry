//
//  ConnectionManager.swift
//  DocumentPlus
//
//  Created by Fauzaan on 1/21/25.
//

import Foundation
import MongoKitten
import SwiftUI

@Observable
final class ConnectionManager {
    static let shared = ConnectionManager()
    
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
        connectionInstances.first { $0.id == activeConnectionInstanceId }
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
    
    func removeConnectionInstance(_ instanceId: UUID) {
        connectionInstances.removeAll(where: { $0.id == instanceId })
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
    
    func disconnect() {
        activeConnectionInstance?.connectionStatus = .disconnected
        activeConnectionInstanceId = nil
    }
}
