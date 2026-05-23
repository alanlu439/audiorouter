import Combine
import Foundation

public protocol AudioDeviceManaging {
    func refreshDevices() throws -> [AudioDevice]
    func setDefaultDevice(uid: String, kind: AudioDeviceKind) throws
    func setVolume(uid: String, kind: AudioDeviceKind, volume: Double) throws
    func setMuted(uid: String, kind: AudioDeviceKind, isMuted: Bool) throws
    func setBalance(uid: String, kind: AudioDeviceKind, balance: Double) throws
}

public final class AudioDeviceManager: AudioDeviceManaging {
    private let client: CoreAudioClient

    public convenience init() {
        self.init(client: CoreAudioClient())
    }

    init(client: CoreAudioClient) {
        self.client = client
    }

    public func refreshDevices() throws -> [AudioDevice] {
        try client.devices()
    }

    public func setDefaultDevice(uid: String, kind: AudioDeviceKind) throws {
        try client.setDefaultDevice(uid: uid, kind: kind)
    }

    public func setVolume(uid: String, kind: AudioDeviceKind, volume: Double) throws {
        try client.setVolume(uid: uid, kind: kind, volume: volume)
    }

    public func setMuted(uid: String, kind: AudioDeviceKind, isMuted: Bool) throws {
        try client.setMuted(uid: uid, kind: kind, isMuted: isMuted)
    }

    public func setBalance(uid: String, kind: AudioDeviceKind, balance: Double) throws {
        try client.setBalance(uid: uid, kind: kind, balance: balance)
    }
}
