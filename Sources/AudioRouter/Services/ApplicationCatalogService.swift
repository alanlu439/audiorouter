import AppKit
import Foundation

final class ApplicationCatalogService {
    private let fileManager: FileManager
    private let allowedBundleIDs: Set<String> = [
        "com.google.Chrome",
        "com.apple.Music",
        "com.spotify.client"
    ]
    private let allowedDisplayNames: Set<String> = [
        "apple music",
        "chrome",
        "google chrome",
        "music",
        "spotify"
    ]

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    func availableApplications(audioProcesses: [AudioProcessInfo]) -> [AppSoundSource] {
        var sourcesByKey: [String: AppSoundSource] = [:]

        for process in audioProcesses {
            upsert(AppSoundSource(process: process), into: &sourcesByKey)
        }

        for app in NSWorkspace.shared.runningApplications where app.activationPolicy == .regular {
            let source = AppSoundSource(
                displayName: app.localizedName ?? app.bundleIdentifier ?? "Application \(app.processIdentifier)",
                bundleID: app.bundleIdentifier,
                appURL: app.bundleURL,
                processObjectID: audioProcesses.first { process in
                    process.pid == app.processIdentifier || process.bundleID == app.bundleIdentifier
                }?.processObjectID,
                pid: app.processIdentifier,
                isRunning: true,
                isRunningOutput: audioProcesses.contains { process in
                    process.pid == app.processIdentifier || process.bundleID == app.bundleIdentifier
                },
                deviceObjectIDs: audioProcesses.first { process in
                    process.pid == app.processIdentifier || process.bundleID == app.bundleIdentifier
                }?.deviceObjectIDs ?? []
            )
            upsert(source, into: &sourcesByKey)
        }

        for appURL in installedApplicationURLs() {
            guard let bundle = Bundle(url: appURL) else { continue }
            let bundleID = bundle.bundleIdentifier
            let displayName = displayName(for: bundle, url: appURL)
            let source = AppSoundSource(
                displayName: displayName,
                bundleID: bundleID,
                appURL: appURL,
                processObjectID: nil,
                pid: nil,
                isRunning: false,
                isRunningOutput: false,
                deviceObjectIDs: []
            )
            upsert(source, into: &sourcesByKey)
        }

        return sourcesByKey.values
            .filter(isAllowedApplication)
            .sorted { lhs, rhs in
            let lhsRank = appRank(lhs)
            let rhsRank = appRank(rhs)
            if lhsRank != rhsRank {
                return lhsRank < rhsRank
            }
            if lhs.isRunningOutput != rhs.isRunningOutput {
                return lhs.isRunningOutput
            }
            if lhs.isRunning != rhs.isRunning {
                return lhs.isRunning
            }
            return lhs.displayName.localizedCaseInsensitiveCompare(rhs.displayName) == .orderedAscending
        }
    }

    private func isAllowedApplication(_ source: AppSoundSource) -> Bool {
        if let bundleID = source.bundleID, allowedBundleIDs.contains(bundleID) {
            return true
        }
        return allowedDisplayNames.contains(source.displayName.trimmingCharacters(in: .whitespacesAndNewlines).lowercased())
    }

    private func appRank(_ source: AppSoundSource) -> Int {
        if source.bundleID == "com.apple.Music" || source.displayName.localizedCaseInsensitiveContains("music") {
            return 0
        }
        if source.bundleID == "com.spotify.client" || source.displayName.localizedCaseInsensitiveContains("spotify") {
            return 1
        }
        if source.bundleID == "com.google.Chrome" || source.displayName.localizedCaseInsensitiveContains("chrome") {
            return 2
        }
        return 3
    }

    private func upsert(_ source: AppSoundSource, into sources: inout [String: AppSoundSource]) {
        let source = canonicalized(source)
        let key = canonicalKey(for: source)
        guard let existing = sources[key] else {
            sources[key] = source
            return
        }

        sources[key] = AppSoundSource(
            displayName: preferred(existing.displayName, source.displayName),
            bundleID: existing.bundleID ?? source.bundleID,
            appURL: existing.appURL ?? source.appURL,
            processObjectID: existing.processObjectID ?? source.processObjectID,
            pid: existing.pid ?? source.pid,
            isRunning: existing.isRunning || source.isRunning,
            isRunningOutput: existing.isRunningOutput || source.isRunningOutput,
            deviceObjectIDs: existing.deviceObjectIDs.isEmpty ? source.deviceObjectIDs : existing.deviceObjectIDs
        )
    }

    private func canonicalKey(for source: AppSoundSource) -> String {
        switch source.displayName {
        case "Apple Music":
            return "known-app:apple-music"
        case "Spotify":
            return "known-app:spotify"
        case "Chrome":
            return "known-app:chrome"
        default:
            return source.bundleID ?? source.appURL?.path ?? source.displayName
        }
    }

    private func canonicalized(_ source: AppSoundSource) -> AppSoundSource {
        AppSoundSource(
            displayName: canonicalDisplayName(for: source),
            bundleID: source.bundleID,
            appURL: source.appURL,
            processObjectID: source.processObjectID,
            pid: source.pid,
            isRunning: source.isRunning,
            isRunningOutput: source.isRunningOutput,
            deviceObjectIDs: source.deviceObjectIDs
        )
    }

    private func canonicalDisplayName(for source: AppSoundSource) -> String {
        if source.bundleID == "com.apple.Music" || source.displayName.localizedCaseInsensitiveCompare("Music") == .orderedSame {
            return "Apple Music"
        }
        if source.bundleID == "com.spotify.client" || source.displayName.localizedCaseInsensitiveContains("spotify") {
            return "Spotify"
        }
        if source.bundleID == "com.google.Chrome" || source.displayName.localizedCaseInsensitiveContains("chrome") {
            return "Chrome"
        }
        return source.displayName
    }

    private func preferred(_ lhs: String, _ rhs: String) -> String {
        lhs.count <= rhs.count ? lhs : rhs
    }

    private func installedApplicationURLs() -> [URL] {
        let roots = [
            URL(fileURLWithPath: "/Applications", isDirectory: true),
            URL(fileURLWithPath: "/System/Applications", isDirectory: true),
            URL(fileURLWithPath: "/System/Applications/Utilities", isDirectory: true),
            fileManager.homeDirectoryForCurrentUser.appendingPathComponent("Applications", isDirectory: true)
        ]

        var urls: Set<URL> = []
        for root in roots where fileManager.fileExists(atPath: root.path) {
            guard let enumerator = fileManager.enumerator(
                at: root,
                includingPropertiesForKeys: [.isDirectoryKey],
                options: [.skipsHiddenFiles, .skipsPackageDescendants]
            ) else { continue }

            for case let url as URL in enumerator where url.pathExtension == "app" {
                urls.insert(url)
            }
        }
        return Array(urls)
    }

    private func displayName(for bundle: Bundle, url: URL) -> String {
        let info = bundle.localizedInfoDictionary ?? bundle.infoDictionary ?? [:]
        return info["CFBundleDisplayName"] as? String
            ?? info["CFBundleName"] as? String
            ?? url.deletingPathExtension().lastPathComponent
    }
}
