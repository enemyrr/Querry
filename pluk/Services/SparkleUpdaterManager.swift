import Foundation
import Observation
import os.log
import Sparkle
import UserNotifications

/// SparkleUpdaterManager with automatic update downloads enabled.
///
/// Manages application updates using the Sparkle framework. Handles automatic
/// update checking, downloading, and installation while respecting user preferences
/// and update channels. Integrates with macOS notifications for update announcements.
@MainActor
public final class SparkleUpdaterManager: NSObject, SPUUpdaterDelegate {
    public static let shared = SparkleUpdaterManager()

    public var updaterController: SPUStandardUpdaterController?
    private let logger = os.Logger(
        subsystem: Bundle.main.bundleIdentifier!,
        category: "SparkleUpdater"
    )

    private nonisolated static let staticLogger = os.Logger(
        subsystem: Bundle.main.bundleIdentifier!,
        category: "SparkleUpdater"
    )

    override public init() {
        super.init()

        updaterController = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: self,
            userDriverDelegate: nil
        )

        guard let updater = updaterController?.updater else { return }

        let autoCheckForUpdates = UserDefaults.standard.object(forKey: "autoCheckForUpdates") as? Bool ?? true
        updater.automaticallyChecksForUpdates = autoCheckForUpdates

        #if DEBUG
            updater.automaticallyDownloadsUpdates = false
            logger.info("Sparkle updater initialized in DEBUG mode - auto check: \(autoCheckForUpdates)")
        #else
            updater.automaticallyDownloadsUpdates = autoCheckForUpdates
            updater.updateCheckInterval = 86_400
            logger.info("Sparkle updater initialized - auto check: \(autoCheckForUpdates)")
        #endif

        do {
            try updater.start()
        } catch {
            logger.error("Failed to start Sparkle updater: \(error)")
        }
    }

    public func setUpdateChannel(_ channel: UpdateChannel) {
        // Save the channel preference
        UserDefaults.standard.set(channel.rawValue, forKey: "updateChannel")
        logger.info("Update channel set to: \(channel.rawValue)")

        // The actual feed URL will be provided by the delegate method
    }

    public func checkForUpdatesInBackground() {
        guard let updater = updaterController?.updater else { return }
        updater.checkForUpdatesInBackground()
        logger.info("Background update check initiated")
    }

    public func checkForUpdates() {
        guard let controller = updaterController else {
            logger.warning("Cannot check for updates: updater not initialized")
            return
        }
        controller.checkForUpdates(nil)
        logger.info("Manual update check initiated")
    }

    public func clearUserDefaults() {
        let sparkleDefaults = [
            "SUEnableAutomaticChecks",
            "SUHasLaunchedBefore",
            "SULastCheckTime",
            "SUSendProfileInfo",
            "SUUpdateRelaunchingMarker",
            "SUAutomaticallyUpdate",
            "SULastProfileSubmissionDate"
        ]

        for key in sparkleDefaults {
            UserDefaults.standard.removeObject(forKey: key)
        }

        logger.info("Sparkle user defaults cleared")
    }
}

// MARK: - SPUUpdaterDelegate

extension SparkleUpdaterManager {
    public nonisolated func updater(_ updater: SPUUpdater, mayPerformUpdateCheck updateCheck: SPUUpdateCheck) throws {
        // Allow update checks by default - not throwing an error means the check is allowed
        // We could add logic here to prevent checks during certain conditions
    }

    public nonisolated func allowedChannels(for updater: SPUUpdater) -> Set<String> {
        // Use UpdateChannel.current which is hardcoded to .prerelease for now
        let channel = UpdateChannel.current
        return channel.includesPreReleases ? Set(["", "prerelease"]) : Set([""])
    }

    public nonisolated func feedURLString(for updater: SPUUpdater) -> String? {
        // Use UpdateChannel.current which ensures everyone gets beta for now
        let channel = UpdateChannel.current
        return channel.appcastURL.absoluteString
    }
}

// MARK: - SparkleViewModel

@MainActor
@Observable
public final class SparkleViewModel {
    public var canCheckForUpdates = false
    public var isCheckingForUpdates = false
    public var automaticallyChecksForUpdates = true
    public var automaticallyDownloadsUpdates = true
    public var updateCheckInterval: TimeInterval = 86_400
    public var lastUpdateCheckDate: Date?
    public var updateChannel: UpdateChannel = .prerelease // Default to prerelease for now

    private let updaterManager = SparkleUpdaterManager.shared

    public init() {
        // Sync with actual Sparkle settings
        if let updater = updaterManager.updaterController?.updater {
            automaticallyChecksForUpdates = updater.automaticallyChecksForUpdates
            automaticallyDownloadsUpdates = updater.automaticallyDownloadsUpdates
            updateCheckInterval = updater.updateCheckInterval
            lastUpdateCheckDate = updater.lastUpdateCheckDate
            canCheckForUpdates = updater.canCheckForUpdates
        }

        // Always use current channel (which is prerelease for now)
        updateChannel = UpdateChannel.current
    }

    public func checkForUpdates() {
        updaterManager.checkForUpdates()
    }

    public func setUpdateChannel(_ channel: UpdateChannel) {
        updateChannel = channel
        updaterManager.setUpdateChannel(channel)
    }
}
