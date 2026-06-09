import AppKit
import Foundation

enum AppIconResolver {
    static func icon(for source: AudioSource) -> NSImage? {
        guard let url = applicationURL(bundleIdentifier: source.bundleIdentifier, fallbackPath: source.icon) else {
            return nil
        }
        return NSWorkspace.shared.icon(forFile: url.path)
    }

    static func applicationPath(bundleIdentifier: String?, fallbackPath: String?) -> String? {
        applicationURL(bundleIdentifier: bundleIdentifier, fallbackPath: fallbackPath)?.path
    }

    static func applicationURL(bundleIdentifier: String?, fallbackPath: String?) -> URL? {
        if let bundleIdentifier = bundleIdentifier?.trimmingCharacters(in: .whitespacesAndNewlines),
           !bundleIdentifier.isEmpty,
           let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier) {
            return url
        }

        if let fallbackPath = fallbackPath?.trimmingCharacters(in: .whitespacesAndNewlines),
           !fallbackPath.isEmpty {
            let url = URL(fileURLWithPath: fallbackPath)
            if FileManager.default.fileExists(atPath: url.path) {
                return url
            }
        }

        return nil
    }
}
