import Foundation

public struct AudioSource: Identifiable, Codable, Hashable {
    public let id: String
    public let appName: String
    public let bundleIdentifier: String?
    public let processID: Int32
    public let audioObjectID: UInt32?
    public let icon: String?
    public var isRunning: Bool
    public var isProducingAudio: Bool
    public var lastActiveDate: Date
    public var currentLevel: Double?
    public var volume: Double
    public var isMuted: Bool
    public var routeMode: AudioRouteMode
    public var assignedOutputDeviceID: String?
    public var followsSystemOutput: Bool

    public init(
        id: String,
        appName: String,
        bundleIdentifier: String?,
        processID: Int32,
        audioObjectID: UInt32? = nil,
        icon: String?,
        isRunning: Bool = true,
        isProducingAudio: Bool,
        lastActiveTime: Date = Date(),
        currentLevel: Double? = nil,
        volume: Double = 1,
        isMuted: Bool = false,
        routeMode: AudioRouteMode = .followSystemOutput,
        assignedOutputDeviceID: String? = nil,
        followsSystemOutput: Bool = true
    ) {
        self.id = id
        self.appName = appName
        self.bundleIdentifier = bundleIdentifier
        self.processID = processID
        self.audioObjectID = audioObjectID
        self.icon = icon
        self.isRunning = isRunning
        self.isProducingAudio = isProducingAudio
        self.lastActiveDate = lastActiveTime
        self.currentLevel = currentLevel
        self.volume = volume
        self.isMuted = isMuted
        self.routeMode = routeMode
        self.assignedOutputDeviceID = assignedOutputDeviceID
        self.followsSystemOutput = followsSystemOutput
    }

    public var lastActiveTime: Date {
        get { lastActiveDate }
        set { lastActiveDate = newValue }
    }

    public var activityLabel: String {
        isProducingAudio ? "Live" : "Recent"
    }

    public var debugLabel: String {
        if let bundleIdentifier {
            return "\(bundleIdentifier) · PID \(processID)"
        }
        return "PID \(processID)"
    }
}
