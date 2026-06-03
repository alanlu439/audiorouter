import AppKit
import Foundation

@MainActor
public final class UpdateManager: ObservableObject {
    nonisolated public static let releaseAssetName = "AudioRouter-macOS.zip"
    nonisolated public static let lastAutomaticCheckDefaultsKey = "AudioRouter.lastAutomaticUpdateCheckAt"
    nonisolated public static let defaultAutomaticCheckInterval: TimeInterval = 900

    public struct UpdateInfo: Equatable {
        public let version: String
        public let releaseURL: URL
        public let downloadURL: URL
        public let publishedAt: Date?
        public let body: String?

        public var isDownloadable: Bool {
            true
        }
    }

    @Published public private(set) var isChecking = false
    @Published public private(set) var isDownloading = false
    @Published public private(set) var availableUpdate: UpdateInfo?
    @Published public private(set) var downloadedUpdateURL: URL?
    @Published public private(set) var lastCheckedAt: Date?
    @Published public private(set) var shouldPromptToInstall = false
    @Published public private(set) var message: String = "Updates have not been checked yet."

    private let session: URLSession
    private let defaults: UserDefaults
    private let automaticCheckInterval: TimeInterval
    private let currentVersionProvider: () -> String
    private var automaticCheckTimer: Timer?
    private let latestReleaseURL = URL(string: "https://api.github.com/repos/alanlu439/audiorouter/releases/latest")!
    private let latestDownloadURL = URL(string: "https://github.com/alanlu439/audiorouter/releases/latest/download/AudioRouter-macOS.zip")!

    public init(
        session: URLSession = .shared,
        defaults: UserDefaults = .standard,
        automaticCheckInterval: TimeInterval = UpdateManager.defaultAutomaticCheckInterval,
        currentVersionProvider: @escaping () -> String = {
            Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.0.0"
        }
    ) {
        self.session = session
        self.defaults = defaults
        self.automaticCheckInterval = automaticCheckInterval
        self.currentVersionProvider = currentVersionProvider
        self.lastCheckedAt = defaults.object(forKey: Self.lastAutomaticCheckDefaultsKey) as? Date
    }

    public var currentVersion: String {
        currentVersionProvider()
    }

    public var hasUpdate: Bool {
        availableUpdate != nil
    }

    public var hasDownloadedUpdate: Bool {
        downloadedUpdateURL != nil
    }

    public func checkForUpdates(autoFetch: Bool = true) {
        guard !isChecking else { return }
        isChecking = true
        message = "Checking for updates..."
        Task {
            await performUpdateCheck(autoFetch: autoFetch)
        }
    }

    public func checkAutomaticallyIfNeeded(enabled: Bool, force: Bool = false) {
        guard enabled else { return }
        if !force, let lastCheckedAt, abs(lastCheckedAt.timeIntervalSinceNow) < automaticCheckInterval {
            return
        }
        checkForUpdates(autoFetch: true)
    }

