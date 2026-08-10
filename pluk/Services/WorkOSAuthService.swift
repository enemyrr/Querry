//
//  WorkOSAuthService.swift
//  Pluk
//

import Cocoa
import CryptoKit

@Observable
@MainActor
final class WorkOSAuthService {
    static let shared = WorkOSAuthService()

    private(set) var currentUser: WorkOSUser?
    private var codeVerifier = ""
    private var pendingAuthMode = "log_in"
    private var pendingAuthSource = "unknown"

    var isAuthenticated: Bool { currentUser != nil }

    private static let accessTokenRefreshLeadTime: TimeInterval = 60

    private init() {
        restoreSession()
        restoreBillingCache()
        setupCallbackObserver()
        if isAuthenticated {
            Task { await fetchSubscriptionStatus() }
        }
    }

    // MARK: - Login

    func login(signUp: Bool = false, source: String = "unknown") {
        isLoading = true
        authError = nil
        pendingAuthMode = signUp ? "sign_up" : "log_in"
        pendingAuthSource = source
        AnalyticsService.shared.trackAuthLoginStarted(mode: pendingAuthMode, source: source)

        codeVerifier = generateCodeVerifier()
        let codeChallenge = generateCodeChallenge(from: codeVerifier)

        var components = URLComponents(string: WorkOSConfig.authorizeURL)!
        var queryItems: [URLQueryItem] = [
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "client_id", value: WorkOSConfig.clientId),
            URLQueryItem(name: "redirect_uri", value: WorkOSConfig.redirectURI),
            URLQueryItem(name: "code_challenge", value: codeChallenge),
            URLQueryItem(name: "code_challenge_method", value: "S256"),
            URLQueryItem(name: "provider", value: "authkit"),
            URLQueryItem(name: "state", value: UUID().uuidString),
            URLQueryItem(name: "prompt", value: "login"),
            // max_age=0 forces AuthKit to require a fresh authentication even
            // if the browser still holds a WorkOS session cookie. Without this
            // the user gets silently auto-reauthenticated as themselves and
            // can't pick a different account after logging out.
            URLQueryItem(name: "max_age", value: "0"),
        ]
        if signUp {
            queryItems.append(URLQueryItem(name: "screen_hint", value: "sign-up"))
        }
        components.queryItems = queryItems

        guard let authURL = components.url else {
            isLoading = false
            AnalyticsService.shared.trackAuthLoginFailed(
                reason: "invalid_authorization_url",
                mode: pendingAuthMode,
                source: pendingAuthSource
            )
            return
        }

