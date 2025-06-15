//
//  TabManager.swift
//  Pluk
//
//  Created by Claude on 6/14/25.
//

import Foundation
import SwiftUI

@Observable
class TabManager {
    static let shared = TabManager()
    
    // Tab management
    private(set) var tabs: [PlukTab] = []
    var activeTabId: UUID = UUID() // Home tab ID
    
    private init() {
        // Initialize with home tab
        let homeTab = PlukTab(
            id: activeTabId,
            type: .home,
            title: "Home"
        )
        tabs = [homeTab]
    }
    
    var activeTab: PlukTab? {
        tabs.first { $0.id == activeTabId }
    }
    
    // MARK: - Tab Operations
    
    func createConnectionTab(for connectionInstance: ConnectionInstance) -> UUID {
        let tabId = connectionInstance.id
        
        // Check if tab already exists
        if let existingTab = tabs.first(where: { $0.connectionInstanceId == connectionInstance.id }) {
            activeTabId = existingTab.id
            return existingTab.id
        }
        
        // Create new tab
        let newTab = PlukTab(
            id: tabId,
            type: .connection(connectionInstance.id),
            title: connectionInstance.connection.name,
            connectionInstanceId: connectionInstance.id
        )
        
        tabs.append(newTab)
        activeTabId = tabId
        
        return tabId
    }
    
    func switchToTab(_ tabId: UUID) {
        if tabs.contains(where: { $0.id == tabId }) {
            activeTabId = tabId
        }
    }
    
    func switchToHome() {
        if let homeTab = tabs.first(where: { $0.type == .home }) {
            activeTabId = homeTab.id
        }
    }
    
    func closeTab(_ tabId: UUID) {
        // Don't allow closing home tab
        guard tabId != tabs.first(where: { $0.type == .home })?.id else { return }
        
        // Remove tab
        tabs.removeAll { $0.id == tabId }
        
        // If we closed the active tab, switch to home
        if activeTabId == tabId {
            switchToHome()
        }
    }
    
    func updateTabTitle(_ tabId: UUID, title: String) {
        if let index = tabs.firstIndex(where: { $0.id == tabId }) {
            tabs[index].title = title
        }
    }
    
    func getConnectionInstanceId(for tabId: UUID) -> UUID? {
        return tabs.first { $0.id == tabId }?.connectionInstanceId
    }
}

// MARK: - Tab Model

struct PlukTab: Identifiable, Equatable {
    let id: UUID
    let type: TabType
    var title: String
    let connectionInstanceId: UUID?
    
    init(id: UUID, type: TabType, title: String, connectionInstanceId: UUID? = nil) {
        self.id = id
        self.type = type
        self.title = title
        self.connectionInstanceId = connectionInstanceId
    }
}

enum TabType: Equatable {
    case home
    case connection(UUID)
}