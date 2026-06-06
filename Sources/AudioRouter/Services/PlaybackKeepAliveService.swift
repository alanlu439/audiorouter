import AppKit
import Foundation

public final class PlaybackKeepAliveService {
    private struct ResumeTarget: Hashable {
        let bundleIdentifier: String
        let script: String
    }

    private var lastAttemptDate = Date.distantPast
    private let minimumAttemptInterval: TimeInterval

    public init(minimumAttemptInterval: TimeInterval = 1.4) {
        self.minimumAttemptInterval = minimumAttemptInterval
    }

    public func resumeAfterDeviceChange(sources: [AudioSource]) {
        let now = Date()
        guard now.timeIntervalSince(lastAttemptDate) >= minimumAttemptInterval else { return }

        let targets = Self.resumeTargets(from: sources)
        guard !targets.isEmpty else { return }

        lastAttemptDate = now
        DispatchQueue.global(qos: .utility).async {
            for target in targets {
                Self.runAppleScript(target.script)
            }
        }
    }

    public static func resumeCandidateBundleIdentifiers(
        from sources: [AudioSource],
        requireRunning: Bool = true
    ) -> [String] {
        resumeTargets(from: sources, requireRunning: requireRunning).map(\.bundleIdentifier)
    }

    private static func resumeTargets(from sources: [AudioSource], requireRunning: Bool = true) -> [ResumeTarget] {
        var targets: [ResumeTarget] = []
        var seenBundleIDs = Set<String>()

        for source in sources {
            guard let bundleIdentifier = source.bundleIdentifier,
                  seenBundleIDs.insert(bundleIdentifier).inserted,
                  isLikelyResumeCandidate(source),
                  !requireRunning || isRunning(bundleIdentifier: bundleIdentifier),
                  let script = resumeScript(for: bundleIdentifier) else {
                continue
            }
            targets.append(ResumeTarget(bundleIdentifier: bundleIdentifier, script: script))
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

    private static func resumeScript(for bundleIdentifier: String) -> String? {
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