        NSLog("[Auth] opening login URL signUp=\(signUp) url=\(authURL.absoluteString)")
        NSWorkspace.shared.open(authURL)
        // Clear the loading state as soon as the browser is handed the flow.
        // `exchangeCodeForTokens` will re-set it when the `pluk://auth/...`
        // callback fires; if the callback never fires (e.g. the user closes
        // the browser or the web redirect breaks), the app would otherwise
        // sit on the spinner forever.
        isLoading = false
    }

    // MARK: - Logout

    func logout() {
        NSLog("[Auth] logout() — clearing local session")
        AnalyticsService.shared.trackAuthLogout()

        // Grab the access token BEFORE we wipe it so we can pull the session
        // id and tell WorkOS to invalidate the session server-side. Without
        // this, the browser keeps the auth cookie and the next login silently
        // re-authenticates as the same user.
        let accessToken = KeychainHelper.shared.retrieve(for: WorkOSConfig.accessTokenKeychainKey)

        KeychainHelper.shared.delete(for: WorkOSConfig.accessTokenKeychainKey)
        KeychainHelper.shared.delete(for: WorkOSConfig.refreshTokenKeychainKey)
        UserDefaults.standard.removeObject(forKey: WorkOSConfig.userDefaultsKey)
        UserDefaults.standard.removeObject(forKey: WorkOSConfig.billingCacheKey)
        currentUser = nil
        authError = nil
        resetBillingState()
        hasLoadedSubscriptionStatus = false
        AnalyticsService.shared.resetIdentity()

        // Drop the SceneKit/Metal caches so the next user's engraved card
        // renders fresh instead of flashing the previous user's name/serial.
        PremiumCardView.purge()

        if let accessToken, let sessionId = Self.sessionId(fromJWT: accessToken) {
            Task { await Self.revokeWorkOSSession(sessionId: sessionId, accessToken: accessToken) }
        } else {
            NSLog("[Auth] logout: no session_id in JWT, skipping server-side revoke")
        }
    }

    private static func jwtPayload(from token: String) -> [String: Any]? {
        let parts = token.split(separator: ".")
        guard parts.count >= 2 else { return nil }
        var payload = String(parts[1])
            .replacing("-", with: "+")
            .replacing("_", with: "/")
        while payload.count % 4 != 0 { payload.append("=") }
        guard let data = Data(base64Encoded: payload),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }
        return json
    }

    private static func sessionId(fromJWT token: String) -> String? {
        jwtPayload(from: token)?["sid"] as? String
    }

    private static func formEncodedBody(_ params: [(String, String)]) -> String {
        params.map { key, value in
            let k = key.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? key
            let v = value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? value
            return "\(k)=\(v)"
        }
        .joined(separator: "&")
    }

    private static func revokeWorkOSSession(sessionId: String, accessToken: String) async {
        // AuthKit logout is GET /user_management/sessions/logout?session_id=…
        // (per https://workos.com/docs/reference/authkit/logout).
        // Note: this endpoint is designed to be navigated to in the browser
        // — that's what actually clears the auth cookie. Calling it silently
        // via URLSession marks the session as ended on WorkOS's side but
        // does NOT clear cookies in the user's default browser.
        guard var components = URLComponents(string: "https://api.workos.com/user_management/sessions/logout") else { return }
        components.queryItems = [URLQueryItem(name: "session_id", value: sessionId)]
        guard let url = components.url else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            let status = (response as? HTTPURLResponse)?.statusCode ?? -1
            let body = String(data: data, encoding: .utf8) ?? "<non-utf8>"
            NSLog("[Auth] revoke session HTTP \(status) — body=\(body)")
        } catch {
            NSLog("[Auth] revoke session failed: \(error)")
        }
    }

    // MARK: - State

    var authError: String?
    private(set) var isLoading = false
    private(set) var subscriptionStatus: SubscriptionStatus = .none
    private(set) var isCancelling: Bool = false
    private(set) var cancelAt: Date?
    private(set) var currentPeriodEnd: Date?
    private(set) var isTrialing: Bool = false
    private(set) var trialEnd: Date?
    private(set) var subscriptionStartDate: Date?
    /// Founding-member serial stored on the Stripe customer as metadata and
    /// returned by `/billing/status`. Source of truth; client never generates
    /// this.
    private(set) var memberSerial: String?
    /// False until the first `fetchSubscriptionStatus()` completes (success or
    /// failure). The UI uses this to avoid flashing the default `.none` /
    /// non-premium layout before the real status arrives.
    private(set) var hasLoadedSubscriptionStatus = false

    // MARK: - Subscription Status

    enum SubscriptionStatus: String, Codable {
        case none
        case active
        case trialing
        case pastDue = "past_due"
        case canceled
    }

    /// True when the subscription is still active/trialing but a cancellation has been scheduled.
    var isCancelPending: Bool {
        (subscriptionStatus == .active || subscriptionStatus == .trialing) && isCancelling
    }

    /// The date the subscription will actually end.
    var effectiveCancelDate: Date? {
        cancelAt ?? currentPeriodEnd
    }

    var subscriptionButtonLabel: String {
        if isCancelPending { return "Resume Subscription" }
        switch subscriptionStatus {
        case .none: return "Start your free trial"
        case .active, .trialing: return "Manage Subscription"
        case .pastDue: return "Update Payment Method"
        case .canceled: return "Resubscribe"
        }
    }

    /// Apple-style secondary line describing the subscription state.
    /// e.g. "Plan ends Apr 25, 2026" when the user has cancelled but is still in the paid period.
    var subscriptionDetailText: String? {
        if isCancelPending, let endDate = effectiveCancelDate {
            return "Plan ends on \(endDate.formatted(date: .abbreviated, time: .omitted))"
        }

        if isTrialing, let end = trialEnd {
            return "Trial ends on \(end.formatted(date: .abbreviated, time: .omitted))"
        }

        if (subscriptionStatus == .active || subscriptionStatus == .trialing),
           let renewDate = currentPeriodEnd {
            return "Renews on \(renewDate.formatted(date: .abbreviated, time: .omitted))"
        }

        return nil
    }

    func fetchSubscriptionStatus() async {
        guard let url = URL(string: WorkOSConfig.billingStatusURL) else { return }

        var request = URLRequest(url: url)

        defer { hasLoadedSubscriptionStatus = true }

        do {
            let (data, statusCode) = try await performAuthorized(&request)
            let body = String(data: data, encoding: .utf8) ?? "no body"
            NSLog("[WorkOS] Billing status response: HTTP \(statusCode) — \(body)")

            if statusCode == 200,
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let status = json["status"] as? String {
                let parsed = SubscriptionStatus(rawValue: status) ?? .none
                NSLog("[WorkOS] Subscription status: \(status) → \(parsed)")
                let wasPro = isPro
                let previousStatus = subscriptionStatus
                subscriptionStatus = parsed
                if !wasPro && isPro {
                    AnalyticsService.shared.trackSubscriptionActivated(
                        status: parsed.rawValue,
                        fromStatus: previousStatus.rawValue,
                        isTrial: parsed == .trialing
                    )
                }
                isCancelling = (json["isCancelling"] as? Bool) ?? false
                if let ts = json["cancelAt"] as? TimeInterval {
                    cancelAt = Date(timeIntervalSince1970: ts)
                } else {
                    cancelAt = nil
                }
                if let ts = json["currentPeriodEnd"] as? TimeInterval {
                    currentPeriodEnd = Date(timeIntervalSince1970: ts)
                } else {
                    currentPeriodEnd = nil
                }
                isTrialing = (json["isTrialing"] as? Bool) ?? false
                if let ts = json["trialEnd"] as? TimeInterval {
                    trialEnd = Date(timeIntervalSince1970: ts)
                } else {
                    trialEnd = nil
                }
                if let ts = json["startDate"] as? TimeInterval {
                    subscriptionStartDate = Date(timeIntervalSince1970: ts)
                } else {
                    subscriptionStartDate = nil
                }
                memberSerial = json["member_serial"] as? String
                persistBillingCache()
            }
        } catch {
            NSLog("[WorkOS] Subscription status check failed: \(error)")
        }
    }

    // MARK: - Billing Cache

    private struct BillingCache: Codable {
        let status: String
        let isCancelling: Bool
        let cancelAt: Date?
        let currentPeriodEnd: Date?
        let isTrialing: Bool
        let trialEnd: Date?
        let subscriptionStartDate: Date?
        let memberSerial: String?
    }

    private func restoreBillingCache() {
        guard let data = UserDefaults.standard.data(forKey: WorkOSConfig.billingCacheKey),
              let cache = try? Foundation.JSONDecoder().decode(BillingCache.self, from: data) else {
            return
        }
        subscriptionStatus = SubscriptionStatus(rawValue: cache.status) ?? .none
        isCancelling = cache.isCancelling
        cancelAt = cache.cancelAt
        currentPeriodEnd = cache.currentPeriodEnd
        isTrialing = cache.isTrialing
        trialEnd = cache.trialEnd
        subscriptionStartDate = cache.subscriptionStartDate
        memberSerial = cache.memberSerial
        hasLoadedSubscriptionStatus = true
    }

    private func persistBillingCache() {
        let cache = BillingCache(
            status: subscriptionStatus.rawValue,
            isCancelling: isCancelling,
            cancelAt: cancelAt,
            currentPeriodEnd: currentPeriodEnd,
            isTrialing: isTrialing,
            trialEnd: trialEnd,
            subscriptionStartDate: subscriptionStartDate,
            memberSerial: memberSerial
        )
        if let data = try? JSONEncoder().encode(cache) {
            UserDefaults.standard.set(data, forKey: WorkOSConfig.billingCacheKey)
        }
    }

    private func resetBillingState() {
        subscriptionStatus = .none
        isCancelling = false
        cancelAt = nil
        currentPeriodEnd = nil
        isTrialing = false
        trialEnd = nil
        subscriptionStartDate = nil
        memberSerial = nil
    }

    // MARK: - Billing Portal

    private(set) var isBillingLoading = false

    func openBillingPortal() async {
        isBillingLoading = true
        defer { isBillingLoading = false }

        let isCheckout = subscriptionStatus == .none
        let kind = isCheckout ? "checkout" : "portal"
        let statusForAnalytics = subscriptionStatus.rawValue
        let endpoint = isCheckout
            ? WorkOSConfig.billingCheckoutURL
            : WorkOSConfig.billingPortalURL

        NSLog("[Billing] openBillingPortal tapped — status=\(subscriptionStatus) isAuthed=\(isAuthenticated) endpoint=\(endpoint)")

        guard let url = URL(string: endpoint) else {
            NSLog("[Billing] ❌ invalid endpoint URL: \(endpoint)")
            AnalyticsService.shared.trackBillingCheckoutFailed(
                reason: "invalid_endpoint_url",
                currentStatus: statusForAnalytics
            )
            showBillingErrorAlert()
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"

        do {
            let (data, statusCode) = try await performAuthorized(&request)
            let body = String(data: data, encoding: .utf8) ?? "<non-utf8>"
            NSLog("[Billing] response HTTP \(statusCode) — body=\(body)")

            guard statusCode == 200,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let portalURLString = json["url"] as? String,
                  let portalURL = URL(string: portalURLString) else {
                NSLog("[Billing] ❌ unusable response — status=\(statusCode) body=\(body)")
                AnalyticsService.shared.trackBillingCheckoutFailed(
                    reason: "http_\(statusCode)",
                    currentStatus: statusForAnalytics
                )
                showBillingErrorAlert()
                return
            }

            NSLog("[Billing] ✅ opening \(portalURL)")
            NSWorkspace.shared.open(portalURL)
            AnalyticsService.shared.trackBillingPortalOpened(
                kind: kind,
                currentStatus: statusForAnalytics
            )
        } catch {
            NSLog("[Billing] ❌ request failed: \(error)")
            AnalyticsService.shared.trackBillingCheckoutFailed(
                reason: "request_error",
                currentStatus: statusForAnalytics
            )
            showBillingErrorAlert()
        }
    }

    private func showBillingErrorAlert() {
        let alert = NSAlert()
        alert.messageText = "Something went wrong"
        alert.informativeText = "We couldn't open the billing portal. Reach out on X or by email and we'll sort it out."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Contact on X")
        alert.addButton(withTitle: "Email Support")
        alert.addButton(withTitle: "Cancel")

        let target: URL? = switch alert.runModal() {
        case .alertFirstButtonReturn: URL(string: "https://x.com/pluk_sh")
        case .alertSecondButtonReturn: URL(string: "mailto:support@pluk.sh?subject=Billing%20portal%20error")
        default: nil
        }
        if let target { NSWorkspace.shared.open(target) }
    }

    // MARK: - Authorized Requests

    private enum AuthorizedRequestError: Error {
        case missingAccessToken
        case refreshFailed
    }

    private enum TokenRefreshFailureReason: Error {
        case missingRefreshToken
        case transientHTTP(Int)
        case invalidGrant(Int, String)
        case invalidResponse(Int, String)
        case requestError(any Error)
    }

    /// In-flight refresh task so parallel callers don't each kick off their own
    /// refresh round-trip against the auth server.
    private var inFlightRefresh: Task<Bool, Never>?

    /// Refresh the access token if it's missing, expired, or about to expire.
    /// Multiple concurrent callers share the same in-flight Task so we do at
    /// most one refresh HTTP request at a time.
    private func refreshAccessTokenIfNeeded(force: Bool = false) async -> Bool {
        if let task = inFlightRefresh {
            return await task.value
        }

        guard let token = KeychainHelper.shared.retrieve(for: WorkOSConfig.accessTokenKeychainKey) else {
            return false
        }

        if !force,
           let exp = Self.expiry(fromJWT: token),
           exp.timeIntervalSinceNow > Self.accessTokenRefreshLeadTime {
            return true
        }

        if force {
            NSLog("[WorkOS] access token rejected — refreshing")
        } else {
            NSLog("[WorkOS] access token expired/near-expiry — refreshing proactively")
        }
        let task = Task<Bool, Never> { [weak self] in
            let ok = await self?.refreshAccessTokenIfPossible() ?? false
            await MainActor.run { self?.inFlightRefresh = nil }
            return ok
        }
        inFlightRefresh = task
        return await task.value
    }

    /// Performs `request` with the stored access token. Refreshes the token
    /// proactively if it's near expiry, falls back to reactive refresh on 401.
    private func performAuthorized(_ request: inout URLRequest) async throws -> (Data, Int) {
        _ = await refreshAccessTokenIfNeeded()

        guard let token = KeychainHelper.shared.retrieve(for: WorkOSConfig.accessTokenKeychainKey) else {
            throw AuthorizedRequestError.missingAccessToken
        }
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: request)
        let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1

        guard statusCode == 401 else {
            return (data, statusCode)
        }

        NSLog("[WorkOS] Access token rejected (401) — attempting refresh")
        guard await refreshAccessTokenIfNeeded(force: true),
              let refreshed = KeychainHelper.shared.retrieve(for: WorkOSConfig.accessTokenKeychainKey) else {
            throw AuthorizedRequestError.refreshFailed
        }

        request.setValue("Bearer \(refreshed)", forHTTPHeaderField: "Authorization")
        let (retryData, retryResponse) = try await URLSession.shared.data(for: request)
        let retryStatus = (retryResponse as? HTTPURLResponse)?.statusCode ?? -1
        return (retryData, retryStatus)
    }

    private static func expiry(fromJWT token: String) -> Date? {
        guard let payload = jwtPayload(from: token),
              let exp = payload["exp"] as? TimeInterval else { return nil }
        return Date(timeIntervalSince1970: exp)
    }

    /// Exchanges the stored refresh token for a new access/refresh pair.
    @discardableResult
    private func refreshAccessTokenIfPossible() async -> Bool {
        switch await refreshAccessToken() {
        case .success:
            return true
        case .failure(let reason):
            handleRefreshFailure(reason)
            return false
        }
    }

    private func refreshAccessToken() async -> Result<Void, TokenRefreshFailureReason> {
        guard let refreshToken = KeychainHelper.shared.retrieve(for: WorkOSConfig.refreshTokenKeychainKey) else {
            return .failure(.missingRefreshToken)
        }

        let bodyString = Self.formEncodedBody([
            ("grant_type", "refresh_token"),
            ("client_id", WorkOSConfig.clientId),
            ("refresh_token", refreshToken),
        ])

        guard let url = URL(string: WorkOSConfig.authenticateURL) else {
            return .failure(.invalidResponse(-1, "invalid authenticate URL"))
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = bodyString.data(using: .utf8)

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1

            let body = String(data: data, encoding: .utf8) ?? "no body"

            guard statusCode == 200 else {
                if statusCode == 400 || statusCode == 401 {
                    return .failure(.invalidGrant(statusCode, body))
                }
                return .failure(.transientHTTP(statusCode))
            }

            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                return .failure(.invalidResponse(statusCode, "invalid_json"))
            }
            guard let newAccessToken = tokenString(named: "access_token", in: json),
                  let newRefreshToken = tokenString(named: "refresh_token", in: json) else {
                let keys = json.keys.sorted().joined(separator: ",")
                return .failure(.invalidResponse(statusCode, "missing_token_fields keys=\(keys)"))
            }

            guard storeSessionTokens(accessToken: newAccessToken, refreshToken: newRefreshToken) else {
                return .failure(.invalidResponse(statusCode, "keychain_store_failed"))
            }

            NSLog("[WorkOS] Access token refreshed")
            return .success(())
        } catch {
            NSLog("[WorkOS] Refresh request failed: \(error)")
            return .failure(.requestError(error))
        }
    }

    private func handleRefreshFailure(_ reason: TokenRefreshFailureReason) {
        switch reason {
        case .missingRefreshToken:
            NSLog("[WorkOS] No refresh token available — logging out")
            logout()
        case .invalidGrant(let statusCode, let body):
            NSLog("[WorkOS] Refresh rejected: HTTP \(statusCode) — \(body) — logging out")
            logout()
        case .transientHTTP(let statusCode):
            NSLog("[WorkOS] Refresh temporarily failed: HTTP \(statusCode) — keeping local session")
        case .invalidResponse(let statusCode, let body):
            NSLog("[WorkOS] Refresh returned unusable response: HTTP \(statusCode) — \(body) — keeping local session")
        case .requestError(let error):
            NSLog("[WorkOS] Refresh request failed: \(error) — keeping local session")
        }
    }

    // MARK: - Callback Observer

    private func setupCallbackObserver() {
        NotificationCenter.default.addObserver(
            forName: .workOSAuthCallback,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let code = notification.userInfo?["code"] as? String else { return }
            Task { @MainActor [weak self] in
                await self?.exchangeCodeForTokens(code: code)
            }
        }

        NotificationCenter.default.addObserver(
            forName: .billingCallbackReceived,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self, self.isAuthenticated else { return }
                await self.fetchSubscriptionStatus()
            }
        }
    }

    // MARK: - Session Restoration

    func restoreSession() {
        guard let data = UserDefaults.standard.data(forKey: WorkOSConfig.userDefaultsKey),
              let user = try? Foundation.JSONDecoder().decode(WorkOSUser.self, from: data),
              KeychainHelper.shared.passwordExists(for: WorkOSConfig.accessTokenKeychainKey),
              KeychainHelper.shared.passwordExists(for: WorkOSConfig.refreshTokenKeychainKey) else {
            return
        }
        currentUser = user
    }

    // MARK: - Token Exchange

    private func exchangeCodeForTokens(code: String) async {
        isLoading = true
        authError = nil

        defer { isLoading = false }

        let bodyString = Self.formEncodedBody([
            ("grant_type", "authorization_code"),
            ("code", code),
            ("redirect_uri", WorkOSConfig.redirectURI),
            ("client_id", WorkOSConfig.clientId),
            ("code_verifier", codeVerifier),
        ])

        guard let url = URL(string: WorkOSConfig.authenticateURL) else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = bodyString.data(using: .utf8)

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
                let body = String(data: data, encoding: .utf8) ?? "no body"
                NSLog("[WorkOS] Token exchange failed: HTTP \(httpResponse.statusCode) — \(body)")
                authError = "Authentication failed (HTTP \(httpResponse.statusCode))"
                AnalyticsService.shared.trackAuthLoginFailed(
                    reason: "http_\(httpResponse.statusCode)",
                    mode: pendingAuthMode,
                    source: pendingAuthSource
                )
                return
            }

            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]

            guard let accessToken = tokenString(named: "access_token", in: json) else {
                authError = "No access token received"
                AnalyticsService.shared.trackAuthLoginFailed(
                    reason: "missing_access_token",
                    mode: pendingAuthMode,
                    source: pendingAuthSource
                )
                return
            }

            guard let refreshToken = tokenString(named: "refresh_token", in: json) else {
                let keys = json.keys.sorted().joined(separator: ",")
                NSLog("[WorkOS] Token exchange response missing refresh token keys=\(keys)")
                authError = "No refresh token received"
                AnalyticsService.shared.trackAuthLoginFailed(
                    reason: "missing_refresh_token",
                    mode: pendingAuthMode,
                    source: pendingAuthSource
                )
                return
            }

            guard storeSessionTokens(accessToken: accessToken, refreshToken: refreshToken) else {
                authError = "Couldn't save authentication session"
                AnalyticsService.shared.trackAuthLoginFailed(
                    reason: "keychain_store_failed",
                    mode: pendingAuthMode,
                    source: pendingAuthSource
                )
                return
            }

            if let userJSON = json["user"] {
                let userData = try JSONSerialization.data(withJSONObject: userJSON)
                let user = try Foundation.JSONDecoder().decode(WorkOSUser.self, from: userData)
                currentUser = user
                persistUser(user)
                AnalyticsService.shared.identify(user: user, source: "auth_callback")
                AnalyticsService.shared.trackAuthLoginCompleted(
                    mode: pendingAuthMode,
                    source: pendingAuthSource
                )
                await fetchSubscriptionStatus()
            }
        } catch {
            authError = error.localizedDescription
            AnalyticsService.shared.trackAuthLoginFailed(
                reason: "request_error",
                mode: pendingAuthMode,
                source: pendingAuthSource
            )
        }
    }

    private func tokenString(named snakeCaseName: String, in json: [String: Any]) -> String? {
        if let token = json[snakeCaseName] as? String {
            return token
        }
        let parts = snakeCaseName.split(separator: "_")
        guard let first = parts.first else { return nil }
        let camelCaseName = ([String(first)] + parts.dropFirst().map { part in
            part.prefix(1).uppercased() + String(part.dropFirst())
        }).joined()
        return json[camelCaseName] as? String
    }

    private func storeSessionTokens(accessToken: String, refreshToken: String) -> Bool {
        let accessStored = KeychainHelper.shared.store(
            password: accessToken,
            for: WorkOSConfig.accessTokenKeychainKey
        )
        let refreshStored = KeychainHelper.shared.store(
            password: refreshToken,
            for: WorkOSConfig.refreshTokenKeychainKey
        )
        guard accessStored && refreshStored else {
            NSLog("[WorkOS] Failed to store session tokens accessStored=\(accessStored) refreshStored=\(refreshStored)")
            KeychainHelper.shared.delete(for: WorkOSConfig.accessTokenKeychainKey)
            KeychainHelper.shared.delete(for: WorkOSConfig.refreshTokenKeychainKey)
            return false
        }
        return true
    }

    // MARK: - Persistence

    private func persistUser(_ user: WorkOSUser) {
        if let data = try? JSONEncoder().encode(user) {
            UserDefaults.standard.set(data, forKey: WorkOSConfig.userDefaultsKey)
        }
    }

    // MARK: - PKCE Helpers

    private func generateCodeVerifier() -> String {
        let characters = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~"
        return String((0..<128).compactMap { _ in characters.randomElement() })
    }

    private func generateCodeChallenge(from verifier: String) -> String {
        guard let data = verifier.data(using: .utf8) else { return "" }
        let digest = SHA256.hash(data: data)
        return Data(digest).base64URLEncodedString()
    }
}
