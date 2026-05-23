import Foundation

public protocol AudioRoutingServicing {
    func loadDevices() throws -> [AudioDeviceInfo]
    func loadProcesses() throws -> [AudioProcessInfo]
    func loadApplications(audioProcesses: [AudioProcessInfo]) throws -> [AppSoundSource]
    func setDefaultOutput(deviceUID: String) throws
    func setDeviceVolume(deviceUID: String, volume: Double) throws
    func setDeviceMuted(deviceUID: String, isMuted: Bool) throws
    func start(route: RouteRule, process: AudioProcessInfo, device: AudioDeviceInfo) throws
    func setVolume(routeID: UUID, volume: Double)
    func stop(routeID: UUID)
    func stopAll()
    var activeRouteIDs: Set<UUID> { get }
    var routeLevels: [UUID: Float] { get }
}

public enum AudioRoutingError: LocalizedError {
    case unsupportedSystem
    case missingProcess
    case missingDevice
    case coreAudio(String, Int32)
    case routeAlreadyRunning

    public var errorDescription: String? {
        switch self {
        case .unsupportedSystem:
            return "macOS 14.2 or newer is required for CoreAudio process taps."
        case .missingProcess:
            return "The selected process is no longer available."
        case .missingDevice:
            return "The selected output device is no longer available."
        case let .coreAudio(operation, status):
            return "\(operation) failed with OSStatus \(status)."
        case .routeAlreadyRunning:
            return "This route is already running."
        }
    }
}

public final class AudioRoutingService: AudioRoutingServicing {
    private let hardware: CoreAudioHardwareClient
    private let routeEngine: CoreAudioRouteEngine
    private let applicationCatalog: ApplicationCatalogService

    public convenience init() {
        self.init(
            hardware: CoreAudioHardwareClient(),
            routeEngine: CoreAudioRouteEngine(),
            applicationCatalog: ApplicationCatalogService()
        )
    }

    init(
        hardware: CoreAudioHardwareClient,
        routeEngine: CoreAudioRouteEngine,
        applicationCatalog: ApplicationCatalogService
    ) {
        self.hardware = hardware
        self.routeEngine = routeEngine
        self.applicationCatalog = applicationCatalog
    }

    public var activeRouteIDs: Set<UUID> {
        routeEngine.activeRouteIDs
    }

    public var routeLevels: [UUID: Float] {
        routeEngine.routeLevels
    }

    public func loadDevices() throws -> [AudioDeviceInfo] {
        try hardware.outputDevices()
    }

    public func loadProcesses() throws -> [AudioProcessInfo] {
        try hardware.audioProcesses()
    }

    public func loadApplications(audioProcesses: [AudioProcessInfo]) throws -> [AppSoundSource] {
        applicationCatalog.availableApplications(audioProcesses: audioProcesses)
    }

    public func setDefaultOutput(deviceUID: String) throws {
        try hardware.setDefaultOutput(deviceUID: deviceUID)
    }

    public func setDeviceVolume(deviceUID: String, volume: Double) throws {
        try hardware.setOutputVolume(deviceUID: deviceUID, volume: volume)
    }

    public func setDeviceMuted(deviceUID: String, isMuted: Bool) throws {
        try hardware.setMuted(deviceUID: deviceUID, isMuted: isMuted)
    }

    public func start(route: RouteRule, process: AudioProcessInfo, device: AudioDeviceInfo) throws {
        try routeEngine.start(route: route, process: process, device: device)
    }

    public func setVolume(routeID: UUID, volume: Double) {
        routeEngine.setVolume(routeID: routeID, volume: volume)
    }

    public func stop(routeID: UUID) {
        routeEngine.stop(routeID: routeID)
    }

    public func stopAll() {
        routeEngine.stopAll()
    }
}
