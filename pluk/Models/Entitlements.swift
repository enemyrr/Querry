//
//  Entitlements.swift
//  Pluk
//

import Foundation

/// Feature flags derived from the user's subscription tier. Read gates from
/// `WorkOSAuthService.shared.entitlements` instead of inspecting
/// `subscriptionStatus` directly — this keeps tier logic in one place so
/// adding the Team tier later is a localized change.
struct Entitlements: Sendable, Equatable {
    private static let freeMonthlyLLMCreditBudgetCents = 500
    private static let proMonthlyLLMCreditBudgetCents = 5_000

    /// Maximum number of concurrent open connection instances (tabs).
    /// Free = 4, Pro = unlimited. Matches the "4 connections at a time"
    /// promise on pluk.sh/pricing.
    let maxConnections: Int?
    let maxDashboardShares: Int?
    /// Internal monthly notebook agent credit allocation in cents. `nil` means unlimited.
    let monthlyLLMCreditBudgetCents: Int?
    let hasExpandedAI: Bool
    let hasNotebookAgent: Bool
    let hasPrioritySupport: Bool

    static let free = Entitlements(
        maxConnections: 4,
        maxDashboardShares: 2,
        monthlyLLMCreditBudgetCents: freeMonthlyLLMCreditBudgetCents,
        hasExpandedAI: false,
        hasNotebookAgent: false,
        hasPrioritySupport: false
    )

    static let pro = Entitlements(
        maxConnections: nil,
        maxDashboardShares: nil,
        monthlyLLMCreditBudgetCents: proMonthlyLLMCreditBudgetCents,
        hasExpandedAI: true,
        hasNotebookAgent: true,
        hasPrioritySupport: true
    )

    func canAddConnection(currentCount: Int) -> Bool {
        guard let limit = maxConnections else { return true }
        return currentCount < limit
    }

    func canShareDashboard(currentCount: Int) -> Bool {
        guard let limit = maxDashboardShares else { return true }
        return currentCount < limit
    }
}

extension WorkOSAuthService {
    var isPro: Bool {
        subscriptionStatus == .active || subscriptionStatus == .trialing
    }

    var entitlements: Entitlements {
        isPro ? .pro : .free
    }

    var planDisplayName: String {
        switch subscriptionStatus {
        case .active: return isCancelPending ? "Pro (Canceling)" : "Pro"
        case .trialing: return "Pro (Trial)"
        case .pastDue: return "Pro (Past Due)"
        case .canceled: return "Canceled"
        case .none: return "Free"
        }
    }
}
