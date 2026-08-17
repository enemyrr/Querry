//
//  AnalyticsService.swift
//  Pluk
//
//  Created by Claude on 1/25/26.
//

import Foundation
import PostHog

@MainActor
final class AnalyticsService {
    static let shared = AnalyticsService()

    private let journeyVersion = "retention_v1"

    private init() {}

    // MARK: - First Event Tracking

    func trackFirstEvent(_ eventName: String, properties: [String: Any] = [:]) {
        let key = "hasTracked_\(eventName)"
        if !UserDefaults.standard.bool(forKey: key) {
            UserDefaults.standard.set(true, forKey: key)
            PostHogSDK.shared.capture(eventName, properties: properties)
        }
    }

    // MARK: - Super Properties Setup

    func setupSuperPropertiesIfNeeded() {
        let defaults = UserDefaults.standard
        let firstSeenDate: String
        if let storedFirstSeenDate = defaults.string(forKey: "analytics_first_seen_date") {
            firstSeenDate = storedFirstSeenDate
        } else {
            firstSeenDate = ISO8601DateFormatter().string(from: Date())
            defaults.set(firstSeenDate, forKey: "analytics_first_seen_date")
        }

        PostHogSDK.shared.register([
            "first_seen_date": firstSeenDate,
            "app_install_version": Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown",
            "auth_state": "anonymous"
        ])
        updateAppearanceSuperProperty()
    }

    func identify(user: WorkOSUser, source: String) {
        PostHogSDK.shared.identify(
            user.id,
            userProperties: ["email_verified": user.emailVerified],
            userPropertiesSetOnce: ["platform": "macos"]
        )
        PostHogSDK.shared.register(["auth_state": "authenticated"])
        PostHogSDK.shared.capture("auth_session_identified", properties: retentionProperties([
            "source": source
        ]))
    }

    func resetIdentity() {
        PostHogSDK.shared.reset()
        setupSuperPropertiesIfNeeded()
    }

    func updateAppearanceSuperProperty() {
        let value = UserDefaults.standard.integer(forKey: "appearance")
        let label = switch value {
        case 1: "light"
        case 2: "dark"
        default: "system"
        }
        PostHogSDK.shared.register(["appearance": label])
    }

    func updateConnectionSuperProperties(totalConnections: Int, databaseTypes: [String]) {
        PostHogSDK.shared.register([
            "total_connections": totalConnections,
            "database_types_used": databaseTypes
        ])
    }

    // MARK: - Connection Events

    func trackConnectionFormOpened(databaseType: DatabaseType?, isEditing: Bool) {
        var properties: [String: Any] = ["is_editing": isEditing]
        if let databaseType {
            properties["database_type"] = databaseType.rawValue
        }
        PostHogSDK.shared.capture("connection_form_opened", properties: retentionProperties(properties))
    }

    func trackConnectionAttemptStarted(databaseType: DatabaseType, source: String, isReconnect: Bool) {
        PostHogSDK.shared.capture("connection_attempt_started", properties: retentionProperties([
            "database_type": databaseType.rawValue,
            "source": source,
            "is_reconnect": isReconnect
        ]))
    }

    func trackConnectionAttemptSucceeded(
        databaseType: DatabaseType,
        source: String,
        isReconnect: Bool,
        durationMs: Int
    ) {
        PostHogSDK.shared.capture("connection_attempt_succeeded", properties: retentionProperties([
            "database_type": databaseType.rawValue,
            "source": source,
            "is_reconnect": isReconnect,
            "duration_ms": durationMs
        ]))
    }

    func trackConnectionAttemptFailed(
        databaseType: DatabaseType,
        source: String,
        isReconnect: Bool,
        durationMs: Int,
        errorCategory: String
    ) {
        PostHogSDK.shared.capture("connection_attempt_failed", properties: retentionProperties([
            "database_type": databaseType.rawValue,
            "source": source,
            "is_reconnect": isReconnect,
            "duration_ms": durationMs,
            "error_category": errorCategory
        ]))
    }

    func trackDatabaseDiscoverySucceeded(databaseType: DatabaseType, source: String, databaseCount: Int) {
        PostHogSDK.shared.capture("database_discovery_succeeded", properties: retentionProperties([
            "database_type": databaseType.rawValue,
            "source": source,
            "database_count": databaseCount
        ]))
    }

    func trackDatabaseDiscoveryFailed(databaseType: DatabaseType, source: String, errorCategory: String) {
        PostHogSDK.shared.capture("database_discovery_failed", properties: retentionProperties([
            "database_type": databaseType.rawValue,
            "source": source,
            "error_category": errorCategory
        ]))
    }

    func trackConnectionOpened(databaseType: DatabaseType, isFirstConnection: Bool) {
        PostHogSDK.shared.capture("connection_opened", properties: [
            "database_type": databaseType.rawValue,
            "is_first_connection": isFirstConnection
        ])
    }

