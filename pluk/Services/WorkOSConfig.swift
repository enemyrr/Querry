//
//  WorkOSConfig.swift
//  Pluk
//

import Foundation

enum WorkOSConfig {
    static let clientId: String = {
        #if DEBUG
        return "client_01KP0A64W3N3BX4AJ4N8GDEMNS"
        #else
        return "client_01KP0A65KR9YG2ENR1YNH96W9V"
        #endif
    }()

    static let redirectURI = "https://pluk.sh/welcome"
    static let authorizeURL = "https://api.workos.com/user_management/authorize"
    static let authenticateURL = "https://api.workos.com/user_management/authenticate"

    private static let apiBaseURL: String = {
        #if DEBUG
        return "https://api-stg.pluk.sh"
        #else
        return "https://api.pluk.sh"
        #endif
    }()

    static let billingStatusURL = "\(apiBaseURL)/api/billing/status"
    static let billingPortalURL = "\(apiBaseURL)/api/billing/portal"
    static let billingCheckoutURL = "\(apiBaseURL)/api/billing/checkout"

    static let accessTokenKeychainKey = "workos_access_token"
    static let refreshTokenKeychainKey = "workos_refresh_token"
    static let userDefaultsKey = "workos_current_user"
    static let billingCacheKey = "workos_billing_cache_v1"
}
