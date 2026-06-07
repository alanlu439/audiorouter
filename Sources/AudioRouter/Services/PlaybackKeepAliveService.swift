import AppKit
import Foundation

public final class PlaybackKeepAliveService: @unchecked Sendable {
    private struct KeepAliveTarget: Hashable {
        let bundleIdentifier: String
        let script: String
    }

    private let spotifyPlaybackStateNotification = Notification.Name("com.spotify.client.PlaybackStateChanged")
    private var lastAttemptDate = Date.distantPast
    private let minimumAttemptInterval: TimeInterval
    private var spotifyPlaybackObserver: NSObjectProtocol?
    private var spotifyResumeBurstTask: Task<Void, Never>?

    public init(minimumAttemptInterval: TimeInterval = 0.14) {
        self.minimumAttemptInterval = minimumAttemptInterval
    }

    public func keepPlaying(sources: [AudioSource]) {
        let now = Date()
        guard now.timeIntervalSince(lastAttemptDate) >= minimumAttemptInterval else { return }

        let targets = Self.keepAliveTargets(from: sources)
        guard !targets.isEmpty else { return }

        lastAttemptDate = now
        DispatchQueue.global(qos: .utility).async {
            for target in targets {
                Self.runAppleScript(target.script)
            }
        }
    }

    @MainActor
    public func startImmediatePlaybackObservers(
        sourcesProvider: @escaping () -> [AudioSource],
        isEnabled: @escaping () -> Bool
    ) {
        guard spotifyPlaybackObserver == nil else { return }

        spotifyPlaybackObserver = DistributedNotificationCenter.default().addObserver(
            forName: spotifyPlaybackStateNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            Task { @MainActor [weak self] in
                guard let self,
                      isEnabled(),
                      Self.isSpotifyPausedPlaybackState(userInfo: notification.userInfo) else {
                    return
                }
                self.scheduleSpotifyResumeBurst(sourcesProvider: sourcesProvider, isEnabled: isEnabled)
            }
        }
    }

    @MainActor
    public func stopImmediatePlaybackObservers() {
        if let spotifyPlaybackObserver {
            DistributedNotificationCenter.default().removeObserver(spotifyPlaybackObserver)
            self.spotifyPlaybackObserver = nil
        }
        spotifyResumeBurstTask?.cancel()
        spotifyResumeBurstTask = nil
    }

    public func keepPlayingDuringDeviceChange(sources: [AudioSource]) {
        keepPlaying(sources: sources)
    }

    public static func keepAliveCandidateBundleIdentifiers(
        from sources: [AudioSource],
        requireRunning: Bool = true
    ) -> [String] {
        keepAliveTargets(from: sources, requireRunning: requireRunning).map(\.bundleIdentifier)
    }

    public static func resumeCandidateBundleIdentifiers(
        from sources: [AudioSource],
        requireRunning: Bool = true
    ) -> [String] {
        keepAliveCandidateBundleIdentifiers(from: sources, requireRunning: requireRunning)
    }

    public static func spotifyPlaybackState(from userInfo: [AnyHashable: Any]?) -> String? {
        let keys = ["Player State", "PlayerState", "state"]
        for key in keys {
            if let state = userInfo?[key] as? String {
                return state.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            }
        }
        return nil
    }

    public static func isSpotifyPausedPlaybackState(userInfo: [AnyHashable: Any]?) -> Bool {
        spotifyPlaybackState(from: userInfo) == "paused"
    }

    @MainActor
    private func scheduleSpotifyResumeBurst(
        sourcesProvider: @escaping () -> [AudioSource],
        isEnabled: @escaping () -> Bool
    ) {
        spotifyResumeBurstTask?.cancel()
        spotifyResumeBurstTask = Task { @MainActor [weak self] in
            let attemptDelays: [TimeInterval] = [0, 0.08, 0.18, 0.35, 0.7, 1.2]
            for delay in attemptDelays {
                if delay > 0 {
                    try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                }
                guard !Task.isCancelled, isEnabled() else { return }
                self?.keepPlayingImmediately(
                    sources: sourcesProvider(),
                    bundleIdentifiers: ["com.spotify.client"]
                )
            }
            self?.spotifyResumeBurstTask = nil
        }
    }

    private func keepPlayingImmediately(sources: [AudioSource], bundleIdentifiers: Set<String>) {
        let targets = Self.keepAliveTargets(from: sources)
            .filter { bundleIdentifiers.contains($0.bundleIdentifier) }
        guard !targets.isEmpty else { return }

        lastAttemptDate = Date()
        DispatchQueue.global(qos: .userInitiated).async {
            for target in targets {
                Self.runAppleScript(target.script)
            }
        }
    }

    private static func keepAliveTargets(from sources: [AudioSource], requireRunning: Bool = true) -> [KeepAliveTarget] {
        var targets: [KeepAliveTarget] = []
        var seenBundleIDs = Set<String>()

        for source in sources {
            guard let bundleIdentifier = source.bundleIdentifier,
                  seenBundleIDs.insert(bundleIdentifier).inserted,
                  isLikelyResumeCandidate(source),
                  !requireRunning || isRunning(bundleIdentifier: bundleIdentifier),
                  let script = keepAliveScript(for: bundleIdentifier) else {
                continue
            }
            targets.append(KeepAliveTarget(bundleIdentifier: bundleIdentifier, script: script))
        }

        return targets
    }

    private static func isLikelyResumeCandidate(_ source: AudioSource) -> Bool {
        source.isRunning
            || source.processID > 0
            || source.isProducingAudio
            || Date().timeIntervalSince(source.lastActiveDate) < 120
    }

    private static func isRunning(bundleIdentifier: String) -> Bool {
        !NSRunningApplication.runningApplications(withBundleIdentifier: bundleIdentifier).isEmpty
    }

    private static func keepAliveScript(for bundleIdentifier: String) -> String? {
        switch bundleIdentifier {
        case "com.spotify.client":
            return #"tell application id "com.spotify.client" to play"#
        case "com.apple.Music":
            return #"tell application id "com.apple.Music" to play"#
        default:
            return nil
        }
    }

    private static func runAppleScript(_ source: String) {
        var error: NSDictionary?
        NSAppleScript(source: source)?.executeAndReturnError(&error)
    }
}