    func trackConnectionCreated(databaseType: DatabaseType, isFirstConnection: Bool) {
        PostHogSDK.shared.capture("connection_created", properties: [
            "database_type": databaseType.rawValue,
            "is_first_connection": isFirstConnection
        ])

        if isFirstConnection {
            trackFirstEvent("first_connection_created", properties: [
                "database_type": databaseType.rawValue
            ])
        }
    }

    func trackConnectionFailed(databaseType: DatabaseType, errorType: String) {
        PostHogSDK.shared.capture("connection_failed", properties: [
            "database_type": databaseType.rawValue,
            "error_type": errorType
        ])
    }

    func trackConnectionDeleted(databaseType: DatabaseType) {
        PostHogSDK.shared.capture("connection_deleted", properties: [
            "database_type": databaseType.rawValue
        ])
    }

    // MARK: - Query Events

    func trackQueryExecuted(
        databaseType: DatabaseType,
        queryType: String,
        executionTimeMs: Int,
        rowCount: Int,
        success: Bool
    ) {
        PostHogSDK.shared.capture("query_executed", properties: [
            "database_type": databaseType.rawValue,
            "query_type": queryType,
            "execution_time_ms": executionTimeMs,
            "row_count": rowCount,
            "success": success
        ])

        if success {
            trackFirstEvent("first_query_executed", properties: [
                "database_type": databaseType.rawValue
            ])
            trackFirstEvent("activation_completed", properties: retentionProperties([
                "activation_type": "sql_editor_query",
                "activation_source": "sql_editor",
                "surface": "sql_editor",
                "database_type": databaseType.rawValue,
                "query_type": queryType
            ]))
        }
    }

    func trackQueryFailed(databaseType: DatabaseType, errorCategory: String) {
        PostHogSDK.shared.capture("query_failed", properties: [
            "database_type": databaseType.rawValue,
            "error_category": errorCategory
        ])
    }

    func trackQueryEditorOpened(databaseType: DatabaseType, source: String) {
        PostHogSDK.shared.capture("query_editor_opened", properties: [
            "database_type": databaseType.rawValue,
            "source": source
        ])
    }

    func trackAccountSettingsViewed(
        source: String,
        isAuthenticated: Bool,
        subscriptionStatus: String,
        isPro: Bool,
        hasLoadedSubscriptionStatus: Bool
    ) {
        PostHogSDK.shared.capture("account_settings_viewed", properties: [
            "source": source,
            "is_authenticated": isAuthenticated,
            "subscription_status": subscriptionStatus,
            "is_pro": isPro,
            "has_loaded_subscription_status": hasLoadedSubscriptionStatus
        ])
    }

    func trackSidebarProPromo(
        action: String,
        databaseType: DatabaseType,
        sidebarViewMode: String
    ) {
        PostHogSDK.shared.capture("sidebar_pro_promo", properties: [
            "action": action,
            "database_type": databaseType.rawValue,
            "sidebar_view_mode": sidebarViewMode
        ])
    }

    // MARK: - Auth Funnel

    func trackAuthLoginStarted(mode: String, source: String) {
        PostHogSDK.shared.capture("auth_login_started", properties: [
            "mode": mode,
            "source": source
        ])
    }

    func trackAuthLoginCompleted(mode: String, source: String) {
        let properties = retentionProperties([
            "mode": mode,
            "source": source
        ])
        PostHogSDK.shared.capture("auth_login_completed", properties: properties)
        PostHogSDK.shared.capture(
            mode == "sign_up" ? "signup_completed" : "login_completed",
            properties: properties
        )
    }

    func trackAuthLoginFailed(reason: String, mode: String, source: String) {
        PostHogSDK.shared.capture("auth_login_failed", properties: retentionProperties([
            "reason": reason,
            "mode": mode,
            "source": source
        ]))
    }

    func trackAuthLogout() {
        PostHogSDK.shared.capture("auth_logged_out", properties: retentionProperties([:]))
    }

    // MARK: - Billing Funnel

    func trackBillingCheckoutStarted(source: String, currentStatus: String) {
        PostHogSDK.shared.capture("billing_checkout_started", properties: [
            "source": source,
            "current_status": currentStatus
        ])
    }

    func trackBillingPortalOpened(kind: String, currentStatus: String) {
        PostHogSDK.shared.capture("billing_portal_opened", properties: [
            "kind": kind,
            "current_status": currentStatus
        ])
    }

    func trackBillingCheckoutFailed(reason: String, currentStatus: String) {
        PostHogSDK.shared.capture("billing_checkout_failed", properties: [
            "reason": reason,
            "current_status": currentStatus
        ])
    }