    public func startAutomaticChecks(enabled: Bool) {
        automaticCheckTimer?.invalidate()
        automaticCheckTimer = nil
        guard enabled else { return }

        checkAutomaticallyIfNeeded(enabled: true)
        automaticCheckTimer = Timer.scheduledTimer(withTimeInterval: automaticCheckInterval, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.checkAutomaticallyIfNeeded(enabled: true)
            }
        }
        automaticCheckTimer?.tolerance = min(60, automaticCheckInterval * 0.15)
    }

    public func stopAutomaticChecks() {
        automaticCheckTimer?.invalidate()
        automaticCheckTimer = nil
    }

    public func dismissInstallPrompt() {
        shouldPromptToInstall = false
    }

    public func openLatestRelease() {
        if let releaseURL = availableUpdate?.releaseURL {
            NSWorkspace.shared.open(releaseURL)
        } else {
            NSWorkspace.shared.open(URL(string: "https://github.com/alanlu439/audiorouter/releases/latest")!)
        }
    }

    public func openLatestDownload() {
        if downloadedUpdateURL != nil {
            installDownloadedUpdate()
        } else if availableUpdate != nil {
            fetchAvailableUpdate()
        } else {
            NSWorkspace.shared.open(latestDownloadURL)
        }
    }

    public func fetchAvailableUpdate() {
        guard let availableUpdate else {
            NSWorkspace.shared.open(latestDownloadURL)
            return
        }
        guard !isDownloading else { return }

        if let existingURL = existingDownloadedUpdateURL(for: availableUpdate), FileManager.default.fileExists(atPath: existingURL.path) {
            downloadedUpdateURL = existingURL
            message = "AudioRouter \(availableUpdate.version) is downloaded. Open the ZIP to install."
            return
        }

        isDownloading = true
        message = "Downloading AudioRouter \(availableUpdate.version) ZIP..."
        Task {
            await performUpdateDownload(availableUpdate)
        }
    }

    public func installDownloadedUpdate() {
        guard let downloadedUpdateURL else {
            fetchAvailableUpdate()
            return
        }
        NSWorkspace.shared.open(downloadedUpdateURL)
        shouldPromptToInstall = false
        message = "Opened the AudioRouter ZIP. Move AudioRouter to Applications to finish installing."
    }

    private func performUpdateCheck(autoFetch: Bool) async {
        defer { isChecking = false }
        do {
            let release = try await fetchLatestRelease()
            let latestVersion = Self.displayVersion(from: release.tagName)
            markChecked()

            if Self.isVersion(latestVersion, newerThan: currentVersion) {
                let assetURL = release.assets.first { $0.name == Self.releaseAssetName }?.browserDownloadURL
                    ?? latestDownloadURL
                let update = UpdateInfo(
                    version: latestVersion,
                    releaseURL: release.htmlURL,
                    downloadURL: assetURL,
                    publishedAt: release.publishedAt,
                    body: release.body
                )
                availableUpdate = update
                downloadedUpdateURL = existingDownloadedUpdateURL(for: update)
                if downloadedUpdateURL != nil {
                    message = "AudioRouter \(latestVersion) is downloaded. Open the ZIP to install."
                    shouldPromptToInstall = true
                } else if autoFetch {
                    message = "AudioRouter \(latestVersion) is available."
                    fetchAvailableUpdate()
                } else {
                    message = "AudioRouter \(latestVersion) is available."
                }
            } else {
                availableUpdate = nil
                downloadedUpdateURL = nil
                shouldPromptToInstall = false
                message = "AudioRouter is up to date."
            }
        } catch {
            markChecked()
            if error is DecodingError {
                message = "Could not read the GitHub release feed. The release format may have changed."
            } else {
                message = "Could not check for updates: \(error.localizedDescription)"
            }
        }
    }

    private func performUpdateDownload(_ update: UpdateInfo) async {
        defer { isDownloading = false }
        do {
            var request = URLRequest(url: update.downloadURL)
            request.timeoutInterval = 60
            request.setValue("application/octet-stream", forHTTPHeaderField: "Accept")
            request.setValue("AudioRouter/\(currentVersion)", forHTTPHeaderField: "User-Agent")
            let (temporaryURL, response) = try await session.download(for: request)
            if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
                throw UpdateCheckError.badDownloadStatus(http.statusCode)
            }

            let destinationURL = try downloadedUpdateURL(for: update)
            let directoryURL = destinationURL.deletingLastPathComponent()
            try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
            if FileManager.default.fileExists(atPath: destinationURL.path) {
                try FileManager.default.removeItem(at: destinationURL)
            }
            try FileManager.default.moveItem(at: temporaryURL, to: destinationURL)
            downloadedUpdateURL = destinationURL
            shouldPromptToInstall = true
            message = "AudioRouter \(update.version) is downloaded. Open the ZIP to install."
        } catch {
            downloadedUpdateURL = nil
            shouldPromptToInstall = false
            message = "Could not download update: \(error.localizedDescription)"
        }
    }

    private func markChecked() {
        let date = Date()
        lastCheckedAt = date
        defaults.set(date, forKey: Self.lastAutomaticCheckDefaultsKey)
    }

    private func existingDownloadedUpdateURL(for update: UpdateInfo) -> URL? {
        guard let url = try? downloadedUpdateURL(for: update),
              FileManager.default.fileExists(atPath: url.path) else {
            return nil
        }
        return url
    }

    private func downloadedUpdateURL(for update: UpdateInfo) throws -> URL {
        let baseURL = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        return baseURL
            .appendingPathComponent("AudioRouter", isDirectory: true)
            .appendingPathComponent("Updates", isDirectory: true)
            .appendingPathComponent("AudioRouter-\(update.version)-macOS.zip")
    }

    nonisolated public static func displayVersion(from tag: String) -> String {
        var cleaned = tag.trimmingCharacters(in: .whitespacesAndNewlines)
        if cleaned.lowercased().hasPrefix("v") {
            cleaned.removeFirst()
        }
        return cleaned
    }

    nonisolated public static func isVersion(_ candidate: String, newerThan current: String) -> Bool {
        let lhs = numericVersionParts(candidate)
        let rhs = numericVersionParts(current)
        let count = max(lhs.count, rhs.count)
        for index in 0..<count {
            let left = index < lhs.count ? lhs[index] : 0
            let right = index < rhs.count ? rhs[index] : 0
            if left != right {
                return left > right
            }
        }
        return false
    }

    nonisolated private static func numericVersionParts(_ version: String) -> [Int] {
        let base = displayVersion(from: version)
            .split(whereSeparator: { $0 == "-" || $0 == "+" })
            .first
            .map(String.init) ?? "0"

        return base.split(separator: ".").map { component in
            let digits = component.prefix { $0.isNumber }
            return Int(digits) ?? 0
        }
    }
}

