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
    var activeConnection: Connection?
    var activeConnections: [Connection] = []
    
    // Runtime instances of connections
    var connectionInstances: [ConnectionInstance] = []
    
    // UI State only
   var activeSidebarItem: SidebarItem = .home
   var activeSidebarTab: SidebarTab = .connection_details
   var sidebarWidth: CGFloat = 0
   var activeSiderbarTabOffset: CGFloat = 0
   
   // Active instance tracking
   var activeConnectionInstanceId: UUID?
    
    var activeConnectionInstance: ConnectionInstance? {
       connectionInstances.first { $0.id == activeConnectionInstanceId }
   }
    
    @discardableResult
    func createNewConnectionInstance(for connection: Connection) -> UUID? {
        if let existingInstance = connectionInstances.first(where: { instance in
            instance.connection.persistentModelID == connection.persistentModelID
        }) {
            activeConnectionInstanceId = existingInstance.id
            return activeConnectionInstanceId
        }
        
        let newInstance = ConnectionInstance(connection: connection)
        connectionInstances.append(newInstance)
        activeConnectionInstanceId = newInstance.id
        
        // TODO:
        // Support override to open as new tab
        return newInstance.id
    }
    
    func removeConnectionInstance(_ instanceId: UUID) {
        connectionInstances.removeAll(where: { $0.id == instanceId })
        if activeConnectionInstanceId == instanceId {
            activeConnectionInstanceId = connectionInstances.first?.id
        }
    }
    
    func changeActiveSidebarItem(_ sidebarItem: SidebarItem) -> Void {
        activeSidebarItem = sidebarItem
        
        if case .connection(let connectionInstanceId) = sidebarItem {
            activeConnectionInstanceId = connectionInstanceId
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
    
    /// MARK: TABS
//    private func addTab(for item: String) {
//        if !appState.tabs.contains(where: { $0 == item }) {
//            withAnimation(.spring(response: 0.3)) {
//                appState.tabs.append(item)
//            }
//        }
//        
//        appState.selectedTab = item
//    }
    
    func addTab(instanceId: UUID, tabName: String) {
         guard let index = connectionInstances.firstIndex(where: { $0.id == instanceId }) else { return }
         
        if !connectionInstances[index].tabs.contains(tabName) {
            connectionInstances[index].tabs.append(tabName)
        }
        
        connectionInstances[index].selectedTab = tabName
     }
     
    func removeTab(instanceId: UUID, tabName: String) {
        if let index = connectionInstances.firstIndex(where: { $0.id == instanceId }) {
            connectionInstances[index].tabs.removeAll(where: { $0 == tabName })
            
            if connectionInstances[index].selectedTab == tabName {
                connectionInstances[index].selectedTab = connectionInstances[index].tabs.last
            }
        }
    }
    
    func selectTab(instanceId: UUID, tabName: String) {
        if let index = connectionInstances.firstIndex(where: { $0.id == instanceId }) {
            connectionInstances[index].selectedTab = tabName
        }
    }
}
