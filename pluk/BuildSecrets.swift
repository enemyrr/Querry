import Foundation

enum BuildSecrets {
    static let postHogAPIKey = value(for: "PLUKPostHogAPIKey")
    static let sentryDSN = value(for: "PLUKSentryDSN")
    static let workOSClientID = value(for: "PLUKWorkOSClientID")
    static let convexOAuthClientID = value(for: "PLUKConvexOAuthClientID")
    static let convexOAuthClientSecret = value(for: "PLUKConvexOAuthClientSecret")
    static let bedrockIdentityPoolID = value(for: "PLUKBedrockIdentityPoolID")
    static let bedrockRoleARN = value(for: "PLUKBedrockRoleARN")

    private static func value(for key: String) -> String? {
        guard let rawValue = Bundle.main.object(forInfoDictionaryKey: key) as? String else {
            return nil
        }

        let value = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty, !value.contains("$(") else { return nil }
        return value
    }
}
