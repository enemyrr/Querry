//
//  AccountSettingsView.swift
//  Pluk
//

import AppKit
import SwiftUI

struct AccountSettingsView: View {
    private var authService = WorkOSAuthService.shared
    @State private var isCardEnvReady = false
    @State private var sinceYear: String = ""
    @State private var lastSubscriptionFetch: Date?
    private static let subscriptionRefetchCooldown: TimeInterval = 60

    var body: some View {
        AccountSettingsContentView(
            authService: authService,
            isCardEnvReady: isCardEnvReady,
            sinceYear: sinceYear
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .task(id: authService.isAuthenticated) {
            guard authService.isAuthenticated else {
                isCardEnvReady = false
                return
            }
            await refreshSubscriptionIfStale()
            if let user = authService.currentUser {
                let year = (authService.subscriptionStartDate ?? .now).formatted(.dateTime.year())
                sinceYear = year
                await PremiumCardView.preload(
                    displayName: user.displayName,
                    sinceYear: year,
                    memberSerial: authService.memberSerial
                )
            }
            isCardEnvReady = true
        }
        .onDisappear {
            PremiumCardView.purge()
        }
        .onReceive(
            NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)
        ) { _ in
            guard authService.isAuthenticated else { return }
            Task { await refreshSubscriptionIfStale() }
        }
    }

    private func refreshSubscriptionIfStale() async {
        if let last = lastSubscriptionFetch,
            Date.now.timeIntervalSince(last) < Self.subscriptionRefetchCooldown
        {
            return
        }
        await authService.fetchSubscriptionStatus()
        lastSubscriptionFetch = .now
    }
}

private struct AccountSettingsContentView: View {
    let authService: WorkOSAuthService
    let isCardEnvReady: Bool
    let sinceYear: String

    var body: some View {
        if authService.isAuthenticated {
            loggedInView
        } else {
            loggedOutView
        }
    }

    // MARK: - Logged Out

