import Foundation

public struct RouteRule: Identifiable, Codable, Hashable {
    public var id: UUID
    public var processObjectID: UInt32?
    public var pid: Int32?
    public var bundleID: String?
    public var processDisplayName: String
    public var deviceUID: String?
    public var deviceName: String
    public var isEnabled: Bool
    public var muteOriginal: Bool
    public var volume: Double
    public var status: RouteStatus
    public var lastError: String?

    public init(
        id: UUID = UUID(),
        process: AudioProcessInfo,
        device: AudioDeviceInfo,
        isEnabled: Bool = false,
        muteOriginal: Bool = true,
        volume: Double = 1
    ) {
        self.id = id
        self.processObjectID = process.processObjectID
        self.pid = process.pid
        self.bundleID = process.bundleID
        self.processDisplayName = process.displayName
        self.deviceUID = device.uid
        self.deviceName = device.name
        self.isEnabled = isEnabled
        self.muteOriginal = muteOriginal
        self.volume = volume
        self.status = .ready
        self.lastError = nil
    }

    public init(
        id: UUID = UUID(),
        application: AppSoundSource,
        device: AudioDeviceInfo,
        isEnabled: Bool = false,
        muteOriginal: Bool = true,
        volume: Double = 1
    ) {
        self.id = id
        self.processObjectID = application.processObjectID
        self.pid = application.pid
        self.bundleID = application.bundleID
        self.processDisplayName = application.displayName
        self.deviceUID = device.uid
        self.deviceName = device.name
        self.isEnabled = isEnabled
        self.muteOriginal = muteOriginal
        self.volume = volume
        self.status = .ready
        self.lastError = nil
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case processObjectID
        case pid
        case bundleID
        case processDisplayName
        case deviceUID
        case deviceName
        case isEnabled
        case muteOriginal
        case volume
        case status
        case lastError
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        processObjectID = try container.decodeIfPresent(UInt32.self, forKey: .processObjectID)
        pid = try container.decodeIfPresent(Int32.self, forKey: .pid)
        bundleID = try container.decodeIfPresent(String.self, forKey: .bundleID)
        processDisplayName = try container.decode(String.self, forKey: .processDisplayName)
        deviceUID = try container.decodeIfPresent(String.self, forKey: .deviceUID)
        deviceName = try container.decode(String.self, forKey: .deviceName)
        isEnabled = try container.decode(Bool.self, forKey: .isEnabled)
        muteOriginal = try container.decode(Bool.self, forKey: .muteOriginal)
        volume = try container.decodeIfPresent(Double.self, forKey: .volume) ?? 1
        status = try container.decode(RouteStatus.self, forKey: .status)
        lastError = try container.decodeIfPresent(String.self, forKey: .lastError)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encodeIfPresent(processObjectID, forKey: .processObjectID)
        try container.encodeIfPresent(pid, forKey: .pid)
        try container.encodeIfPresent(bundleID, forKey: .bundleID)
        try container.encode(processDisplayName, forKey: .processDisplayName)
        try container.encodeIfPresent(deviceUID, forKey: .deviceUID)
        try container.encode(deviceName, forKey: .deviceName)
        try container.encode(isEnabled, forKey: .isEnabled)
        try container.encode(muteOriginal, forKey: .muteOriginal)
        try container.encode(volume, forKey: .volume)
        try container.encode(status, forKey: .status)
        try container.encodeIfPresent(lastError, forKey: .lastError)
    }
}

public enum RouteStatus: String, Codable, CaseIterable {
    case ready = "Ready"
    case running = "Running"
    case stopped = "Stopped"
    case unavailable = "Unavailable"
    case failed = "Failed"

    var systemImage: String {
        switch self {
        case .ready:
            return "checkmark.circle"
        case .running:
            return "waveform.circle.fill"
        case .stopped:
            return "stop.circle"
        case .unavailable:
            return "exclamationmark.triangle"
        case .failed:
            return "xmark.octagon"
        }
    }
}
