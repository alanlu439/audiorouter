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
        rebuildSourceCache(from: sources)
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
        try processTapRoutingEngine.startRoute(
            source: routeSource(from: source, canonicalSourceID: sourceID),
            outputDevice: outputDevice
        )
    }

    public func routeSourceToDevices(sourceID: String, outputDevices: [AudioDevice]) throws {
        guard !outputDevices.isEmpty else {
            throw AudioRoutingBackendError.unsupported("Add at least one connected output to this group.")
        }
        let source = try source(for: sourceID)
        try processTapRoutingEngine.startRoute(
            source: routeSource(from: source, canonicalSourceID: sourceID),
            outputDevices: outputDevices
        )
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
        if let source = latestSourcesByID[sourceID], source.audioObjectID != nil {
            return source
        }
        let sources = processMonitor.snapshot().sources
        rebuildSourceCache(from: sources)
        if let source = latestSourcesByID[sourceID], source.audioObjectID != nil {
            return source
        }
        if let source = bestSource(matching: sourceID, in: sources), source.audioObjectID != nil {
            latestSourcesByID[sourceID] = source
            return source
        }
        throw AudioRoutingBackendError.unsupported("AudioRouter cannot see that app's Core Audio process yet. The route was saved and will retry automatically when the process appears.")
    }

    private func rebuildSourceCache(from sources: [AudioSource]) {
        latestSourcesByID.removeAll()
        for source in sources {
            cache(source, for: source.id)
            if let bundleIdentifier = source.bundleIdentifier {
                cache(source, for: bundleIdentifier)
                for alias in helperBundleAliases(for: bundleIdentifier) {
                    cache(source, for: alias)
                }
            }
        }
    }

    private func cache(_ source: AudioSource, for key: String) {
        guard !key.isEmpty else { return }
        if let current = latestSourcesByID[key], sourceScore(source) <= sourceScore(current) {
            return
        }
        latestSourcesByID[key] = source
    }

    private func sourceScore(_ source: AudioSource) -> Int {
        (source.audioObjectID == nil ? 0 : 100)
            + (source.isProducingAudio ? 25 : 0)
            + (source.isRunning ? 5 : 0)
    }

    private func helperBundleAliases(for bundleIdentifier: String) -> [String] {
        let helperMarkers: Set<String> = ["helper", "renderer", "gpu", "plugin", "xpc", "service"]
        let components = bundleIdentifier.split(separator: ".").map(String.init)
        guard let helperIndex = components.firstIndex(where: { helperMarkers.contains($0.lowercased()) }),
              helperIndex >= 3 else {
            return []
        }
        return [components[..<helperIndex].joined(separator: ".")]
    }

    private func bestSource(matching sourceID: String, in sources: [AudioSource]) -> AudioSource? {
        let scoredSources = sources
            .map { source in (source, sourceMatchScore(source, targetID: sourceID)) }
            .filter { $0.1 > 0 }
        return scoredSources.max { lhs, rhs in lhs.1 < rhs.1 }?.0
    }

    private func sourceMatchScore(_ source: AudioSource, targetID: String) -> Int {
        let sourceBundle = source.bundleIdentifier ?? ""
        if source.id == targetID || sourceBundle == targetID {
            return 1_000 + sourceScore(source)
        }
        if source.id.hasPrefix("\(targetID).") || sourceBundle.hasPrefix("\(targetID).") {
            return 900 + sourceScore(source)
        }

        let haystack = [source.id, sourceBundle, source.appName]
            .joined(separator: " ")
            .lowercased()
        let tokenScore = targetTokens(for: targetID)
            .filter { haystack.contains($0) }
            .count * 120
        return tokenScore + (tokenScore > 0 ? sourceScore(source) : 0)
    }

    private func targetTokens(for sourceID: String) -> [String] {
        let ignored: Set<String> = [
            "com", "org", "net", "io", "app", "apps", "client", "helper",
            "renderer", "xpc", "service", "google", "apple", "microsoft"
        ]
        let tokens = sourceID
            .lowercased()
            .split { !$0.isLetter && !$0.isNumber }
            .map(String.init)
            .filter { $0.count > 2 && !ignored.contains($0) }
        return Array(Set(tokens))
    }

    private func routeSource(from source: AudioSource, canonicalSourceID: String) -> AudioSource {
        AudioSource(
            id: canonicalSourceID,
            appName: source.appName,
            bundleIdentifier: source.bundleIdentifier,
            processID: source.processID,
            audioObjectID: source.audioObjectID,
            icon: source.icon,
            isRunning: source.isRunning,
            isProducingAudio: source.isProducingAudio,
            lastActiveTime: source.lastActiveTime,
            currentLevel: source.currentLevel,
            volume: source.volume,
            isMuted: source.isMuted,
            routeMode: source.routeMode,
            assignedOutputDeviceID: source.assignedOutputDeviceID,
            followsSystemOutput: source.followsSystemOutput
        )
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
