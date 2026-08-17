import Foundation

struct LLMTokenUsageSnapshot: Codable, Sendable, Equatable {
    let userKey: String
    let periodKey: String
    let planKey: String
    let creditBudgetCents: Int?
    var inputTokens: Int
    var outputTokens: Int
    var cacheCreationInputTokens: Int
    var cacheReadInputTokens: Int

    var usedTokens: Int {
        inputTokens + outputTokens + cacheCreationInputTokens + cacheReadInputTokens
    }

    var usedCreditCents: Double {
        SonnetTokenPricing.costCents(for: self)
    }

    var remainingCreditCents: Double {
        guard let creditBudgetCents else { return .infinity }
        return max(0, Double(creditBudgetCents) - usedCreditCents)
    }

    var isExhausted: Bool {
        guard let creditBudgetCents else { return false }
        return usedCreditCents >= Double(creditBudgetCents)
    }
}

private enum SonnetTokenPricing {
    private static let tokenDenominator = 1_000_000.0
    // Claude Sonnet 4.6 standard pricing; cache write uses the 5-minute TTL rate.
    private static let inputCentsPerMillionTokens = 300.0
    private static let outputCentsPerMillionTokens = 1_500.0
    private static let cacheCreationCentsPerMillionTokens = 375.0
    private static let cacheReadCentsPerMillionTokens = 30.0

    static func costCents(for snapshot: LLMTokenUsageSnapshot) -> Double {
        costCents(
            inputTokens: snapshot.inputTokens,
            outputTokens: snapshot.outputTokens,
            cacheCreationInputTokens: snapshot.cacheCreationInputTokens,
            cacheReadInputTokens: snapshot.cacheReadInputTokens
        )
    }

    static func costCents(
        inputTokens: Int,
        outputTokens: Int,
        cacheCreationInputTokens: Int,
        cacheReadInputTokens: Int
    ) -> Double {
        let inputCost = Double(inputTokens) * inputCentsPerMillionTokens
        let outputCost = Double(outputTokens) * outputCentsPerMillionTokens
        let cacheCreationCost = Double(cacheCreationInputTokens) * cacheCreationCentsPerMillionTokens
        let cacheReadCost = Double(cacheReadInputTokens) * cacheReadCentsPerMillionTokens
        return (inputCost + outputCost + cacheCreationCost + cacheReadCost) / tokenDenominator
    }
}

@Observable
@MainActor
final class LLMTokenUsageService {
    static let shared = LLMTokenUsageService()

    private let userDefaults = UserDefaults.standard
    private let keyPrefix = "llm_token_usage_v1"
    private(set) var latestSnapshot: LLMTokenUsageSnapshot

    private init() {
        latestSnapshot = Self.emptySnapshot()
        latestSnapshot = loadSnapshot(date: Date())
    }

    func currentSnapshot(date: Date = Date()) -> LLMTokenUsageSnapshot {
        let snapshot = loadSnapshot(date: date)
        updateLatestSnapshot(snapshot)
        return snapshot
    }

    @discardableResult
    func record(_ usage: BedrockTokenUsage, date: Date = Date()) -> LLMTokenUsageSnapshot {
        var snapshot = loadSnapshot(date: date)
        snapshot.inputTokens += usage.inputTokens
        snapshot.outputTokens += usage.outputTokens
        snapshot.cacheCreationInputTokens += usage.cacheCreationInputTokens
        snapshot.cacheReadInputTokens += usage.cacheReadInputTokens
        persist(snapshot, forKey: storageKey(userKey: snapshot.userKey, periodKey: snapshot.periodKey))
        updateLatestSnapshot(snapshot)
        return snapshot
    }

    func exhaustionMessage(for snapshot: LLMTokenUsageSnapshot? = nil) -> String {
        let snapshot = snapshot ?? currentSnapshot()
        guard snapshot.creditBudgetCents != nil else {
            return "Your \(snapshot.planKey.capitalized) plan includes unlimited AI credits."
        }
        return "Monthly AI credits reached. Your credits reset on \(resetDateText(for: snapshot))."
    }

