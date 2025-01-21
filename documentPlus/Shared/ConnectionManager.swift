//
//  ConnectionManager.swift
//  DocumentPlus
//
//  Created by Fauzaan on 1/21/25.
//

import Foundation

@Observable
final class ConnectionManager {
    static let shared = ConnectionManager()
    private var instances: [UUID: ConnectionInstanceNew] = [:]
    
    var allInstances: [ConnectionInstanceNew] {
        Array(instances.values)
    }
    
    func getInstance(_ id: UUID) -> ConnectionInstanceNew? {
        instances[id]
    }
    
    func createInstance(for connection: Connection) -> UUID {
        if let existingInstance = instances.values.first(where: {
            $0.connection.persistentModelID == connection.persistentModelID
        }) {
            return existingInstance.id
        }
        
        let instance = ConnectionInstanceNew(connection: connection)
        instances[instance.id] = instance
        return instance.id
    }
    
    func removeInstance(_ id: UUID) {
        instances.removeValue(forKey: id)
    }
    
    func isEmpty() -> Bool {
        instances.isEmpty
    }
}
