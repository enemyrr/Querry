//
//  SidebarViewModel.swift
//  Collection
//
//  Created by Fauzaan on 1/31/25.
//

import SwiftUI
@_spi(Experimental) import PostHog

@Observable class SidebarViewModel {
    private let connectionService: ConnectionService
    private let windowConnectionInstance: ConnectionInstance?

    enum SidebarItem: Hashable {
        case home
        case connection(UUID)
    }

    // UI State
    var activeSidebarItem: SidebarItem = .home
    var searchText: String = ""
    var isSearchVisible: Bool = false
    // Computed Properties
    var connections: [ConnectionInstance] {
        connectionService.connectionInstances
    }
    var activeConnection: ConnectionInstance? {
        // If this window has a specific connection, use that; otherwise fall back to shared service
        return windowConnectionInstance ?? connectionService.activeConnectionInstance
    }

    init(connectionService: ConnectionService = .shared, windowConnectionInstance: ConnectionInstance? = nil) {
        self.connectionService = connectionService
        self.windowConnectionInstance = windowConnectionInstance

        // Set initial sidebar item based on window context
        if let windowInstance = windowConnectionInstance {
            self.activeSidebarItem = .connection(windowInstance.id)
        }
    }
    
    // Actions
    func changeActiveSidebarItem(_ item: SidebarItem) {
        activeSidebarItem = item

        switch item {
        case .home:
            // Switch to home tab using WindowController
            WindowController.switchToTab(.home)
        case .connection(let instanceId):
            // Switch to connection tab using WindowController
            WindowController.switchToTab(.connection(instanceId))
        }
    }
    
    func createNewConnectionInstance(for connection: Connection) -> UUID {
        return connectionService.createNewConnectionInstance(for: connection)
    }
    
    func disconnectConnectionInstance(_ instanceId: UUID) async {
        await connectionService.removeConnectionInstance(instanceId)
    }
    
    func createCollection(withName: String) async throws {
        guard let activeConnection = activeConnection else {
            return
        }
        
        try await activeConnection.databaseService.createCollection(named: withName)
    }
    
    func loadActiveConnection() async {
        try? await activeConnection?.connect()
    }
    
    // Feedback Form State
    var isShowingFeedback: Bool = false
    var feedbackText: String = ""
    var feedbackEmail: String = ""
    var isFeedbackSubmitting: Bool = false
    var isFeedbackSubmitted: Bool = false
    
    // Feedback Functions
    func showFeedbackForm() {
        // Reset other form state when opening
        feedbackText = ""
        isFeedbackSubmitted = false
        isFeedbackSubmitting = false
        isShowingFeedback = true
    }

    func submitFeedback() async {
        isFeedbackSubmitting = true
        
        PostHogSDK.shared.capture("survey sent", properties: [
            "$survey_id": "01966cb2-a2e8-0000-fb97-f2e9a889567f",
            "$survey_response_ec511b62-1f0a-4480-a946-04f3cc420dc3": feedbackText,
            "$survey_response_c75e07e1-5dcf-4708-8bd8-549726126767": feedbackEmail
        ])
        
        isFeedbackSubmitting = false
        isFeedbackSubmitted = true
    }
}
