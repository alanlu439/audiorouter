import Foundation

public final class SystemVolumeManager {
    private let deviceManager: AudioDeviceManaging

    public init(deviceManager: AudioDeviceManaging) {
        self.deviceManager = deviceManager
    }

    public func setOutputVolume(device: AudioDevice, volume: Double) throws {
        guard device.canSetVolume else {
            throw AudioRouterError.unsupportedControl("Output volume")
        }
        try deviceManager.setVolume(uid: device.uid, kind: .output, volume: volume)
    }

    public func setInputVolume(device: AudioDevice, volume: Double) throws {
        guard device.canSetVolume else {
            throw AudioRouterError.unsupportedControl("Input volume")
        }
        try deviceManager.setVolume(uid: device.uid, kind: .input, volume: volume)
    }

    public func setMuted(device: AudioDevice, isMuted: Bool) throws {
        guard device.canSetMute else {
            throw AudioRouterError.unsupportedControl("\(device.kind.title) mute")
        }
        try deviceManager.setMuted(uid: device.uid, kind: device.kind, isMuted: isMuted)
    }

    public func setBalance(device: AudioDevice, balance: Double) throws {
        guard device.canSetBalance else {
            throw AudioRouterError.unsupportedControl("\(device.kind.title) balance")
        }
        try deviceManager.setBalance(uid: device.uid, kind: device.kind, balance: balance)
    }
}
