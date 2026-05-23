import AudioRouter
import Foundation

@MainActor
func runChecks() throws {
    try checkRoutePersistenceRoundTrip()
    checkRouteResolverBundleFallback()
    checkRouteResolverMarksUnavailable()
    checkStoreRouteVolume()
    checkStoreDeviceVolumeOptimisticUpdate()
    checkOutputGroupPersistence()
    checkStoreConnectsMultipleInputsToOutputs()
    checkStoreRetriesEnabledRouteAfterRefresh()
    checkStoreStopAll()
}

func checkRoutePersistenceRoundTrip() throws {
    let fileURL = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString)
        .appendingPathComponent("routes.json")
    let persistence = RoutePersistence(fileURL: fileURL)
    let route = RouteRule(
        process: sampleProcess(id: 42, pid: 1234, bundleID: "com.example.Player", name: "Player"),
        device: sampleDevice(uid: "device-9", name: "Headphones"),
        isEnabled: true,
        muteOriginal: true
    )

    try persistence.saveRoutes([route])
    let loaded = try persistence.loadRoutes()

    precondition(loaded == [route], "RoutePersistence failed to round-trip routes")
}

func checkRouteResolverBundleFallback() {
    let device = sampleDevice(uid: "speaker", name: "Speaker")
    let oldProcess = sampleProcess(id: 10, pid: 111, bundleID: "com.example.Music", name: "Music")
    let newProcess = sampleProcess(id: 99, pid: 222, bundleID: "com.example.Music", name: "Music")
    var route = RouteRule(process: oldProcess, device: device)
    route.isEnabled = true

    let updated = RouteResolver.updatedRoutes(
        [route],
        devices: [device],
        processes: [newProcess],
        activeRouteIDs: []
    )

    precondition(updated.first?.processObjectID == 99, "RouteResolver did not restore by bundle id")
    precondition(updated.first?.status == .ready, "RouteResolver did not mark restored route ready")
}

func checkRouteResolverMarksUnavailable() {
    let route = RouteRule(
        process: sampleProcess(id: 10, pid: 111, bundleID: "com.example.Music", name: "Music"),
        device: sampleDevice(uid: "speaker", name: "Speaker")
    )

    let updated = RouteResolver.updatedRoutes(
        [route],
        devices: [],
        processes: [sampleProcess(id: 10, pid: 111, bundleID: "com.example.Music", name: "Music")],
        activeRouteIDs: []
    )

    precondition(updated.first?.status == .unavailable, "RouteResolver did not mark missing device unavailable")
}

@MainActor
func checkStoreRouteVolume() {
    let service = FakeRoutingService()
    let persistence = InMemoryPersistence()
    let store = AudioRouterStore(routingService: service, persistence: persistence)
    let process = service.processes[0]
    let device = service.devices[0]

    store.addRoute(process: process, device: device, muteOriginal: true)
    guard let route = store.routes.first else {
        preconditionFailure("Expected store to add a route")
    }

    store.setRouteVolume(route, volume: 1.25)

    precondition(store.routes.first?.volume == 1.25, "Store did not update route volume")
    precondition(service.routeVolumes[route.id] == 1.25, "Store did not forward route volume to service")
    store.stopAllRoutes()
    precondition(persistence.routes.first?.volume == 1.25, "Store did not persist route volume")
}

@MainActor
func checkStoreDeviceVolumeOptimisticUpdate() {
    let service = FakeRoutingService()
    service.devices = [
        sampleDevice(uid: "speaker", name: "Speaker", outputVolume: 0.4, canSetVolume: true)
    ]
    let persistence = InMemoryPersistence()
    let store = AudioRouterStore(routingService: service, persistence: persistence)
    store.refresh()

    guard let device = store.devices.first else {
        preconditionFailure("Expected device")
    }
    store.setDeviceVolume(device, volume: 0.72)

    precondition(store.devices.first?.outputVolume == 0.72, "Store did not optimistically update device volume")
    precondition(service.deviceVolumes["speaker"] == 0.72, "Store did not forward device volume to service")
}

@MainActor
func checkOutputGroupPersistence() {
    let service = FakeRoutingService()
    service.devices = [
        sampleDevice(uid: "speaker-a", name: "Speaker A"),
        sampleDevice(uid: "speaker-b", name: "Speaker B")
    ]
    let persistence = InMemoryPersistence()
    let store = AudioRouterStore(routingService: service, persistence: persistence)
    store.refresh()
    store.createOutputGroup(name: "Desk", deviceUIDs: ["speaker-a", "speaker-b"])

    precondition(store.outputGroups.count == 1, "Store did not create an output group")
    precondition(persistence.groups.first?.deviceUIDs == ["speaker-a", "speaker-b"], "Store did not persist output group devices")
}

@MainActor
func checkStoreConnectsMultipleInputsToOutputs() {
    let service = FakeRoutingService()
    service.devices = [
        sampleDevice(uid: "speaker-a", name: "Speaker A"),
        sampleDevice(uid: "speaker-b", name: "Speaker B")
    ]
    service.processes = [
        sampleProcess(id: 2, pid: 123, bundleID: "com.example.PlayerA", name: "Player A"),
        sampleProcess(id: 3, pid: 456, bundleID: "com.example.PlayerB", name: "Player B")
    ]
    let persistence = InMemoryPersistence()
    let store = AudioRouterStore(routingService: service, persistence: persistence)
    store.refresh()

    store.connect(
        applications: service.processes.map(AppSoundSource.init(process:)),
        devices: service.devices
    )

    precondition(store.routes.count == 4, "Store did not create one route per input-output pair")
    precondition(service.activeRouteIDs.count == 4, "Store did not start every input-output route")
    precondition(Set(store.routes.map(\.deviceUID)).count == 2, "Store did not include both outputs")
    precondition(Set(store.routes.map(\.processDisplayName)).count == 2, "Store did not include both inputs")
}

