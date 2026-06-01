import Foundation

public protocol AudioRoutingBackend {
    var supportsPerAppRouting: Bool { get }
    var supportsPerAppVolume: Bool { get }
    var supportsPerAppMute: Bool { get }
    var supportsLiveProcessMeters: Bool { get }
    var backendName: String { get }

    func listAudioSources() throws -> [AudioSource]
    func listOutputDevices() throws -> [AudioDevice]
    func routeSourceToDevice(sourceID: String, deviceID: String?) throws
    func routeSourceToDevices(sourceID: String, outputDevices: [AudioDevice]) throws
    func setSourceVolume(sourceID: String, volume: Double) throws
    func muteSource(sourceID: String, muted: Bool) throws
    func currentLevel(sourceID: String) -> Double?
}

public extension AudioRoutingBackend {
    var supportsPerAppVolume: Bool { supportsPerAppRouting }
    var supportsPerAppMute: Bool { supportsPerAppRouting }
    var supportsLiveProcessMeters: Bool { false }
    func currentLevel(sourceID: String) -> Double? { nil }
    func routeSourceToDevices(sourceID: String, outputDevices: [AudioDevice]) throws {
        guard let firstOutput = outputDevices.first else {
            throw AudioRoutingBackendError.unsupported("Add at least one connected output to this group.")
        }
        guard outputDevices.count == 1 else {
            throw AudioRoutingBackendError.unsupported("This backend cannot render one source to multiple outputs.")
        }
        try routeSourceToDevice(sourceID: sourceID, deviceID: firstOutput.uid)
    }
}

public enum AudioRoutingBackendError: LocalizedError, Equatable {
    case unsupported(String)

    public var errorDescription: String? {
        switch self {
        case let .unsupported(message):
            return message
        }
    }
}
