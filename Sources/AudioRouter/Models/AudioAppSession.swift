import Foundation

public struct AudioAppSession: Identifiable, Codable, Hashable {
    public let id: String
    public let pid: Int32
    public let bundleID: String?
    public let displayName: String
    public let iconPath: String?
    public var isProducingAudio: Bool
    public var lastActivity: Date
    public var volume: Double
    public var isMuted: Bool
    public var assignedOutputUID: String?

    public init(
        id: String,
        pid: Int32,
        bundleID: String?,
        displayName: String,
        iconPath: String?,
        isProducingAudio: Bool,
        lastActivity: Date = Date(),
        volume: Double = 1,
        isMuted: Bool = false,
        assignedOutputUID: String? = nil
    ) {
        self.id = id
        self.pid = pid
        self.bundleID = bundleID
        self.displayName = displayName
        self.iconPath = iconPath
        self.isProducingAudio = isProducingAudio
        self.lastActivity = lastActivity
        self.volume = volume
        self.isMuted = isMuted
        self.assignedOutputUID = assignedOutputUID
    }

    public var activityLabel: String {
        isProducingAudio ? "Live" : "Recent"
    }
}