private extension UpdateManager {
    func fetchLatestRelease() async throws -> GitHubRelease {
        var request = URLRequest(url: latestReleaseURL)
        request.timeoutInterval = 12
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("AudioRouter/\(currentVersion)", forHTTPHeaderField: "User-Agent")
        let (data, response) = try await session.data(for: request)
        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            throw UpdateCheckError.badStatus(http.statusCode)
        }
        return try JSONDecoder.releaseDecoder.decode(GitHubRelease.self, from: data)
    }
}

private enum UpdateCheckError: LocalizedError {
    case badStatus(Int)
    case badDownloadStatus(Int)

    var errorDescription: String? {
        switch self {
        case .badStatus(let status):
            return "GitHub returned HTTP \(status). Try again later."
        case .badDownloadStatus(let status):
            return "GitHub download returned HTTP \(status). Try again later."
        }
    }
}

private struct GitHubRelease: Decodable {
    let tagName: String
    let htmlURL: URL
    let publishedAt: Date?
    let body: String?
    let assets: [GitHubAsset]

    enum CodingKeys: String, CodingKey {
        case tagName = "tag_name"
        case htmlURL = "html_url"
        case publishedAt = "published_at"
        case body
        case assets
    }
}

private struct GitHubAsset: Decodable {
    let name: String
    let browserDownloadURL: URL

    enum CodingKeys: String, CodingKey {
        case name
        case browserDownloadURL = "browser_download_url"
    }
}

private extension JSONDecoder {
    static var releaseDecoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let value = try container.decode(String.self)
            if let date = ISO8601DateFormatter.githubDateWithFractionalSeconds.date(from: value)
                ?? ISO8601DateFormatter.githubDate.date(from: value) {
                return date
            }
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Unsupported GitHub release date: \(value)"
            )
        }
        return decoder
    }
}

private extension ISO8601DateFormatter {
    static let githubDate: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    static let githubDateWithFractionalSeconds: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()
}
