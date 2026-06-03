import Foundation

public enum AudioDeviceKind: String, Codable, CaseIterable, Identifiable {
    case output
    case input

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .output: return "Output"
        case .input: return "Input"
        }
    }

    public var systemImage: String {
        switch self {
        case .output: return "speaker.wave.2.fill"
        case .input: return "mic.fill"
        }
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

public struct AudioSampleRateRange: Codable, Hashable {
    public let minimum: Double
    public let maximum: Double

    public init(minimum: Double, maximum: Double) {
        self.minimum = min(minimum, maximum)
        self.maximum = max(minimum, maximum)
    }

    public var isExact: Bool {
        abs(minimum - maximum) < 0.001
    }

    public func contains(_ sampleRate: Double) -> Bool {
        sampleRate >= minimum - 0.001 && sampleRate <= maximum + 0.001
    }

    public func nearestValue(to sampleRate: Double) -> Double {
        min(max(sampleRate, minimum), maximum)
    }
}

public struct AudioDevice: Identifiable, Codable, Hashable {
    public var id: String { "\(kind.rawValue)-\(uid)" }

    public let audioObjectID: UInt32
    public let uid: String
    public let name: String
    public let kind: AudioDeviceKind
    public let channelCount: Int
    public let transport: AudioTransport
    public let isDefault: Bool
    public let isAlive: Bool
    public let volume: Double?
    public let isMuted: Bool?
    public let balance: Double?
    public let sampleRate: Double?
    public let availableSampleRateRanges: [AudioSampleRateRange]?
    public let canSetVolume: Bool
    public let canSetMute: Bool
    public let canSetBalance: Bool

    public init(
        audioObjectID: UInt32,
        uid: String,
        name: String,
        kind: AudioDeviceKind,
        channelCount: Int,
        transport: AudioTransport,
        isDefault: Bool,
        isAlive: Bool,
        volume: Double? = nil,
        isMuted: Bool? = nil,
        balance: Double? = nil,
        sampleRate: Double? = nil,
        availableSampleRateRanges: [AudioSampleRateRange]? = nil,
        canSetVolume: Bool = false,
        canSetMute: Bool = false,
        canSetBalance: Bool = false
    ) {
        self.audioObjectID = audioObjectID
        self.uid = uid
        self.name = name
        self.kind = kind
        self.channelCount = channelCount
        self.transport = transport
        self.isDefault = isDefault
        self.isAlive = isAlive
        self.volume = volume
        self.isMuted = isMuted
        self.balance = balance
        self.sampleRate = sampleRate
        self.availableSampleRateRanges = availableSampleRateRanges
        self.canSetVolume = canSetVolume
        self.canSetMute = canSetMute
        self.canSetBalance = canSetBalance
    }

    public var typeDescription: String {
        "\(transport.rawValue) · \(channelCount) ch"
    }

    public var sampleRateDescription: String {
        guard let sampleRate else { return "Sample rate N/A" }
        return "\(Int(sampleRate.rounded())) Hz"
    }
}
