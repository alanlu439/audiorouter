import AppKit
import Foundation

public final class RunningAppService {
    private let likelyAudioBundleIDs: Set<String> = [
        "com.spotify.client",
        "com.google.Chrome",
        "com.apple.Music"
    ]

    public init() {}

    public func listRunningApps() -> [AudioSource] {
        NSWorkspace.shared.runningApplications
            .filter { $0.activationPolicy == .regular }
            .map(source(for:))
            .sorted { $0.appName.localizedCaseInsensitiveCompare($1.appName) == .orderedAscending }
    }

    public func identifyLikelyAudioApps() -> [AudioSource] {
        let apps = listRunningApps()
        let likely = apps.filter { source in
            source.bundleIdentifier.map { likelyAudioBundleIDs.contains($0) } ?? false
        }
        return likely.isEmpty ? apps : likely
    }

    public func getAppIcon(for app: NSRunningApplication) -> String? {
        app.bundleURL?.path
    }

    public func getBundleIdentifier(for app: NSRunningApplication) -> String? {
        app.bundleIdentifier
    }

    public func getProcessID(for app: NSRunningApplication) -> pid_t {
        app.processIdentifier
    }

    private func source(for app: NSRunningApplication) -> AudioSource {
        AudioSource(
            id: app.bundleIdentifier ?? "pid-\(app.processIdentifier)",
            appName: app.localizedName ?? "App \(app.processIdentifier)",
            bundleIdentifier: app.bundleIdentifier,
            processID: app.processIdentifier,
            icon: getAppIcon(for: app),
            isRunning: !app.isTerminated,
            isProducingAudio: false
        )
    }
}
