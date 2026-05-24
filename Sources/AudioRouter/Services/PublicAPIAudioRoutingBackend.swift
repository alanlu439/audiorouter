import AppKit
import Foundation

public final class PublicAPIAudioRoutingBackend: AudioRoutingBackend {
    public var supportsPerAppRouting: Bool { processTapRoutingEngine.isSupportedOnThisOS }
    public var supportsPerAppVolume: Bool { processTapRoutingEngine.isSupportedOnThisOS }
    public var supportsPerAppMute: Bool { processTapRoutingEngine.isSupportedOnThisOS }
    public var supportsLiveProcessMeters: Bool { processTapRoutingEngine.isSupportedOnThisOS }
    public let backendName = "Public Core Audio process taps"

    private let client: CoreAudioClient
    private let processMonitor: ProcessAudioMonitor
    private let processTapRoutingEngine: ProcessTapRoutingEngine
    private var latestSourcesByID: [String: AudioSource] = [:]
    private var latestOutputsByUID: [String: AudioDevice] = [:]

    public convenience init() {
        self.init(
            client: CoreAudioClient(),
            processMonitor: ProcessAudioMonitor(),
            processTapRoutingEngine: ProcessTapRoutingEngine()
        )
    }

    init(
        client: CoreAudioClient,
        processMonitor: ProcessAudioMonitor = ProcessAudioMonitor(),
        processTapRoutingEngine: ProcessTapRoutingEngine = ProcessTapRoutingEngine()
    ) {
        self.client = client
        self.processMonitor = processMonitor
        self.processTapRoutingEngine = processTapRoutingEngine
    }

    public func listAudioSources() throws -> [AudioSource] {
        let sources = processMonitor.snapshot().sources
        latestSourcesByID = Dictionary(sources.map { ($0.id, $0) }, uniquingKeysWith: { current, replacement in
            replacement.isProducingAudio ? replacement : current
        })
        return sources
    }

    public func listOutputDevices() throws -> [AudioDevice] {
        let outputs = try client.devices().filter { $0.kind == .output }
        latestOutputsByUID = Dictionary(outputs.map { ($0.uid, $0) }, uniquingKeysWith: { current, replacement in
            replacement.isDefault ? replacement : current
        })
        return outputs
    }

    public func routeSourceToDevice(sourceID: String, deviceID: String?) throws {
        guard let deviceID else {
            processTapRoutingEngine.stopRoute(sourceID: sourceID)
            return
        }

        let source = try source(for: sourceID)
        let outputDevice = try outputDevice(for: deviceID)
        try processTapRoutingEngine.startRoute(source: source, outputDevice: outputDevice)
    }

    public func setSourceVolume(sourceID: String, volume: Double) throws {
        processTapRoutingEngine.setVolume(sourceID: sourceID, volume: volume)
    }

    public func muteSource(sourceID: String, muted: Bool) throws {
        processTapRoutingEngine.setMuted(sourceID: sourceID, muted: muted)
    }

    public func currentLevel(sourceID: String) -> Double? {
        processTapRoutingEngine.currentLevel(sourceID: sourceID)
    }

    private func source(for sourceID: String) throws -> AudioSource {
        if let source = latestSourcesByID[sourceID] {
            return source
        }
        let sources = processMonitor.snapshot().sources
        latestSourcesByID = Dictionary(sources.map { ($0.id, $0) }, uniquingKeysWith: { current, replacement in
            replacement.isProducingAudio ? replacement : current
        })
        if let source = latestSourcesByID[sourceID] {
            return source
        }
        throw AudioRoutingBackendError.unsupported("Start playback in the selected app, refresh AudioRouter, then assign the output again.")
    }

    private func outputDevice(for deviceID: String) throws -> AudioDevice {
        if let output = latestOutputsByUID[deviceID] {
            return output
        }
        let outputs = try client.devices().filter { $0.kind == .output }
        latestOutputsByUID = Dictionary(outputs.map { ($0.uid, $0) }, uniquingKeysWith: { current, replacement in
            replacement.isDefault ? replacement : current
        })
        guard let output = latestOutputsByUID[deviceID] else {
            throw AudioRouterError.missingDevice
        }
        return output
    }
}