    private var loggedOutView: some View {
        ScrollView {
            VStack(spacing: 20) {
                Image(nsImage: NSApp.applicationIconImage)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 96, height: 96)
                    .padding(.top, 8)

                VStack(spacing: 8) {
                    Text("Get Started")
                        .font(.system(size: 22, weight: .semibold))
                        .multilineTextAlignment(.center)

                    Text(
                        "Log in or create an account to upgrade to Pluk Pro and unlock the full experience."
                    )
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: 360)
                }

                HStack(spacing: 12) {
                    Button {
                        AnalyticsService.shared.trackAuthLoginStarted(
                            mode: "sign_up",
                            source: "account_pane"
                        )
                        authService.login(signUp: true)
                    } label: {
                        Text("Sign Up")
                            .frame(minWidth: 80)
                    }
                    .tintedGlassButtonStyle()
                    .disabled(authService.isLoading)

                    Button("Log In") {
                        AnalyticsService.shared.trackAuthLoginStarted(
                            mode: "log_in",
                            source: "account_pane"
                        )
                        authService.login()
                    }
                    .controlSize(.large)
                    .buttonStyle(.borderless)
                    .disabled(authService.isLoading)
                }
                .padding(.top, 4)

                if authService.isLoading {
                    ProgressView()
                        .controlSize(.small)
                        .padding(.top, 4)
                }

                if let error = authService.authError {
                    Text(error)
                        .font(.system(size: 12))
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: 360)
                }
            }
            .padding(.horizontal, 32)
            .padding(.top, 48)
            .padding(.bottom, 32)
            .frame(maxWidth: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    // MARK: - Logged In

    @ViewBuilder
    private var loggedInView: some View {
        if let user = authService.currentUser {
            if !authService.hasLoadedSubscriptionStatus {
                loadingView
            } else if authService.isPro {
                premiumView(user: user)
            } else {
                nonPremiumView(user: user)
            }
        }
    }

    private var loadingView: some View {
        ProgressView()
            .controlSize(.regular)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
    }

    private func premiumView(user: WorkOSUser) -> some View {
        ScrollView {
            VStack(spacing: 0) {
                Group {
                    if isCardEnvReady {
                        PremiumCardView(
                            displayName: user.displayName,
                            sinceYear: sinceYear,
                            memberSerial: authService.memberSerial
                        )
                    } else {
                        Color.clear
                            .frame(width: 440, height: 278)
                    }
                }
                .padding(.bottom, 4)

                Form {
                    Section {
                        LabeledContent("Email", value: user.email)
                        LabeledContent("Current Plan", value: authService.planDisplayName)
                        LabeledContent("Renewal Date", value: renewalDateText ?? "—")
                    }
                }
                .formStyle(.grouped)
                .scrollDisabled(true)
                .fixedSize(horizontal: false, vertical: true)

                HStack {
                    Button("Sign Out...", role: .destructive) {
                        authService.logout()
                    }
                    .buttonStyle(.bordered)

                    Spacer()

                    Button {
                        AnalyticsService.shared.trackBillingCheckoutStarted(
                            source: "account_pane_manage",
                            currentStatus: authService.subscriptionStatus.rawValue
                        )
                        Task { await authService.openBillingPortal() }
                    } label: {
                        BillingPortalButtonLabel(authService: authService)
                    }
                    .buttonStyle(.bordered)
                    .disabled(authService.isBillingLoading)
                }
                .controlSize(.large)
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            }
            .frame(maxWidth: .infinity, alignment: .top)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    private func nonPremiumView(user: WorkOSUser) -> some View {
        ScrollView {
            VStack(spacing: 28) {
                UpgradeHeroView()

                UpgradeBenefitsView()

                VStack(spacing: 10) {
                    Button {
                        AnalyticsService.shared.trackBillingCheckoutStarted(
                            source: "account_pane_upgrade",
                            currentStatus: authService.subscriptionStatus.rawValue
                        )
                        Task { await authService.openBillingPortal() }
                    } label: {
                        BillingPortalButtonLabel(authService: authService)
                            .frame(minWidth: 160)
                    }
                    .tintedGlassButtonStyle()
                    .disabled(authService.isBillingLoading)

                    if let detail = authService.subscriptionDetailText {
                        Text(detail)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.secondary)
                    } else {
                        Text("14-day free trial. Then $15/month. Cancel anytime.")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: 420)

                HStack(spacing: 8) {
                    Text("Signed in as \(user.email)")
                        .font(.system(size: 11))
                        .foregroundStyle(.tertiary)

                    Button {
                        authService.logout()
                    } label: {
                        Text("Sign out")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(Color.primaryButton)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.bottom, 24)
            }
            .padding(.horizontal, 32)
            .padding(.top, 70)
            .frame(maxWidth: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    // MARK: - Premium Helpers

    private var renewalDateText: String? {
        let date: Date? = {
            if authService.isTrialing, let end = authService.trialEnd {
                return end
            }
            return authService.effectiveCancelDate ?? authService.currentPeriodEnd
        }()
        return date?.formatted(date: .numeric, time: .omitted)
    }
}

private struct BillingPortalButtonLabel: View {
    let authService: WorkOSAuthService

    var body: some View {
        ZStack {
            Text(authService.subscriptionButtonLabel)
                .opacity(authService.isBillingLoading ? 0 : 1)
            ProgressView()
                .controlSize(.small)
                .opacity(authService.isBillingLoading ? 1 : 0)
        }
    }
}

// MARK: - Upgrade Hero

private struct UpgradeHeroView: View {
    var body: some View {
        VStack(spacing: 4) {
            Text("Pluk Pro")
                .font(.system(size: 18, weight: .semibold))

            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text("$15")
                    .font(.system(size: 13, weight: .medium))
                Text("/month")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - Upgrade Benefits

private struct UpgradeBenefitsView: View {
    private let benefits: [Benefit] = [
        Benefit(icon: "sparkles", title: "Expanded AI usage"),
        Benefit(icon: "infinity", title: "Unlimited connections"),
        Benefit(icon: "square.and.arrow.up", title: "Unlimited dashboard shares"),
        Benefit(icon: "wand.and.stars", title: "Full Notebook Agent"),
        Benefit(icon: "bolt.badge.clock", title: "Priority support"),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Pro")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .padding(.leading, 2)
                .padding(.bottom, 6)

            VStack(spacing: 0) {
                ForEach(benefits, id: \.title) { benefit in
                    BenefitRow(benefit: benefit)
                }
            }
        }
        .frame(maxWidth: 420)
    }

    fileprivate struct Benefit {
        let icon: String
        let title: String
    }

    private struct BenefitRow: View {
        let benefit: Benefit

        var body: some View {
            HStack(spacing: 10) {
                Image(systemName: benefit.icon)
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .frame(width: 18, alignment: .center)

                Text(benefit.title)
                    .font(.system(size: 13))

                Spacer(minLength: 0)

                Text("Pro")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color.primaryButton)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 1.5)
                    .overlay(
                        Capsule()
                            .strokeBorder(Color.primaryButton.opacity(0.4), lineWidth: 1)
                    )
            }
            .padding(.vertical, 8)
        }
    }
}

private struct TintedGlassButtonStyle: ButtonStyle {
    @State private var isHovering = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(Color.primaryButton)
            .padding(.horizontal, 18)
            .padding(.vertical, 9)
            .background(
                Capsule()
                    .fill(
                        Color.primaryButton.opacity(
                            configuration.isPressed ? 0.22 : (isHovering ? 0.2 : 0.16)
                        ))
            )
            .overlay(
                Capsule()
                    .strokeBorder(Color.primaryButton.opacity(0.35), lineWidth: 0.5)
            )
            .contentShape(Capsule())
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.easeOut(duration: 0.1), value: configuration.isPressed)
            .onHover { isHovering = $0 }
    }
}

extension View {
    @ViewBuilder
    func tintedGlassButtonStyle() -> some View {
        if #available(macOS 26.0, *) {
            self
                .buttonStyle(.glass)
                .tint(Color.primaryButton)
                .controlSize(.extraLarge)
        } else {
            self.buttonStyle(TintedGlassButtonStyle())
        }
    }
}
