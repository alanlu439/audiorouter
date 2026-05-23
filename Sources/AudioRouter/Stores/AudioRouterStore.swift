import Combine
import Foundation

@MainActor
public final class AudioRouterStore: ObservableObject {
    @Published public var devices: [AudioDeviceInfo] = []
    @Published public var processes: [AudioProcessInfo] = []
    @Published public var applications: [AppSoundSource] = []
    @Published public var routes: [RouteRule] = []
    @Published public var outputGroups: [OutputGroup] = []
    @Published public var routeLevels: [UUID: Float] = [:]
    @Published var selectedSection: AppSection? = .routes
    @Published var diagnostics: [DiagnosticsEvent] = []

    private let routingService: AudioRoutingServicing
    private let persistence: RoutePersisting
    private var levelTimer: Timer?
    private var routePersistTimer: Timer?
    private var deviceRefreshTimer: Timer?

    public init(
        routingService: AudioRoutingServicing = AudioRoutingService(),
        persistence: RoutePersisting = RoutePersistence()
    ) {
        self.routingService = routingService
        self.persistence = persistence
        loadPersistedRoutes()
        loadPersistedOutputGroups()
        levelTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                let levels = self.routingService.routeLevels
                if self.routeLevels != levels {
                    self.routeLevels = levels
                }
            }
        }
    }

    deinit {
        levelTimer?.invalidate()
        routePersistTimer?.invalidate()
        deviceRefreshTimer?.invalidate()
    }

    public func refresh() {
        do {
            devices = try routingService.loadDevices()
            processes = try routingService.loadProcesses()
            applications = try routingService.loadApplications(audioProcesses: processes)
            reconcileRoutes()
            startEnabledRoutesIfNeeded()
            addEvent(.info, "Refreshed \(devices.count) outputs and \(applications.count) applications.")
        } catch {
            addEvent(.error, error.localizedDescription)
        }
    }

    public func addRoute(process: AudioProcessInfo, device: AudioDeviceInfo, muteOriginal: Bool) {
        var route = RouteRule(process: process, device: device, muteOriginal: true)
        route.status = .stopped
        routes.append(route)
        persistRoutes()
        addEvent(.info, "Added route for \(process.displayName) to \(device.name).")
    }

    public func addRoute(application: AppSoundSource, device: AudioDeviceInfo, muteOriginal: Bool) {
        var route = RouteRule(application: application, device: device, muteOriginal: true)
        route.status = .stopped
        routes.append(route)
        persistRoutes()
        addEvent(.info, "Added route for \(application.displayName) to \(device.name).")
    }

    public func connect(application: AppSoundSource, device: AudioDeviceInfo) {
        connect(applications: [application], devices: [device])
    }

    public func connect(applications: [AppSoundSource], devices: [AudioDeviceInfo]) {
        guard !applications.isEmpty, !devices.isEmpty else { return }

        for application in applications {
            for device in devices {
                if let existingIndex = routes.firstIndex(where: { routeMatches($0, application: application, device: device) }) {
                    routes[existingIndex].deviceUID = device.uid
                    routes[existingIndex].deviceName = device.name
                    routes[existingIndex].muteOriginal = true
                    routes[existingIndex].isEnabled = true
                    routes[existingIndex].status = .ready
                    if routingService.activeRouteIDs.contains(routes[existingIndex].id) {
                        routes[existingIndex].status = .running
                        routeLevels = routingService.routeLevels
                        persistRoutes()
                    } else {
                        startRoute(routes[existingIndex])
                    }
                } else {
                    let route = RouteRule(application: application, device: device, isEnabled: true, muteOriginal: true)
                    routes.append(route)
                    startRoute(route)
                }
            }
        }
    }

    public func connect(applications: [AppSoundSource], outputGroup: OutputGroup) {
        let groupDevices = outputGroup.deviceUIDs.compactMap { uid in
            devices.first { $0.uid == uid && $0.isRoutableOutput }
        }
        connect(applications: applications, devices: groupDevices)
    }

    public func removeRoute(_ route: RouteRule) {
        routingService.stop(routeID: route.id)
        routes.removeAll { $0.id == route.id }
        persistRoutes()
        addEvent(.info, "Removed route for \(route.processDisplayName).")
    }

    public func setRouteEnabled(_ route: RouteRule, isEnabled: Bool) {
        guard let index = routes.firstIndex(where: { $0.id == route.id }) else { return }
        routes[index].isEnabled = isEnabled

        if isEnabled {
            startRoute(routes[index])
        } else {
            routingService.stop(routeID: route.id)
            routeLevels = routingService.routeLevels
            routes[index].status = .stopped
            routes[index].lastError = nil
            persistRoutes()
            addEvent(.info, "Stopped \(route.processDisplayName).")
        }
    }

    public func updateRoute(_ route: RouteRule, deviceUID: String?, muteOriginal: Bool) {
        guard let index = routes.firstIndex(where: { $0.id == route.id }) else { return }
        let wasEnabled = routes[index].isEnabled
        if wasEnabled {
            routingService.stop(routeID: route.id)
        }

        let device = deviceUID.flatMap { uid in devices.first { $0.uid == uid } }
        routes[index].deviceUID = deviceUID
        routes[index].deviceName = device?.name ?? "No output"
        routes[index].muteOriginal = true
        routes[index].status = wasEnabled ? .ready : .stopped
        routes[index].lastError = nil

        if wasEnabled {
            startRoute(routes[index])
        } else {
            persistRoutes()
        }
    }

    public func setRouteVolume(_ route: RouteRule, volume: Double) {
        guard let index = routes.firstIndex(where: { $0.id == route.id }) else { return }
        let clampedVolume = max(0, min(volume, 1.5))
        routes[index].volume = clampedVolume
        routingService.setVolume(routeID: route.id, volume: clampedVolume)
        scheduleRoutePersistence()
    }

    public func createOutputGroup(name: String, deviceUIDs: [String]) {
        let uniqueUIDs = Array(NSOrderedSet(array: deviceUIDs).compactMap { $0 as? String })
        guard !uniqueUIDs.isEmpty else { return }
        let cleanName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let group = OutputGroup(
            name: cleanName.isEmpty ? "Output Group \(outputGroups.count + 1)" : cleanName,
            deviceUIDs: uniqueUIDs
        )
        outputGroups.append(group)
        persistOutputGroups()
        addEvent(.info, "Created output group \(group.name).")
    }

    public func removeOutputGroup(_ group: OutputGroup) {
        outputGroups.removeAll { $0.id == group.id }
        persistOutputGroups()
        addEvent(.info, "Removed output group \(group.name).")
    }

    public func setDefaultOutput(_ device: AudioDeviceInfo) {
        do {
            try routingService.setDefaultOutput(deviceUID: device.uid)
            updateDeviceStates { current in
                copyDevice(current, isDefaultOutput: current.uid == device.uid)
            }
            scheduleDeviceRefresh()
            addEvent(.info, "Set \(device.name) as the default output.")
        } catch {
            addEvent(.error, error.localizedDescription)
        }
    }

    public func setDeviceVolume(_ device: AudioDeviceInfo, volume: Double) {
        let clampedVolume = max(0, min(volume, 1))
        updateDevice(device.uid, outputVolume: clampedVolume)
        do {
            try routingService.setDeviceVolume(deviceUID: device.uid, volume: clampedVolume)
            scheduleDeviceRefresh()
        } catch {
            addEvent(.error, error.localizedDescription)
            scheduleDeviceRefresh(interval: 0.05)
        }
    }

    public func setDeviceMuted(_ device: AudioDeviceInfo, isMuted: Bool) {
        updateDevice(device.uid, isMuted: isMuted)
        do {
            try routingService.setDeviceMuted(deviceUID: device.uid, isMuted: isMuted)
            scheduleDeviceRefresh()
        } catch {
            addEvent(.error, error.localizedDescription)
            scheduleDeviceRefresh(interval: 0.05)
        }
    }

    public func stopAllRoutes() {
        routingService.stopAll()
        routeLevels.removeAll()
        for index in routes.indices {
            routes[index].isEnabled = false
            routes[index].status = .stopped
            routes[index].lastError = nil
        }
        persistRoutes()
        addEvent(.info, "Stopped all routes.")
    }

    public func deviceName(for uid: String?) -> String {
        guard let uid else { return "No output" }
        return devices.first(where: { $0.uid == uid })?.name
            ?? routes.first(where: { $0.deviceUID == uid })?.deviceName
            ?? uid
    }

    private func startEnabledRoutesIfNeeded() {
        let pendingRoutes = routes.filter { route in
            route.isEnabled && !routingService.activeRouteIDs.contains(route.id)
        }
        for route in pendingRoutes {
            startRoute(route)
        }
    }

    private func startRoute(_ route: RouteRule) {
        guard let index = routes.firstIndex(where: { $0.id == route.id }) else { return }
        let matchedProcess = RouteResolver.matchingProcess(for: route, in: processes)
        let matchedApplication = RouteResolver.matchingApplication(for: route, in: applications)
        guard let source = matchedProcess.map(AppSoundSource.init(process:)) ?? matchedApplication else {
            routes[index].status = .unavailable
            routes[index].lastError = AudioRoutingError.missingProcess.localizedDescription
            persistRoutes()
            addEvent(.warning, "Process unavailable for \(route.processDisplayName).")
            return
        }
        guard let deviceUID = route.deviceUID,
              let device = devices.first(where: { $0.uid == deviceUID && $0.isRoutableOutput }) else {
            routes[index].status = .unavailable
            routes[index].lastError = AudioRoutingError.missingDevice.localizedDescription
            persistRoutes()
            addEvent(.warning, "Output unavailable for \(route.processDisplayName).")
            return
        }

        do {
            routes[index].muteOriginal = true
            try routingService.start(route: routes[index], process: source.audioProcessInfo, device: device)
            routeLevels = routingService.routeLevels
            routes[index].status = .running
            routes[index].lastError = nil
            persistRoutes()
            addEvent(.info, "Routing \(source.displayName) to \(device.name).")
        } catch AudioRoutingError.missingProcess {
            routes[index].status = .unavailable
            routes[index].lastError = "Start playback in \(route.processDisplayName), then refresh AudioRouter."
            routeLevels = routingService.routeLevels
            persistRoutes()
            addEvent(.warning, routes[index].lastError ?? AudioRoutingError.missingProcess.localizedDescription)
        } catch AudioRoutingError.missingDevice {
            routes[index].status = .unavailable
            routes[index].lastError = AudioRoutingError.missingDevice.localizedDescription
            routeLevels = routingService.routeLevels
            persistRoutes()
            addEvent(.warning, "Output unavailable for \(route.processDisplayName).")
        } catch AudioRoutingError.unsupportedSystem {
            routes[index].isEnabled = false
            routes[index].status = .failed
            routes[index].lastError = AudioRoutingError.unsupportedSystem.localizedDescription
            routeLevels = routingService.routeLevels
            persistRoutes()
            addEvent(.error, routes[index].lastError ?? AudioRoutingError.unsupportedSystem.localizedDescription)
        } catch {
            routes[index].status = .failed
            routes[index].lastError = error.localizedDescription
            routeLevels = routingService.routeLevels
            persistRoutes()
            addEvent(.error, error.localizedDescription)
        }
    }

    private func reconcileRoutes() {
        routes = RouteResolver.updatedRoutes(
            routes,
            devices: devices,
            processes: processes,
            applications: applications,
            activeRouteIDs: routingService.activeRouteIDs
        )
        persistRoutes()
    }

    private func routeMatches(_ route: RouteRule, application: AppSoundSource, device: AudioDeviceInfo) -> Bool {
        guard route.deviceUID == device.uid else { return false }

        if let bundleID = application.bundleID, route.bundleID == bundleID {
            return true
        }
        if let processObjectID = application.processObjectID, route.processObjectID == processObjectID {
            return true
        }
        return route.processDisplayName == application.displayName
    }

    private func loadPersistedRoutes() {
        do {
            routes = try persistence.loadRoutes()
        } catch {
            addEvent(.error, "Could not load saved routes: \(error.localizedDescription)")
        }
    }

    private func loadPersistedOutputGroups() {
        do {
            outputGroups = try persistence.loadOutputGroups()
        } catch {
            addEvent(.error, "Could not load output groups: \(error.localizedDescription)")
        }
    }

    private func persistRoutes() {
        do {
            try persistence.saveRoutes(routes)
        } catch {
            addEvent(.error, "Could not save routes: \(error.localizedDescription)")
        }
    }

    private func scheduleRoutePersistence(interval: TimeInterval = 0.35) {
        routePersistTimer?.invalidate()
        routePersistTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: false) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.persistRoutes()
            }
        }
    }

    private func scheduleDeviceRefresh(interval: TimeInterval = 0.45) {
        deviceRefreshTimer?.invalidate()
        deviceRefreshTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: false) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.refresh()
            }
        }
    }

    private func persistOutputGroups() {
        do {
            try persistence.saveOutputGroups(outputGroups)
        } catch {
            addEvent(.error, "Could not save output groups: \(error.localizedDescription)")
        }
    }

    private func updateDevice(_ uid: String, outputVolume: Double? = nil, isMuted: Bool? = nil) {
        updateDeviceStates { device in
            guard device.uid == uid else { return device }
            return copyDevice(device, outputVolume: outputVolume, isMuted: isMuted)
        }
    }

    private func updateDeviceStates(_ transform: (AudioDeviceInfo) -> AudioDeviceInfo) {
        devices = devices.map(transform)
    }

    private func copyDevice(
        _ device: AudioDeviceInfo,
        isDefaultOutput: Bool? = nil,
        outputVolume: Double? = nil,
        isMuted: Bool? = nil
    ) -> AudioDeviceInfo {
        AudioDeviceInfo(
            audioObjectID: device.audioObjectID,
            uid: device.uid,
            name: device.name,
            outputChannelCount: device.outputChannelCount,
            transport: device.transport,
            isDefaultOutput: isDefaultOutput ?? device.isDefaultOutput,
            isAlive: device.isAlive,
            outputVolume: outputVolume ?? device.outputVolume,
            isMuted: isMuted ?? device.isMuted,
            canSetVolume: device.canSetVolume,
            canSetMute: device.canSetMute
        )
    }

    private func addEvent(_ level: DiagnosticsLevel, _ message: String) {
        diagnostics.insert(
            DiagnosticsEvent(timestamp: Date(), level: level, message: message),
            at: 0
        )
        if diagnostics.count > 60 {
            diagnostics.removeLast(diagnostics.count - 60)
        }
    }
}
