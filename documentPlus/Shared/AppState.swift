//
//  AppState.swift
//  DocumentPlus
//
//  Created by Fauzaan on 1/17/25.
//

import MongoKitten
import Foundation
import SwiftUI

@Observable @MainActor final class AppState {
    static let shared = AppState()
    var activeSidebarItem: SidebarItem = .home
    var activeConnection: Connection?
    var activeConnections: [Connection] = []
    var activeSidebarTab: SidebarTab = .connection_details
    var activeSiderbarTabOffset: CGFloat = 0
    var sidebarWidth: CGFloat = 0
    var tabs: [String] = []
    var selectedTab: String? = nil
    
    private init() {}
    
    @discardableResult
    func addConnection(_ connection: Connection) -> Bool {
        guard !activeConnections.contains(where: { existingConnection in
            existingConnection.id == connection.id
        }) else {
            return false
        }
        
        activeConnections.append(connection)
        activeConnection = connection
        
        return true
    }
    
    func changeActiveSidebarItem(_ sidebarItem: SidebarItem) -> Void {
        activeSidebarItem = sidebarItem
        
        if case .database(let databaseName) = sidebarItem {
            activeConnection = activeConnections.first { connection in
                connection.name == databaseName
            }
        }
    }
    
    func changeActiveTab(_ sidebarTab: SidebarTab) {
        withAnimation(.spring(duration: 0.3)) {
            switch sidebarTab {
            case .connections:
                activeSiderbarTabOffset = 0
            case .connection_details:
                activeSiderbarTabOffset = -sidebarWidth
            }
            activeSidebarTab = sidebarTab
        }
    }
    
    func setSidebarWidth(_ width: CGFloat) {
        sidebarWidth = width
        activeSiderbarTabOffset = -width
    }
}
