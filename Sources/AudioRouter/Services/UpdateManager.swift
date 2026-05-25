import AppKit
import Foundation

@MainActor
public final class UpdateManager: ObservableObject {
    public struct UpdateInfo: Equatable {
        public let version: String
        public let releaseURL: URL
        public let downloadURL: URL
        public let publishedAt: Date?
        public let body: String?
    }

    @Published public private(set) var isChecking = false
    @Published public private(set) var availableUpdate: UpdateInfo?
    @Published public private(set) var lastCheckedAt: Date?
    @Published public private(set) var message: String = "Updates have not been checked yet."

    private let session: URLSession
    private let currentVersionProvider: () -> String
    private let latestReleaseURL = URL(string: "https://api.github.com/repos/alanlu439/audiorouter/releases/latest")!
    private let latestDownloadURL = URL(string: "https://github.com/alanlu439/audiorouter/releases/latest/download/AudioRouter-macOS.zip")!

    public init(
        session: URLSession = .shared,
        currentVersionProvider: @escaping () -> String = {
            Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.0.0"
        }
    ) {
        self.session = session
        self.currentVersionProvider = currentVersionProvider
    }

    public var currentVersion: String {
        currentVersionProvider()
    }

    public var hasUpdate: Bool {
        availableUpdate != nil
    }

    public func checkForUpdates() {
        guard !isChecking else { return }
        isChecking = true
        message = "Checking for updates..."
        Task {
            await performUpdateCheck()
        }
    }

    public func checkAutomaticallyIfNeeded(enabled: Bool) {
        guard enabled else { return }
        if let lastCheckedAt, abs(lastCheckedAt.timeIntervalSinceNow) < 21_600 {
            return
        }
        checkForUpdates()
    }

    public func openLatestRelease() {
        if let releaseURL = availableUpdate?.releaseURL {
            NSWorkspace.shared.open(releaseURL)
        } else {
            NSWorkspace.shared.open(URL(string: "https://github.com/alanlu439/audiorouter/releases/latest")!)
        }
    }

    public func openLatestDownload() {
        NSWorkspace.shared.open(availableUpdate?.downloadURL ?? latestDownloadURL)
    }

    private func performUpdateCheck() async {
        defer { isChecking = false }
        do {
            var request = URLRequest(url: latestReleaseURL)
            request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
            request.setValue("AudioRouter", forHTTPHeaderField: "User-Agent")
            let (data, response) = try await session.data(for: request)
            if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
                throw URLError(.badServerResponse)
            }
            let release = try JSONDecoder.releaseDecoder.decode(GitHubRelease.self, from: data)
            let latestVersion = release.tagName.trimmingCharacters(in: CharacterSet(charactersIn: "vV"))
            lastCheckedAt = Date()

            if Self.isVersion(latestVersion, newerThan: currentVersion) {
                let assetURL = release.assets.first { $0.name == "AudioRouter-macOS.zip" }?.browserDownloadURL
                    ?? latestDownloadURL
                availableUpdate = UpdateInfo(
                    version: latestVersion,
                    releaseURL: release.htmlURL,
                    downloadURL: assetURL,
                    publishedAt: release.publishedAt,
                    body: release.body
                )
                message = "AudioRouter \(latestVersion) is available."
            } else {
                availableUpdate = nil
                message = "AudioRouter is up to date."
            }
        } catch {
            lastCheckedAt = Date()
            message = "Could not check for updates: \(error.localizedDescription)"
        }
    }

    nonisolated public static func isVersion(_ candidate: String, newerThan current: String) -> Bool {
        let lhs = candidate.split(separator: ".").map { Int($0) ?? 0 }
        let rhs = current.split(separator: ".").map { Int($0) ?? 0 }
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
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}
