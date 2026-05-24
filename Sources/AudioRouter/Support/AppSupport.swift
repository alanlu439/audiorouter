import Foundation

public enum AppSupport {
    public static func fileURL(named filename: String) throws -> URL {
        let base = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let directory = base.appendingPathComponent("AudioRouter", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory.appendingPathComponent(filename)
    }
}

extension Double {
    var clampedUnit: Double {
        max(0, min(1, self))
    }

    var clampedBalance: Double {
        max(-1, min(1, self))
    }
}

extension Date {
    var shortRelativeDescription: String {
        let seconds = abs(timeIntervalSinceNow)
        if seconds < 8 { return "now" }
        if seconds < 60 { return "\(Int(seconds))s ago" }
        if seconds < 3600 { return "\(Int(seconds / 60))m ago" }
        return "\(Int(seconds / 3600))h ago"
    }
}
