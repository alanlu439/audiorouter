import Combine
import Foundation

public protocol AudioDeviceManaging {
    func refreshDevices() throws -> [AudioDevice]
    func listOutputDevices() throws -> [AudioOutputDevice]
    func listInputDevices() throws -> [AudioDevice]
    func getDefaultOutputDevice() throws -> AudioOutputDevice?
    func getDefaultInputDevice() throws -> AudioDevice?
    func setDefaultOutputDevice(deviceID: String) throws
    func setDefaultInputDevice(deviceID: String) throws
    func setDefaultDevice(uid: String, kind: AudioDeviceKind) throws
    func getDeviceVolume(deviceID: String) throws -> Double?
    func setVolume(uid: String, kind: AudioDeviceKind, volume: Double) throws
    func setDeviceVolume(deviceID: String, volume: Double) throws
    func getDeviceMute(deviceID: String) throws -> Bool?
    func setMuted(uid: String, kind: AudioDeviceKind, isMuted: Bool) throws
    func setDeviceMute(deviceID: String, muted: Bool) throws
    func getDeviceBalance(deviceID: String) throws -> Double?
    func setBalance(uid: String, kind: AudioDeviceKind, balance: Double) throws
    func setDeviceBalance(deviceID: String, balance: Double) throws
    func observeDeviceChanges(_ onChange: @escaping @Sendable () -> Void) -> DevicePropertyObservation?
}

public final class AudioDeviceService: AudioDeviceManaging {
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

    public func listOutputDevices() throws -> [AudioOutputDevice] {
        try refreshDevices().filter { $0.kind == .output }
    }

    public func listInputDevices() throws -> [AudioDevice] {
        try refreshDevices().filter { $0.kind == .input }
    }

    public func getDefaultOutputDevice() throws -> AudioOutputDevice? {
        try listOutputDevices().first { $0.isDefault }
    }

    public func getDefaultInputDevice() throws -> AudioDevice? {
        try listInputDevices().first { $0.isDefault }
    }

    public func setDefaultOutputDevice(deviceID: String) throws {
        try setDefaultDevice(uid: deviceID, kind: .output)
    }

    public func setDefaultInputDevice(deviceID: String) throws {
        try setDefaultDevice(uid: deviceID, kind: .input)
    }

    public func setDefaultDevice(uid: String, kind: AudioDeviceKind) throws {
        try client.setDefaultDevice(uid: uid, kind: kind)
    }

    public func getDeviceVolume(deviceID: String) throws -> Double? {
        try refreshDevices().first { $0.uid == deviceID }?.volume
    }

    public func setVolume(uid: String, kind: AudioDeviceKind, volume: Double) throws {
        try client.setVolume(uid: uid, kind: kind, volume: volume)
    }

    public func setDeviceVolume(deviceID: String, volume: Double) throws {
        guard let device = try refreshDevices().first(where: { $0.uid == deviceID }) else {
            throw AudioRouterError.missingDevice
        }
        try setVolume(uid: deviceID, kind: device.kind, volume: volume)
    }

    public func getDeviceMute(deviceID: String) throws -> Bool? {
        try refreshDevices().first { $0.uid == deviceID }?.isMuted
    }

    public func setMuted(uid: String, kind: AudioDeviceKind, isMuted: Bool) throws {
        try client.setMuted(uid: uid, kind: kind, isMuted: isMuted)
    }

    public func setDeviceMute(deviceID: String, muted: Bool) throws {
        guard let device = try refreshDevices().first(where: { $0.uid == deviceID }) else {
            throw AudioRouterError.missingDevice
        }
        try setMuted(uid: deviceID, kind: device.kind, isMuted: muted)
    }

    public func getDeviceBalance(deviceID: String) throws -> Double? {
        try refreshDevices().first { $0.uid == deviceID }?.balance
    }

    public func setBalance(uid: String, kind: AudioDeviceKind, balance: Double) throws {
        try client.setBalance(uid: uid, kind: kind, balance: balance)
    }

    public func setDeviceBalance(deviceID: String, balance: Double) throws {
        guard let device = try refreshDevices().first(where: { $0.uid == deviceID }) else {
            throw AudioRouterError.missingDevice
        }
        try setBalance(uid: deviceID, kind: device.kind, balance: balance)
    }

    public func observeDeviceChanges(_ onChange: @escaping @Sendable () -> Void) -> DevicePropertyObservation? {
        try? DevicePropertyObserver(onChange: onChange).start()
    }
}

public final class AudioDeviceManager: AudioDeviceManaging {
    private let service: AudioDeviceService

    public convenience init() {
        self.init(client: CoreAudioClient())
    }

    init(client: CoreAudioClient) {
        self.service = AudioDeviceService(client: client)
    }

    public func refreshDevices() throws -> [AudioDevice] { try service.refreshDevices() }
    public func listOutputDevices() throws -> [AudioOutputDevice] { try service.listOutputDevices() }
    public func listInputDevices() throws -> [AudioDevice] { try service.listInputDevices() }
    public func getDefaultOutputDevice() throws -> AudioOutputDevice? { try service.getDefaultOutputDevice() }
    public func getDefaultInputDevice() throws -> AudioDevice? { try service.getDefaultInputDevice() }
    public func setDefaultOutputDevice(deviceID: String) throws { try service.setDefaultOutputDevice(deviceID: deviceID) }
    public func setDefaultInputDevice(deviceID: String) throws { try service.setDefaultInputDevice(deviceID: deviceID) }
    public func setDefaultDevice(uid: String, kind: AudioDeviceKind) throws { try service.setDefaultDevice(uid: uid, kind: kind) }
    public func getDeviceVolume(deviceID: String) throws -> Double? { try service.getDeviceVolume(deviceID: deviceID) }
    public func setVolume(uid: String, kind: AudioDeviceKind, volume: Double) throws { try service.setVolume(uid: uid, kind: kind, volume: volume) }
    public func setDeviceVolume(deviceID: String, volume: Double) throws { try service.setDeviceVolume(deviceID: deviceID, volume: volume) }
    public func getDeviceMute(deviceID: String) throws -> Bool? { try service.getDeviceMute(deviceID: deviceID) }
    public func setMuted(uid: String, kind: AudioDeviceKind, isMuted: Bool) throws { try service.setMuted(uid: uid, kind: kind, isMuted: isMuted) }
    public func setDeviceMute(deviceID: String, muted: Bool) throws { try service.setDeviceMute(deviceID: deviceID, muted: muted) }
    public func getDeviceBalance(deviceID: String) throws -> Double? { try service.getDeviceBalance(deviceID: deviceID) }
    public func setBalance(uid: String, kind: AudioDeviceKind, balance: Double) throws { try service.setBalance(uid: uid, kind: kind, balance: balance) }
    public func setDeviceBalance(deviceID: String, balance: Double) throws { try service.setDeviceBalance(deviceID: deviceID, balance: balance) }
    public func observeDeviceChanges(_ onChange: @escaping @Sendable () -> Void) -> DevicePropertyObservation? {
        service.observeDeviceChanges(onChange)
    }
}
