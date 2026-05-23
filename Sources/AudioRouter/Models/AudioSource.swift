import Foundation

public struct AudioSource: Identifiable, Codable, Hashable {
    public let id: String
    public let appName: String
    public let bundleIdentifier: String?
    public let processID: Int32
    public let icon: String?
    public var isProducingAudio: Bool
    public var lastActiveTime: Date
    public var volume: Double
    public var isMuted: Bool
    public var assignedOutputDeviceID: String?
    public var followsSystemOutput: Bool

    public init(
        id: String,
        appName: String,
        bundleIdentifier: String?,
        processID: Int32,
        icon: String?,
        isProducingAudio: Bool,
        lastActiveTime: Date = Date(),
        volume: Double = 1,
        isMuted: Bool = false,
        assignedOutputDeviceID: String? = nil,
        followsSystemOutput: Bool = true
    ) {
        self.id = id
        self.appName = appName
        self.bundleIdentifier = bundleIdentifier
        self.processID = processID
        self.icon = icon
        self.isProducingAudio = isProducingAudio
        self.lastActiveTime = lastActiveTime
        self.volume = volume
        self.isMuted = isMuted
        self.assignedOutputDeviceID = assignedOutputDeviceID
        self.followsSystemOutput = followsSystemOutput
    }

    public var activityLabel: String {
        isProducingAudio ? "Live" : "Recent"
    }
}