@MainActor
func checkStoreRetriesEnabledRouteAfterRefresh() {
    let service = FakeRoutingService()
    service.startErrors = [.missingProcess]
    let persistence = InMemoryPersistence()
    let store = AudioRouterStore(routingService: service, persistence: persistence)
    store.refresh()

    store.connect(
        applications: service.processes.map(AppSoundSource.init(process:)),
        devices: service.devices
    )

    guard let route = store.routes.first else {
        preconditionFailure("Expected store to create a route")
    }
    precondition(route.isEnabled, "Store disabled a transiently failed route")
    precondition(service.activeRouteIDs.isEmpty, "Service should not have an active route after the forced start failure")

    store.refresh()

    precondition(store.routes.first?.status == .running, "Store did not retry and start the enabled route after refresh")
    precondition(service.activeRouteIDs.count == 1, "Service did not start the retried route")
}

@MainActor
func checkStoreStopAll() {
    let service = FakeRoutingService()
    let persistence = InMemoryPersistence()
    let store = AudioRouterStore(routingService: service, persistence: persistence)
    let process = service.processes[0]
    let device = service.devices[0]

    store.addRoute(process: process, device: device, muteOriginal: true)
    guard let route = store.routes.first else {
        preconditionFailure("Expected store to add a route")
    }

    store.setRouteEnabled(route, isEnabled: true)
    store.stopAllRoutes()

    precondition(service.didStopAll, "Store did not call stopAll")
    precondition(store.routes.first?.isEnabled == false, "Store did not disable route")
    precondition(store.routes.first?.status == .stopped, "Store did not mark route stopped")
}

func sampleDevice(
    uid: String,
    name: String,
    outputVolume: Double? = nil,
    canSetVolume: Bool = false
) -> AudioDeviceInfo {
    AudioDeviceInfo(
        audioObjectID: 7,
        uid: uid,
        name: name,
        outputChannelCount: 2,
        transport: .builtIn,
        isDefaultOutput: true,
        isAlive: true,
        outputVolume: outputVolume,
        canSetVolume: canSetVolume
    )
}

func sampleProcess(id: UInt32, pid: Int32, bundleID: String, name: String) -> AudioProcessInfo {
    AudioProcessInfo(
        processObjectID: id,
        pid: pid,
        bundleID: bundleID,
        displayName: name,
        isRunningOutput: true,
        deviceObjectIDs: []
    )
}

private final class FakeRoutingService: AudioRoutingServicing {
    var devices = [
        sampleDevice(uid: "speaker", name: "Speaker")
    ]
    var processes = [
        sampleProcess(id: 2, pid: 123, bundleID: "com.example.Player", name: "Player")
    ]
    var activeRouteIDs: Set<UUID> = []
    var routeLevels: [UUID: Float] = [:]
    var routeVolumes: [UUID: Double] = [:]
    var deviceVolumes: [String: Double] = [:]
    var startErrors: [AudioRoutingError] = []
    var didStopAll = false

    func loadDevices() throws -> [AudioDeviceInfo] {
        devices
    }

    func loadProcesses() throws -> [AudioProcessInfo] {
        processes
    }

    func loadApplications(audioProcesses: [AudioProcessInfo]) throws -> [AppSoundSource] {
        audioProcesses.map(AppSoundSource.init(process:))
    }

    func setDefaultOutput(deviceUID: String) throws {
        devices = devices.map { device in
            AudioDeviceInfo(
                audioObjectID: device.audioObjectID,
                uid: device.uid,
                name: device.name,
                outputChannelCount: device.outputChannelCount,
                transport: device.transport,
                isDefaultOutput: device.uid == deviceUID,
                isAlive: device.isAlive,
                outputVolume: device.outputVolume,
                isMuted: device.isMuted,
                canSetVolume: device.canSetVolume,
                canSetMute: device.canSetMute
            )
        }
    }

    func setDeviceVolume(deviceUID: String, volume: Double) throws {
        deviceVolumes[deviceUID] = volume
    }

    func setDeviceMuted(deviceUID: String, isMuted: Bool) throws {}

    func start(route: RouteRule, process: AudioProcessInfo, device: AudioDeviceInfo) throws {
        if !startErrors.isEmpty {
            throw startErrors.removeFirst()
        }
        activeRouteIDs.insert(route.id)
        routeLevels[route.id] = 0.5
        routeVolumes[route.id] = route.volume
    }

    func setVolume(routeID: UUID, volume: Double) {
        routeVolumes[routeID] = volume
    }

    func stop(routeID: UUID) {
        activeRouteIDs.remove(routeID)
        routeLevels.removeValue(forKey: routeID)
        routeVolumes.removeValue(forKey: routeID)
    }

    func stopAll() {
        didStopAll = true
        activeRouteIDs.removeAll()
        routeLevels.removeAll()
        routeVolumes.removeAll()
    }
}

private final class InMemoryPersistence: RoutePersisting {
    var routes: [RouteRule] = []
    var groups: [OutputGroup] = []

    func loadRoutes() throws -> [RouteRule] {
        routes
    }

    func saveRoutes(_ routes: [RouteRule]) throws {
        self.routes = routes
    }

    func loadOutputGroups() throws -> [OutputGroup] {
        groups
    }

    func saveOutputGroups(_ groups: [OutputGroup]) throws {
        self.groups = groups
    }
}

do {
    try await MainActor.run {
        try runChecks()
    }
    print("AudioRouterChecks passed")
} catch {
    fputs("AudioRouterChecks failed: \(error)\n", stderr)
    exit(1)
}
