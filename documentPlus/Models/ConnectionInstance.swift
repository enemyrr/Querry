//
//  ConnectionInstance.swift
//  DocumentPlus
//
//  Created by Fauzaan on 1/20/25.
//

import Foundation

struct ConnectionInstance: Identifiable {
    let id: UUID
    var selectedDatabase: String? = nil
    var isConnected: Bool = false
    var tabs: [String] = []
    var selectedTab: String? = nil
    
    let connection: Connection
    
    init(connection: Connection) {
        self.connection = connection
        self.id = UUID()
    }
    
   static func == (lhs: ConnectionInstance, rhs: ConnectionInstance) -> Bool {
       lhs.id == rhs.id
   }
}
