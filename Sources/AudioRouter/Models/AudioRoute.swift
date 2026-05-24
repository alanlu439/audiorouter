import Foundation

public enum AudioRouteMode: String, Codable, Hashable {
    case followSystemOutput
    case customOutput
    case unsupported

    public var title: String {
        switch self {
        case .followSystemOutput: return "Follow System Output"
        case .customOutput: return "Custom Output"
        case .unsupported: return "Unsupported"
        }
    }
}

public enum AudioRouteStatus: String, Codable, Hashable {
    case active
    case savedOnly
    case simulated
    case requiresBackend
    case deviceMissing
}

public struct AudioRoute: Identifiable, Hashable {
    public var id: String { sourceAppID }

    public var sourceAppID: String
    public var outputDeviceID: String?
    public var volume: Double
    public var isMuted: Bool
    public var routeMode: AudioRouteMode
    public var status: AudioRouteStatus

    public init(
        sourceAppID: String,
        outputDeviceID: String? = nil,
        volume: Double = 1,
        isMuted: Bool = false,
        routeMode: AudioRouteMode = .followSystemOutput,
        status: AudioRouteStatus = .active
    ) {
        self.sourceAppID = sourceAppID
        self.outputDeviceID = outputDeviceID
        self.volume = volume
        self.isMuted = isMuted
        self.routeMode = routeMode
        self.status = status
    }

    public var sourceID: String {
        get { sourceAppID }
        set { sourceAppID = newValue }
    }
}

extension AudioRoute: Codable {
    private enum CodingKeys: String, CodingKey {
        case sourceAppID
        case sourceID
        case outputDeviceID
        case volume
        case isMuted
        case routeMode
        case status
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let sourceAppID = try container.decodeIfPresent(String.self, forKey: .sourceAppID)
            ?? container.decode(String.self, forKey: .sourceID)
        let modeRawValue = try container.decodeIfPresent(String.self, forKey: .routeMode)
        let normalizedMode: AudioRouteMode
        switch modeRawValue {
        case "followSystem", "followSystemOutput", nil:
            normalizedMode = .followSystemOutput
        case "customDevice", "customOutput":
            normalizedMode = .customOutput
        case "unsupported":
            normalizedMode = .unsupported
        default:
            normalizedMode = .followSystemOutput
        }
        self.init(
            sourceAppID: sourceAppID,
            outputDeviceID: try container.decodeIfPresent(String.self, forKey: .outputDeviceID),
            volume: try container.decodeIfPresent(Double.self, forKey: .volume) ?? 1,
            isMuted: try container.decodeIfPresent(Bool.self, forKey: .isMuted) ?? false,
            routeMode: normalizedMode,
            status: try container.decodeIfPresent(AudioRouteStatus.self, forKey: .status) ?? (normalizedMode == .customOutput ? .requiresBackend : .active)
        )
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(sourceAppID, forKey: .sourceAppID)
        try container.encodeIfPresent(outputDeviceID, forKey: .outputDeviceID)
        try container.encode(volume, forKey: .volume)
        try container.encode(isMuted, forKey: .isMuted)
        try container.encode(routeMode, forKey: .routeMode)
        try container.encode(status, forKey: .status)
    }
}
