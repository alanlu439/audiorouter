import Foundation

public final class AudioRoutingManager {
    public private(set) var lastWarning: String?

    private let backend: AudioRoutingBackend
    private let fileURL: URL
    private var routesBySourceID: [String: AudioRoute] = [:]
    private var recentSourcesByID: [String: AudioSource] = [:]
    private var routeMessagesBySourceID: [String: String] = [:]
    private let recentWindow: TimeInterval = 120

    public convenience init() {
        self.init(
            backend: PublicAPIAudioRoutingBackend(),
            fileURL: try! AppSupport.fileURL(named: "audio-routes.json")
        )
    }

    public init(backend: AudioRoutingBackend, fileURL: URL) {
        self.backend = backend
        self.fileURL = fileURL
        restoreSavedRoutes()
    }

    public var supportsTruePerAppRouting: Bool {
        backend.supportsPerAppRouting
    }

    public var supportsPerAppVolume: Bool {
        backend.supportsPerAppVolume
    }

    public var supportsPerAppMute: Bool {
        backend.supportsPerAppMute
    }

    public var supportsLiveProcessMeters: Bool {
        backend.supportsLiveProcessMeters
    }

    public var backendName: String {
        backend.backendName
    }

    public func getActiveAudioSources() -> [AudioSource] {
        let now = Date()
        let detected = (try? backend.listAudioSources()) ?? []
        for source in detected {
            var merged = source
            let route = routesBySourceID[source.id] ?? AudioRoute(sourceAppID: source.id)
            merged.volume = route.volume
            merged.isMuted = route.isMuted
            merged.assignedOutputDeviceID = route.outputDeviceID
            merged.routeMode = route.routeMode
            merged.followsSystemOutput = route.routeMode == .followSystemOutput
            if let level = backend.currentLevel(sourceID: source.id) {
                merged.currentLevel = level
                merged.isProducingAudio = level > 0.015 || merged.isProducingAudio
            }
            merged.lastActiveTime = now
            recentSourcesByID[source.id] = merged
        }

        let cutoff = now.addingTimeInterval(-recentWindow)
        recentSourcesByID = recentSourcesByID.filter { $0.value.lastActiveTime >= cutoff }
        return recentSourcesByID.values.sorted {
            if $0.isProducingAudio != $1.isProducingAudio {
                return $0.isProducingAudio
            }
            return $0.appName.localizedCaseInsensitiveCompare($1.appName) == .orderedAscending
        }
    }

    public func getAvailableOutputDevices() -> [AudioDevice] {
        (try? backend.listOutputDevices()) ?? []
    }

    public func assignOutputDevice(sourceID: String, deviceID: String) {
        var route = route(for: sourceID)
        route.outputDeviceID = deviceID
        route.routeMode = .customOutput
        route.status = backend.supportsPerAppRouting ? .savedOnly : .requiresBackend
        routesBySourceID[sourceID] = route
        saveRoutes()

        do {
            try backend.routeSourceToDevice(sourceID: sourceID, deviceID: deviceID)
            route.status = backend.supportsPerAppRouting ? .active : .requiresBackend
            routesBySourceID[sourceID] = route
            saveRoutes()
            routeMessagesBySourceID[sourceID] = backend.supportsPerAppRouting
                ? "Route is live."
                : "This backend cannot render app audio to a separate output."
            lastWarning = nil
        } catch {
            route.status = .requiresBackend
            routesBySourceID[sourceID] = route
            saveRoutes()
            let message = "\(error.localizedDescription) AudioRouter saved the route preference."
            routeMessagesBySourceID[sourceID] = message
            lastWarning = message
        }
    }

    public func retryRoute(sourceID: String) {
        let route = route(for: sourceID)
        guard route.routeMode == .customOutput, let outputDeviceID = route.outputDeviceID else {
            routeMessagesBySourceID[sourceID] = "Choose a custom output before retrying this route."
            return
        }
        assignOutputDevice(sourceID: sourceID, deviceID: outputDeviceID)
    }

    public func resetSourceToSystemOutput(sourceID: String) {
        try? backend.routeSourceToDevice(sourceID: sourceID, deviceID: nil)
        var route = route(for: sourceID)
        route.outputDeviceID = nil
        route.routeMode = .followSystemOutput
        route.status = .active
        routesBySourceID[sourceID] = route
        routeMessagesBySourceID[sourceID] = "Source follows the current system output."
        saveRoutes()
    }

