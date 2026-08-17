//
//  WorkOSConfig.swift
//  Pluk
//

import Foundation

enum WorkOSConfig {
    static let clientId = BuildSecrets.workOSClientID

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

    #if DEBUG
    private static let storageSuffix = "_debug"
    #else
    private static let storageSuffix = ""
    #endif

    static let accessTokenKeychainKey = "workos_access_token\(storageSuffix)"
    static let refreshTokenKeychainKey = "workos_refresh_token\(storageSuffix)"
    static let userDefaultsKey = "workos_current_user\(storageSuffix)"
    static let billingCacheKey = "workos_billing_cache_v1\(storageSuffix)"
}
