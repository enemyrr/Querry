import SwiftUI
@_spi(Experimental) import PostHog

@MainActor
@Observable class SidebarViewModel {
    private let connectionService: ConnectionService
    private let windowConnectionInstance: ConnectionInstance?

    enum SidebarNavItem: Hashable {
        case home
        case connection(UUID)
    }

    var activeSidebarItem: SidebarNavItem = .home
    var searchText: String = ""
    var isSearchVisible: Bool = false

    var activeConnection: ConnectionInstance? {
        windowConnectionInstance ?? connectionService.activeConnectionInstance
    }

    init(connectionService: ConnectionService = .shared, windowConnectionInstance: ConnectionInstance? = nil) {
        self.connectionService = connectionService
        self.windowConnectionInstance = windowConnectionInstance

        if let windowInstance = windowConnectionInstance {
            self.activeSidebarItem = .connection(windowInstance.id)
        }
    }

    func changeActiveSidebarItem(_ item: SidebarNavItem) {
        activeSidebarItem = item

        switch item {
        case .home:
            WindowController.switchToTab(.home)
        case .connection(let instanceId):
            WindowController.switchToTab(.connection(instanceId))
        }
    }

    func createNewConnectionInstance(for connection: Connection) -> UUID {
        connectionService.createNewConnectionInstance(for: connection)
    }

    func disconnectConnectionInstance(_ instanceId: UUID) async {
        await connectionService.removeConnectionInstance(instanceId)
    }

    func connectionInstance(for id: UUID) -> ConnectionInstance? {
        connectionService.getInstance(id)
    }

    func createCollection(withName: String) async throws {
        guard let activeConnection else { return }
        try await activeConnection.databaseService.createCollection(named: withName)
    }

    func loadActiveConnection() async {
        try? await activeConnection?.connect()
    }

    // MARK: - Feedback

    var isShowingFeedback: Bool = false
    var feedbackText: String = ""
    var feedbackEmail: String = ""
    var isFeedbackSubmitting: Bool = false
    var isFeedbackSubmitted: Bool = false

    func showFeedbackForm() {
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
