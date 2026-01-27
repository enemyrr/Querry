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
        if !UserDefaults.standard.bool(forKey: "posthog_super_properties_set") {
            UserDefaults.standard.set(true, forKey: "posthog_super_properties_set")
            PostHogSDK.shared.register([
                "first_seen_date": ISO8601DateFormatter().string(from: Date()),
                "app_install_version": Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown"
            ])
        }
    }

    func updateConnectionSuperProperties(totalConnections: Int, databaseTypes: [String]) {
        PostHogSDK.shared.register([
            "total_connections": totalConnections,
            "database_types_used": databaseTypes
        ])
    }

    // MARK: - Connection Events

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
        }
    }

    func trackQueryFailed(databaseType: DatabaseType, errorCategory: String) {
        PostHogSDK.shared.capture("query_failed", properties: [
            "database_type": databaseType.rawValue,
            "error_category": errorCategory
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

    // MARK: - Error Category Detection

    nonisolated static func categorizeError(_ error: Error) -> String {
        let errorMessage = error.localizedDescription.lowercased()

        if errorMessage.contains("syntax") { return "syntax_error" }
        if errorMessage.contains("permission") || errorMessage.contains("access denied") { return "permission_error" }
        if errorMessage.contains("timeout") { return "timeout_error" }
        if errorMessage.contains("connection") { return "connection_error" }
        if errorMessage.contains("not found") || errorMessage.contains("does not exist") { return "not_found_error" }
        if errorMessage.contains("constraint") || errorMessage.contains("violation") { return "constraint_error" }
        if errorMessage.contains("duplicate") { return "duplicate_error" }

        return "unknown_error"
    }
}