    func trackSubscriptionActivated(status: String, fromStatus: String, isTrial: Bool) {
        PostHogSDK.shared.capture("subscription_activated", properties: [
            "status": status,
            "from_status": fromStatus,
            "is_trial": isTrial
        ])
    }

    // MARK: - Document/Table Events

    func trackTableViewed(databaseType: DatabaseType) {
        PostHogSDK.shared.capture("table_viewed", properties: [
            "database_type": databaseType.rawValue
        ])
    }

    func trackDocumentCreated(databaseType: DatabaseType) {
        PostHogSDK.shared.capture("document_created", properties: [
            "database_type": databaseType.rawValue
        ])

        trackFirstEvent("first_document_modified", properties: [
            "database_type": databaseType.rawValue,
            "action": "create"
        ])
    }

    func trackDocumentUpdated(databaseType: DatabaseType) {
        PostHogSDK.shared.capture("document_updated", properties: [
            "database_type": databaseType.rawValue
        ])

        trackFirstEvent("first_document_modified", properties: [
            "database_type": databaseType.rawValue,
            "action": "update"
        ])
    }

    func trackDocumentDeleted(databaseType: DatabaseType) {
        PostHogSDK.shared.capture("document_deleted", properties: [
            "database_type": databaseType.rawValue
        ])

        trackFirstEvent("first_document_modified", properties: [
            "database_type": databaseType.rawValue,
            "action": "delete"
        ])
    }

    func trackDatabaseCreated(databaseType: DatabaseType) {
        PostHogSDK.shared.capture("database_created", properties: [
            "database_type": databaseType.rawValue
        ])

        trackFirstEvent("first_database_created", properties: [
            "database_type": databaseType.rawValue
        ])
    }

    // MARK: - Tab Events

    func trackTabCreated(databaseType: DatabaseType?, tabType: String) {
        var properties: [String: Any] = ["tab_type": tabType]
        if let databaseType = databaseType {
            properties["database_type"] = databaseType.rawValue
        }
        PostHogSDK.shared.capture("tab_created", properties: properties)
    }

    // MARK: - AI Events

    func trackAIQueryGeneration(hasSelectedText: Bool, databaseType: DatabaseType, promptLength: Int, success: Bool) {
        PostHogSDK.shared.capture("ai_query_generation", properties: [
            "has_selected_text": hasSelectedText,
            "database_type": databaseType.rawValue,
            "prompt_length": promptLength,
            "success": success
        ])

        trackFirstEvent("first_ai_feature_used", properties: [
            "feature_type": "query_generation"
        ])
    }

    func trackAIErrorFixGeneration(databaseType: DatabaseType, queryLength: Int, errorCategory: String) {
        PostHogSDK.shared.capture("ai_error_fix_generation", properties: [
            "database_type": databaseType.rawValue,
            "query_length": queryLength,
            "error_category": errorCategory
        ])

        trackFirstEvent("first_ai_feature_used", properties: [
            "feature_type": "error_fix"
        ])
    }

    func trackAISearch(databaseType: DatabaseType, queryLength: Int, resultsCount: Int) {
        PostHogSDK.shared.capture("ai_search", properties: [
            "database_type": databaseType.rawValue,
            "query_length": queryLength,
            "results_count": resultsCount
        ])

        trackFirstEvent("first_ai_feature_used", properties: [
            "feature_type": "ai_search"
        ])
    }

    // MARK: - Data Operations

    func trackDataExported(databaseType: DatabaseType, format: String, rowCount: Int) {
        PostHogSDK.shared.capture("data_exported", properties: [
            "database_type": databaseType.rawValue,
            "format": format,
            "row_count": rowCount
        ])
    }

    func trackFilterApplied(databaseType: DatabaseType) {
        PostHogSDK.shared.capture("filter_applied", properties: [
            "database_type": databaseType.rawValue
        ])
    }

    func trackSortApplied(databaseType: DatabaseType) {
        PostHogSDK.shared.capture("sort_applied", properties: [
            "database_type": databaseType.rawValue
        ])
    }

    // MARK: - Notebook Events

    func trackNotebookCreated(source: String) {
        let properties = retentionProperties(["source": source])
        PostHogSDK.shared.capture("notebook_created", properties: properties)

        trackFirstEvent("first_notebook_created", properties: properties)
    }

    func trackNotebookOpened(blockCount: Int, isPublished: Bool) {
        PostHogSDK.shared.capture("notebook_opened", properties: retentionProperties([
            "block_count": blockCount,
            "is_published": isPublished
        ]))
    }

    func trackNotebookBlockCreated(blockType: NotebookBlockType, source: String) {
        PostHogSDK.shared.capture("notebook_block_created", properties: retentionProperties([
            "block_type": blockType.rawValue,
            "source": source
        ]))
    }