    public func setSourceVolume(sourceID: String, volume: Double, persist: Bool = true) {
        var route = route(for: sourceID)
        route.volume = max(0, min(1.5, volume))
        if !backend.supportsPerAppVolume {
            route.status = route.routeMode == .customOutput ? .requiresBackend : .savedOnly
        }
        routesBySourceID[sourceID] = route
        if persist {
            saveRoutes()
        }

        do {
            try backend.setSourceVolume(sourceID: sourceID, volume: route.volume)
        } catch {
            lastWarning = "\(error.localizedDescription) AudioRouter saved the volume preference."
        }
    }

    public func muteSource(sourceID: String, muted: Bool) {
        var route = route(for: sourceID)
        route.isMuted = muted
        if !backend.supportsPerAppMute {
            route.status = route.routeMode == .customOutput ? .requiresBackend : .savedOnly
        }
        routesBySourceID[sourceID] = route
        saveRoutes()

        do {
            try backend.muteSource(sourceID: sourceID, muted: muted)
        } catch {
            lastWarning = "\(error.localizedDescription) AudioRouter saved the mute preference."
        }
    }

    public func restoreSavedRoutes() {
        guard let data = try? Data(contentsOf: fileURL),
              let routes = try? JSONDecoder().decode([AudioRoute].self, from: data) else {
            routesBySourceID = [:]
            return
        }
        routesBySourceID = Dictionary(routes.map { route in
            var restored = route
            if restored.routeMode == .customOutput {
                restored.status = .savedOnly
            }
            return (restored.sourceAppID, restored)
        }, uniquingKeysWith: { _, newest in newest })
    }

    public func handleDeviceDisconnected(deviceID: String) {
        let affected = routesBySourceID.values.filter { $0.outputDeviceID == deviceID && $0.routeMode == .customOutput }
        guard !affected.isEmpty else { return }
        for route in affected {
            var updated = route
            updated.status = .deviceMissing
            routesBySourceID[route.sourceAppID] = updated
            routeMessagesBySourceID[route.sourceAppID] = "Assigned output is missing. AudioRouter kept the route saved and will not stop other audio during device changes."
        }
        saveRoutes()
        lastWarning = "An assigned output disappeared. AudioRouter kept the route saved instead of resetting it during the device change."
    }

    public func handleDeviceReconnected(deviceID: String) {
        let affected = routesBySourceID.values.filter { $0.outputDeviceID == deviceID && $0.status == .deviceMissing }
        for route in affected {
            var updated = route
            updated.status = .savedOnly
            routesBySourceID[route.sourceAppID] = updated
            routeMessagesBySourceID[route.sourceAppID] = "Assigned output reconnected. Press Retry Route when the source is playing."
        }
        if !affected.isEmpty {
            saveRoutes()
        }
        lastWarning = nil
    }

    public func hasDeviceMissingRoute(forDeviceID deviceID: String) -> Bool {
        routesBySourceID.values.contains { route in
            route.outputDeviceID == deviceID && route.status == .deviceMissing
        }
    }

    public func route(for sourceID: String) -> AudioRoute {
        routesBySourceID[sourceID] ?? AudioRoute(sourceAppID: sourceID)
    }

    public func deviceName(for route: AudioRoute, outputs: [AudioDevice]) -> String {
        guard route.routeMode == .customOutput, let outputDeviceID = route.outputDeviceID else {
            return "Follow System Output"
        }
        return outputs.first(where: { $0.uid == outputDeviceID })?.name ?? "Missing Output"
    }

    public func currentLevel(for sourceID: String) -> Double? {
        backend.currentLevel(sourceID: sourceID)
    }

    public func routeMessage(for sourceID: String) -> String? {
        routeMessagesBySourceID[sourceID]
    }

    private func saveRoutes() {
        let routes = Array(routesBySourceID.values).sorted { $0.sourceAppID < $1.sourceAppID }
        if let data = try? JSONEncoder().encode(routes) {
            try? data.write(to: fileURL, options: .atomic)
        }
    }
}