    func resetDateText(for snapshot: LLMTokenUsageSnapshot) -> String {
        resetDateText(after: snapshot.periodKey)
    }

    private func loadSnapshot(date: Date) -> LLMTokenUsageSnapshot {
        let userKey = currentUserKey
        let periodKey = Self.periodKey(for: date)
        let planKey = currentPlanKey
        let creditBudgetCents = WorkOSAuthService.shared.entitlements.monthlyLLMCreditBudgetCents
        let key = storageKey(userKey: userKey, periodKey: periodKey)

        if var snapshot = readSnapshot(forKey: key) {
            if snapshot.planKey != planKey || snapshot.creditBudgetCents != creditBudgetCents {
                snapshot = LLMTokenUsageSnapshot(
                    userKey: userKey,
                    periodKey: periodKey,
                    planKey: planKey,
                    creditBudgetCents: creditBudgetCents,
                    inputTokens: snapshot.inputTokens,
                    outputTokens: snapshot.outputTokens,
                    cacheCreationInputTokens: snapshot.cacheCreationInputTokens,
                    cacheReadInputTokens: snapshot.cacheReadInputTokens
                )
                persist(snapshot, forKey: key)
            }
            return snapshot
        }

        let snapshot = LLMTokenUsageSnapshot(
            userKey: userKey,
            periodKey: periodKey,
            planKey: planKey,
            creditBudgetCents: creditBudgetCents,
            inputTokens: 0,
            outputTokens: 0,
            cacheCreationInputTokens: 0,
            cacheReadInputTokens: 0
        )
        persist(snapshot, forKey: key)
        return snapshot
    }

    private var currentUserKey: String {
        WorkOSAuthService.shared.currentUser?.id ?? "anonymous"
    }

    private var currentPlanKey: String {
        WorkOSAuthService.shared.isPro ? "pro" : "free"
    }

    private func storageKey(userKey: String, periodKey: String) -> String {
        "\(keyPrefix).\(userKey).\(periodKey)"
    }

    private func readSnapshot(forKey key: String) -> LLMTokenUsageSnapshot? {
        guard let data = userDefaults.data(forKey: key) else { return nil }
        return try? Foundation.JSONDecoder().decode(LLMTokenUsageSnapshot.self, from: data)
    }

    private func persist(_ snapshot: LLMTokenUsageSnapshot, forKey key: String) {
        guard let data = try? Foundation.JSONEncoder().encode(snapshot) else { return }
        userDefaults.set(data, forKey: key)
    }

    private func updateLatestSnapshot(_ snapshot: LLMTokenUsageSnapshot) {
        guard latestSnapshot != snapshot else { return }
        latestSnapshot = snapshot
    }

    private static func periodKey(for date: Date) -> String {
        let components = Calendar.current.dateComponents([.year, .month], from: date)
        let year = components.year ?? 0
        let month = components.month ?? 0
        let monthText = month < 10 ? "0\(month)" : "\(month)"
        return "\(year)-\(monthText)"
    }

    private func resetDateText(after periodKey: String) -> String {
        let parts = periodKey.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 2,
              let monthStart = Calendar.current.date(from: DateComponents(year: parts[0], month: parts[1], day: 1)),
              let nextMonth = Calendar.current.date(byAdding: .month, value: 1, to: monthStart) else {
            return "the start of next month"
        }
        return nextMonth.formatted(date: .abbreviated, time: .omitted)
    }

    private static func emptySnapshot() -> LLMTokenUsageSnapshot {
        LLMTokenUsageSnapshot(
            userKey: "anonymous",
            periodKey: periodKey(for: Date()),
            planKey: "free",
            creditBudgetCents: 0,
            inputTokens: 0,
            outputTokens: 0,
            cacheCreationInputTokens: 0,
            cacheReadInputTokens: 0
        )
    }
}