    func trackNotebookExecutionStarted(
        surface: String,
        dataSource: String,
        databaseType: DatabaseType?
    ) {
        PostHogSDK.shared.capture(
            "notebook_execution_started",
            properties: notebookExecutionProperties(
                surface: surface,
                dataSource: dataSource,
                databaseType: databaseType
            )
        )
    }

    func trackNotebookExecutionSucceeded(
        surface: String,
        dataSource: String,
        databaseType: DatabaseType?,
        durationMs: Int,
        resultCount: Int
    ) {
        var properties = notebookExecutionProperties(
            surface: surface,
            dataSource: dataSource,
            databaseType: databaseType
        )
        properties["duration_ms"] = durationMs
        properties["result_count"] = resultCount
        PostHogSDK.shared.capture("notebook_execution_succeeded", properties: properties)
        trackFirstEvent("first_notebook_value_received", properties: properties)

        var activationProperties = properties
        activationProperties["activation_type"] = "notebook_\(surface)"
        activationProperties["activation_source"] = "notebook"
        trackFirstEvent("activation_completed", properties: activationProperties)
    }

    func trackNotebookExecutionFailed(
        surface: String,
        dataSource: String,
        databaseType: DatabaseType?,
        durationMs: Int,
        errorCategory: String
    ) {
        var properties = notebookExecutionProperties(
            surface: surface,
            dataSource: dataSource,
            databaseType: databaseType
        )
        properties["duration_ms"] = durationMs
        properties["error_category"] = errorCategory
        PostHogSDK.shared.capture("notebook_execution_failed", properties: properties)
    }

    func trackNotebookPublished(blockCount: Int) {
        PostHogSDK.shared.capture("notebook_published", properties: retentionProperties([
            "block_count": blockCount
        ]))

        trackFirstEvent("first_notebook_published", properties: retentionProperties([:]))
    }

    func trackNotebookUnpublished() {
        PostHogSDK.shared.capture("notebook_unpublished")
    }

    // MARK: - Query Type Detection

    nonisolated static func detectQueryType(from query: String) -> String {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()

        if trimmedQuery.hasPrefix("SELECT") { return "SELECT" }
        if trimmedQuery.hasPrefix("INSERT") { return "INSERT" }
        if trimmedQuery.hasPrefix("UPDATE") { return "UPDATE" }
        if trimmedQuery.hasPrefix("DELETE") { return "DELETE" }
        if trimmedQuery.hasPrefix("CREATE") { return "CREATE" }
        if trimmedQuery.hasPrefix("DROP") { return "DROP" }
        if trimmedQuery.hasPrefix("ALTER") { return "ALTER" }

        return "OTHER"
    }

    nonisolated static func durationMilliseconds(since startTime: ContinuousClock.Instant) -> Int {
        let duration = startTime.duration(to: .now)
        return Int(
            duration.components.seconds * 1000
                + duration.components.attoseconds / 1_000_000_000_000_000
        )
    }

    // MARK: - Error Category Detection

    nonisolated static func categorizeError(_ error: Error) -> String {
        let errorMessage = error.localizedDescription.lowercased()

        if errorMessage.contains("syntax") { return "syntax_error" }
        if errorMessage.contains("ssh") { return "ssh_error" }
        if errorMessage.contains("ssl")
            || errorMessage.contains("tls")
            || errorMessage.contains("certificate")
        {
            return "tls_error"
        }
        if errorMessage.contains("authentication")
            || errorMessage.contains("password")
            || errorMessage.contains("credential")
            || errorMessage.contains("login failed")
        {
            return "authentication_error"
        }
        if errorMessage.contains("permission") || errorMessage.contains("access denied") { return "permission_error" }
        if errorMessage.contains("timeout") { return "timeout_error" }
        if errorMessage.contains("resolve") || errorMessage.contains("dns") { return "host_resolution_error" }
        if errorMessage.contains("refused")
            || errorMessage.contains("unreachable")
            || errorMessage.contains("network")
        {
            return "network_error"
        }
        if errorMessage.contains("connection") { return "connection_error" }
        if errorMessage.contains("not found") || errorMessage.contains("does not exist") { return "not_found_error" }
        if errorMessage.contains("constraint") || errorMessage.contains("violation") { return "constraint_error" }
        if errorMessage.contains("duplicate") { return "duplicate_error" }

        return "unknown_error"
    }

    private func retentionProperties(_ properties: [String: Any]) -> [String: Any] {
        var properties = properties
        properties["journey_version"] = journeyVersion
        return properties
    }

    private func notebookExecutionProperties(
        surface: String,
        dataSource: String,
        databaseType: DatabaseType?
    ) -> [String: Any] {
        var properties: [String: Any] = [
            "surface": surface,
            "data_source": dataSource
        ]
        if let databaseType {
            properties["database_type"] = databaseType.rawValue
        }
        return retentionProperties(properties)
    }
}
