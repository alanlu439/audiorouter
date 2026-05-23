import Foundation

public enum AudioRouteMode: String, Codable, Hashable {
    case followSystem
    case customDevice

    public var title: String {
        switch self {
        case .followSystem: return "Follow System Output"
        case .customDevice: return "Custom Device"
        }
    }
}

public struct AudioRoute: Identifiable, Codable, Hashable {
    public var id: String { sourceAppID }

    public var sourceAppID: String
    public var outputDeviceID: String?
    public var volume: Double
    public var isMuted: Bool
    public var routeMode: AudioRouteMode

    public init(
        sourceAppID: String,
        outputDeviceID: String? = nil,
        volume: Double = 1,
        isMuted: Bool = false,
        routeMode: AudioRouteMode = .followSystem
    ) {
        self.sourceAppID = sourceAppID
        self.outputDeviceID = outputDeviceID
        self.volume = volume
        self.isMuted = isMuted
        self.routeMode = routeMode
    }
}
