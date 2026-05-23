import Foundation

public struct AudioDeviceInfo: Identifiable, Codable, Hashable {
    public var id: String { uid }

    public let audioObjectID: UInt32
    public let uid: String
    public let name: String
    public let outputChannelCount: Int
    public let transport: AudioTransport
    public let isDefaultOutput: Bool
    public let isAlive: Bool
    public let outputVolume: Double?
    public let isMuted: Bool?
    public let canSetVolume: Bool
    public let canSetMute: Bool

    public init(
        audioObjectID: UInt32,
        uid: String,
        name: String,
        outputChannelCount: Int,
        transport: AudioTransport,
        isDefaultOutput: Bool,
        isAlive: Bool,
        outputVolume: Double? = nil,
        isMuted: Bool? = nil,
        canSetVolume: Bool = false,
        canSetMute: Bool = false
    ) {
        self.audioObjectID = audioObjectID
        self.uid = uid
        self.name = name
        self.outputChannelCount = outputChannelCount
        self.transport = transport
        self.isDefaultOutput = isDefaultOutput
        self.isAlive = isAlive
        self.outputVolume = outputVolume
        self.isMuted = isMuted
        self.canSetVolume = canSetVolume
        self.canSetMute = canSetMute
    }

    public var isRoutableOutput: Bool {
        isAlive && outputChannelCount > 0
    }
}

public enum AudioTransport: String, Codable, CaseIterable {
    case builtIn = "Built In"
    case bluetooth = "Bluetooth"
    case bluetoothLE = "Bluetooth LE"
    case usb = "USB"
    case hdmi = "HDMI"
    case displayPort = "DisplayPort"
    case airPlay = "AirPlay"
    case aggregate = "Aggregate"
    case virtual = "Virtual"
    case thunderbolt = "Thunderbolt"
    case unknown = "Unknown"
}
