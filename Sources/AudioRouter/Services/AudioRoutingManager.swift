import Foundation

public final class AudioRoutingManager {
    public private(set) var lastWarning: String?

    private let backend: AudioRoutingBackend
    private let fileURL: URL
    private var routesBySourceID: [String: AudioRoute] = [:]
    private var recentSourcesByID: [String: AudioSource] = [:]
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
        route.status = backend.supportsPerAppRouting ? .active : .requiresBackend
        routesBySourceID[sourceID] = route
        saveRoutes()

        do {
            try backend.routeSourceToDevice(sourceID: sourceID, deviceID: deviceID)
            lastWarning = nil
        } catch {
            route.status = .requiresBackend
            routesBySourceID[sourceID] = route
            saveRoutes()
            lastWarning = "True per-app routing requires an audio routing backend. AudioRouter saved the route preference."
        }
    }

    public func resetSourceToSystemOutput(sourceID: String) {
        var route = route(for: sourceID)
        route.outputDeviceID = nil
        route.routeMode = .followSystemOutput
        route.status = .active
        routesBySourceID[sourceID] = route
        saveRoutes()
    }

    public func setSourceVolume(sourceID: String, volume: Double) {
        var route = route(for: sourceID)
        route.volume = max(0, min(1.5, volume))
        if !backend.supportsPerAppVolume {
            route.status = route.routeMode == .customOutput ? .requiresBackend : .savedOnly
        }
        routesBySourceID[sourceID] = route
        saveRoutes()

        do {
            try backend.setSourceVolume(sourceID: sourceID, volume: route.volume)
        } catch {
            lastWarning = "Per-app volume is saved, but real per-app gain requires an audio routing backend."
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
            lastWarning = "Per-app mute is saved, but real per-app mute requires an audio routing backend."
        }
    }

    public func restoreSavedRoutes() {
        guard let data = try? Data(contentsOf: fileURL),
              let routes = try? JSONDecoder().decode([AudioRoute].self, from: data) else {
            routesBySourceID = [:]
            return
        }
        routesBySourceID = Dictionary(uniqueKeysWithValues: routes.map { ($0.sourceAppID, $0) })
    }

    public func handleDeviceDisconnected(deviceID: String) {
        let affected = routesBySourceID.values.filter { $0.outputDeviceID == deviceID && $0.routeMode == .customOutput }
        guard !affected.isEmpty else { return }
        for route in affected {
            resetSourceToSystemOutput(sourceID: route.sourceAppID)
        }
        lastWarning = "An assigned output disconnected. Affected sources are following system output."
    }

    public func handleDeviceReconnected(deviceID: String) {
        // TODO: A driver-backed backend could restore parked custom routes when the same device UID returns.
        lastWarning = nil
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

    private func saveRoutes() {
        let routes = Array(routesBySourceID.values).sorted { $0.sourceAppID < $1.sourceAppID }
        if let data = try? JSONEncoder().encode(routes) {
            try? data.write(to: fileURL, options: .atomic)
        }
    }
}
