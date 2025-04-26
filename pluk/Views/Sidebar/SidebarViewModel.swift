//
//  SidebarViewModel.swift
//  Collection
//
//  Created by Fauzaan on 1/31/25.
//

import SwiftUI
@_spi(Experimental) import PostHog

@Observable final class SidebarViewModel {
    private let connectionService: ConnectionService
    
    enum SidebarItem: Hashable {
        case home
        case connection(UUID)
    }
    
    // UI State
    var activeSidebarItem: SidebarItem = .home
    var searchText: String = ""
    
    // Computed Properties
    var connections: [ConnectionInstance] {
        connectionService.connectionInstances
    }
    var activeConnection: ConnectionInstance? {
        connectionService.activeConnectionInstance
    }
    
    init(connectionService: ConnectionService = .shared) {
        self.connectionService = connectionService
    }
    
    // Actions
    func changeActiveSidebarItem(_ item: SidebarItem) {
        activeSidebarItem = item
        if case .connection(let instanceId) = item {
            connectionService.activeConnectionInstanceId = instanceId
        }
    }
    
    func createNewConnectionInstance(for connection: Connection) -> UUID {
        return connectionService.createNewConnectionInstance(for: connection)
    }
    
    func disconnectConnectionInstance(_ instanceId: UUID) async {
        await connectionService.removeConnectionInstance(instanceId)
        
        if let lastActiveConnection = connectionService.connectionInstances.last {
            changeActiveSidebarItem(.connection(lastActiveConnection.id))
        } else {
            changeActiveSidebarItem(.home)
        }
    }
    
    func createCollection(withName: String) async throws {
        guard let activeConnection = activeConnection else {
            return
        }
        
        try await activeConnection.createCollection(withName: withName)
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
