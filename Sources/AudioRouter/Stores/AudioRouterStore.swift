import Combine
import Foundation

@MainActor
public final class AudioRouterStore: ObservableObject {
    @Published public private(set) var devices: [AudioDevice] = []
    @Published public private(set) var audioSources: [AudioSource] = []
    @Published public private(set) var lastError: String?
    @Published public private(set) var unsupportedNote: String?
    @Published public var selectedSettingsSection: SettingsSection = .dashboard
    @Published public var sourceMeters: [String: Double] = [:]
    @Published public var deviceMeters: [String: Double] = [:]
    @Published public var systemOutputMeter: Double = 0
    @Published public var inputMeter: Double = 0
    @Published public var soloSourceID: String?
    @Published public var selectedSourceID: String?
    @Published public private(set) var meteringNote: String = "Live meters appear when a process-tap route is active."
    @Published public private(set) var processTapProbeMessage: String?
    @Published public var outputGroups: [OutputDeviceGroup] = [] {
        didSet { saveOutputGroups() }
    }

    public let settings: AppSettingsStore
    public let eqManager: EQManager
    public let presetManager: PresetManager
    public let shortcutManager: ShortcutManager

    private let deviceManager: AudioDeviceManaging
    private let volumeManager: SystemVolumeManager
    private let audioRoutingManager: AudioRoutingManager
    private let processAudioMonitor: ProcessAudioMonitor
    private var refreshTimer: Timer?
    private var meterTimer: Timer?
    private var deviceObservation: DevicePropertyObservation?
    private var pendingVolumeTasks: [String: Task<Void, Never>] = [:]
    private var pendingBalanceTasks: [String: Task<Void, Never>] = [:]
    private var meterPhase: Double = 0
    private var lastRefreshUsedDemoMode: Bool?
    private var cancellables: Set<AnyCancellable> = []
    private let outputGroupsURL: URL

    public init(
        deviceManager: AudioDeviceManaging = AudioDeviceService(),
        settings: AppSettingsStore = AppSettingsStore(),
        eqManager: EQManager = EQManager(),
        presetManager: PresetManager = PresetManager(),
        shortcutManager: ShortcutManager = ShortcutManager(),
        audioRoutingManager: AudioRoutingManager = AudioRoutingManager(),
        processAudioMonitor: ProcessAudioMonitor = ProcessAudioMonitor(),
        outputGroupsURL: URL = try! AppSupport.fileURL(named: "output-groups.json")
    ) {
        self.deviceManager = deviceManager
        self.volumeManager = SystemVolumeManager(deviceManager: deviceManager)
        self.settings = settings
        self.eqManager = eqManager
        self.presetManager = presetManager
        self.shortcutManager = shortcutManager
        self.audioRoutingManager = audioRoutingManager
        self.processAudioMonitor = processAudioMonitor
        self.outputGroupsURL = outputGroupsURL
        self.outputGroups = (try? Data(contentsOf: outputGroupsURL))
            .flatMap { try? JSONDecoder().decode([OutputDeviceGroup].self, from: $0) } ?? []

        settings.objectWillChange
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)
        eqManager.objectWillChange
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)
        presetManager.objectWillChange
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)
        shortcutManager.objectWillChange
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)
    }

    public var outputDevices: [AudioDevice] {
        Self.routeOutputDevices(from: devices)
    }

    public var inputDevices: [AudioDevice] {
        devices.filter { $0.kind == .input }
    }

    public var currentOutput: AudioDevice? {
        outputDevices.first { $0.isDefault } ?? outputDevices.first
    }

    nonisolated public static func routeOutputDevices(from devices: [AudioDevice]) -> [AudioDevice] {
        let outputs = devices.filter { $0.kind == .output && $0.isAlive }
        let bluetoothAndSpeakers = outputs.filter { device in
            device.transport == .bluetooth
                || device.transport == .bluetoothLE
                || device.transport == .builtIn
        }

        if bluetoothAndSpeakers.contains(where: { $0.transport == .builtIn }) {
            return bluetoothAndSpeakers
        }

        if let defaultOutput = outputs.first(where: { $0.isDefault }),
           !bluetoothAndSpeakers.contains(where: { $0.uid == defaultOutput.uid }) {
            return ([defaultOutput] + bluetoothAndSpeakers).uniquedByUID()
        }

        return bluetoothAndSpeakers
    }

    public var currentInput: AudioDevice? {
        inputDevices.first { $0.isDefault } ?? inputDevices.first
    }

    public var routingBackendName: String {
        audioRoutingManager.backendName
    }

    public var supportsTruePerAppRouting: Bool {
        audioRoutingManager.supportsTruePerAppRouting
    }

    public var supportsPerAppVolume: Bool {
        audioRoutingManager.supportsPerAppVolume || settings.demoMode
    }

    public var supportsPerAppMute: Bool {
        audioRoutingManager.supportsPerAppMute || settings.demoMode
    }

    public var liveMeteringAvailable: Bool {
        !settings.demoMode
            && audioRoutingManager.supportsLiveProcessMeters
            && audioSources.contains { source in
                let route = audioRoutingManager.route(for: source.id)
                return route.routeMode == .customOutput && route.status == .active
            }
    }

    public func start() {
        refresh()
        startDeviceObservationIfNeeded()
        guard refreshTimer == nil else { return }
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.refresh(silent: true)
            }
        }
        configureMeterTimer()
    }

    public func stop() {
        refreshTimer?.invalidate()
        refreshTimer = nil
        meterTimer?.invalidate()
        meterTimer = nil
        pendingVolumeTasks.values.forEach { $0.cancel() }
        pendingVolumeTasks.removeAll()
        pendingBalanceTasks.values.forEach { $0.cancel() }
        pendingBalanceTasks.removeAll()
        deviceObservation?.cancel()
        deviceObservation = nil
    }

    public func refresh(silent: Bool = false) {
        do {
            let usingDemoMode = settings.demoMode
            let previousOutputUIDs = Set(outputDevices.map(\.uid))
            if usingDemoMode {
                deviceObservation?.cancel()
                deviceObservation = nil
                if lastRefreshUsedDemoMode != true || devices.isEmpty {
                    devices = demoDevices
                }
            } else {
                devices = try deviceManager.refreshDevices()
            }
            lastRefreshUsedDemoMode = usingDemoMode
            if usingDemoMode {
                meteringNote = "Demo Mode uses animated meters for UI testing."
            } else {
                startDeviceObservationIfNeeded()
                meteringNote = processAudioMonitor.meterAvailabilityMessage
            }
            let currentOutputUIDs = Set(outputDevices.map(\.uid))
            for disconnectedUID in previousOutputUIDs.subtracting(currentOutputUIDs) {
                audioRoutingManager.handleDeviceDisconnected(deviceID: disconnectedUID)
            }
            for reconnectedUID in currentOutputUIDs.subtracting(previousOutputUIDs) {
                audioRoutingManager.handleDeviceReconnected(deviceID: reconnectedUID)
            }
            audioSources = usingDemoMode ? demoSources : focusedSources(from: audioRoutingManager.getActiveAudioSources())
            configureMeterTimer()
            if let warning = audioRoutingManager.lastWarning {
                unsupportedNote = warning
            }
            if !silent {
                lastError = nil
            }
        } catch {
            lastError = error.localizedDescription
        }
    }

    public func applyActivationPolicy() {
        settings.applyActivationPolicy()
    }

    public func setDefaultDevice(_ device: AudioDevice) {
        if settings.demoMode {
            devices = devices.map { copyDevice($0, isDefault: $0.kind == device.kind && $0.uid == device.uid) }
            return
        }
        do {
            try deviceManager.setDefaultDevice(uid: device.uid, kind: device.kind)
            devices = devices.map { copyDevice($0, isDefault: $0.kind == device.kind && $0.uid == device.uid) }
            refreshAfterDelay()
        } catch {
            lastError = error.localizedDescription
        }
    }

    public func setSystemOutputVolume(_ volume: Double) {
        guard let output = currentOutput else { return }
        setDeviceVolume(output, volume: volume)
    }

    public func setInputVolume(_ volume: Double) {
        guard let input = currentInput else { return }
        setDeviceVolume(input, volume: volume)
    }

    public func setDeviceVolume(_ device: AudioDevice, volume: Double) {
        let clamped = volume.clampedUnit
        devices = devices.map { $0.id == device.id ? copyDevice($0, volume: clamped) : $0 }
        if settings.demoMode {
            return
        }
        guard device.canSetVolume else {
            lastError = AudioRouterError.unsupportedControl("\(device.kind.title) volume").localizedDescription
            return
        }
        let taskKey = device.id
        pendingVolumeTasks[taskKey]?.cancel()
        pendingVolumeTasks[taskKey] = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 140_000_000)
            guard !Task.isCancelled else { return }
            await MainActor.run { [weak self] in
                self?.commitDeviceVolume(device, volume: clamped)
                self?.pendingVolumeTasks.removeValue(forKey: taskKey)
            }
        }
    }

    public func setDeviceMuted(_ device: AudioDevice, isMuted: Bool) {
        devices = devices.map { $0.id == device.id ? copyDevice($0, isMuted: isMuted) : $0 }
        if settings.demoMode {
            return
        }
        do {
            try volumeManager.setMuted(device: device, isMuted: isMuted)
            refreshAfterDelay()
        } catch {
            lastError = error.localizedDescription
            refreshAfterDelay(interval: 0.1)
        }
    }

    public func setDeviceBalance(_ device: AudioDevice, balance: Double) {
        let clamped = balance.clampedBalance
        devices = devices.map { $0.id == device.id ? copyDevice($0, balance: clamped) : $0 }
        if settings.demoMode {
            return
        }
        guard device.canSetBalance else {
            lastError = AudioRouterError.unsupportedControl("\(device.kind.title) balance").localizedDescription
            return
        }
        let taskKey = device.id
        pendingBalanceTasks[taskKey]?.cancel()
        pendingBalanceTasks[taskKey] = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 140_000_000)
            guard !Task.isCancelled else { return }
            await MainActor.run { [weak self] in
                self?.commitDeviceBalance(device, balance: clamped)
                self?.pendingBalanceTasks.removeValue(forKey: taskKey)
            }
        }
    }

    private func commitDeviceVolume(_ device: AudioDevice, volume: Double) {
        do {
            if device.kind == .output {
                try volumeManager.setOutputVolume(device: device, volume: volume)
            } else {
                try volumeManager.setInputVolume(device: device, volume: volume)
            }
            refreshAfterDelay(interval: 0.45)
        } catch {
            lastError = error.localizedDescription
            refreshAfterDelay(interval: 0.1)
        }
    }

    private func commitDeviceBalance(_ device: AudioDevice, balance: Double) {
        do {
            try volumeManager.setBalance(device: device, balance: balance)
            refreshAfterDelay(interval: 0.45)
        } catch {
            lastError = error.localizedDescription
            refreshAfterDelay(interval: 0.1)
        }
    }

    public func toggleSystemMute() {
        guard let output = currentOutput else { return }
        setDeviceMuted(output, isMuted: !(output.isMuted ?? false))
    }

    public func changeSystemVolume(by delta: Double) {
        guard let output = currentOutput else { return }
        setDeviceVolume(output, volume: (output.volume ?? 0.5) + delta)
    }

    public func switchToNextOutputDevice() {
        switchOutputDevice(offset: 1)
    }

    public func switchToPreviousOutputDevice() {
        switchOutputDevice(offset: -1)
    }

    private func switchOutputDevice(offset: Int) {
        let outputs = outputDevices
        guard outputs.count > 1 else { return }
        let currentIndex = outputs.firstIndex { $0.uid == currentOutput?.uid } ?? 0
        let nextIndex = (currentIndex + offset + outputs.count) % outputs.count
        setDefaultDevice(outputs[nextIndex])
    }

    public func route(for source: AudioSource) -> AudioRoute {
        audioRoutingManager.route(for: source.id)
    }

    public func routeOutputName(for source: AudioSource) -> String {
        let route = route(for: source)
        if let outputDeviceID = route.outputDeviceID,
           let group = outputGroups.first(where: { $0.routeTargetID == outputDeviceID }) {
            return group.name
        }
        return audioRoutingManager.deviceName(for: route, outputs: outputDevices)
    }

    public func setSourceVolume(source: AudioSource, volume: Double) {
        selectedSourceID = source.id
        audioRoutingManager.setSourceVolume(sourceID: source.id, volume: volume)
        updateAudioSource(source.id) { current in
            current.volume = max(0, min(1.5, volume))
        }
        if let warning = audioRoutingManager.lastWarning {
            showUnsupportedNote(warning)
        }
    }

    public func toggleSolo(source: AudioSource) {
        selectedSourceID = source.id
        soloSourceID = soloSourceID == source.id ? nil : source.id
    }

    public func setSourceMuted(source: AudioSource, isMuted: Bool) {
        selectedSourceID = source.id
        audioRoutingManager.muteSource(sourceID: source.id, muted: isMuted)
        updateAudioSource(source.id) { current in
            current.isMuted = isMuted
        }
        if let warning = audioRoutingManager.lastWarning {
            showUnsupportedNote(warning)
        }
    }

    public func assignSourceOutput(source: AudioSource, uid: String?) {
        selectedSourceID = source.id
        if let uid {
            audioRoutingManager.assignOutputDevice(sourceID: source.id, deviceID: uid)
        } else {
            audioRoutingManager.resetSourceToSystemOutput(sourceID: source.id)
        }
        let route = audioRoutingManager.route(for: source.id)
        updateAudioSource(source.id) { current in
            current.assignedOutputDeviceID = route.outputDeviceID
            current.routeMode = route.routeMode
            current.followsSystemOutput = route.routeMode == .followSystemOutput
        }
        configureMeterTimer()
        if let warning = audioRoutingManager.lastWarning {
            showUnsupportedNote(warning)
        }
    }

    public func resetSourceToSystemOutput(_ source: AudioSource) {
        assignSourceOutput(source: source, uid: nil)
    }

    public func toggleSelectedSourceMute() {
        guard let selectedSourceID,
              let source = audioSources.first(where: { $0.id == selectedSourceID }) else {
            showUnsupportedNote("Select an app source in Dashboard or Mixer before using Mute Selected App.")
            return
        }
        setSourceMuted(source: source, isMuted: !source.isMuted)
    }

    public func applyPreset(at index: Int) {
        guard presetManager.presets.indices.contains(index) else {
            showUnsupportedNote("No saved setup exists in slot \(index + 1).")
            return
        }
        applyPreset(presetManager.presets[index])
    }

    public func probeProcessTapPermission() {
        let result = processAudioMonitor.probeFirstAvailableProcessTap(from: audioSources)
        processTapProbeMessage = result.message
        switch result.status {
        case .tapCreated:
            showUnsupportedNote("Process tap permission is available. Assign an app to an output to start the live routing engine.")
        case let .permissionDenied(message), let .unavailable(message):
            showUnsupportedNote(message)
        }
    }

    public func createOutputGroup() {
        let deviceUIDs = Array(outputDevices.prefix(2).map(\.uid))
        let volumes = Dictionary(uniqueKeysWithValues: deviceUIDs.map { uid in
            (uid, outputDevices.first(where: { $0.uid == uid })?.volume ?? 1)
        })
        outputGroups.insert(
            OutputDeviceGroup(
                name: "Output Group \(outputGroups.count + 1)",
                deviceUIDs: deviceUIDs,
                perDeviceVolumes: volumes
            ),
            at: 0
        )
    }

    public func renameOutputGroup(_ group: OutputDeviceGroup, to name: String) {
        updateOutputGroup(group.id) { current in
            current.name = name.isEmpty ? current.name : name
        }
    }

    public func deleteOutputGroup(_ group: OutputDeviceGroup) {
        outputGroups.removeAll { $0.id == group.id }
        for source in audioSources where route(for: source).outputDeviceID == group.routeTargetID {
            resetSourceToSystemOutput(source)
        }
    }

    public func setOutputGroup(_ group: OutputDeviceGroup, includes device: AudioDevice, included: Bool) {
        updateOutputGroup(group.id) { current in
            if included {
                if !current.deviceUIDs.contains(device.uid) {
                    current.deviceUIDs.append(device.uid)
                }
                current.perDeviceVolumes[device.uid] = device.volume ?? current.perDeviceVolumes[device.uid] ?? 1
            } else {
                current.deviceUIDs.removeAll { $0 == device.uid }
                current.perDeviceVolumes.removeValue(forKey: device.uid)
            }
        }
    }

    public func setOutputGroupVolume(_ group: OutputDeviceGroup, deviceUID: String, volume: Double) {
        updateOutputGroup(group.id) { current in
            current.perDeviceVolumes[deviceUID] = volume.clampedUnit
        }
        if let device = outputDevices.first(where: { $0.uid == deviceUID }), device.canSetVolume {
            setDeviceVolume(device, volume: volume)
        }
    }

    public func routedSources(to device: AudioDevice) -> [AudioSource] {
        audioSources.filter { source in
            let route = route(for: source)
            if route.routeMode != .customOutput {
                return false
            }
            if route.outputDeviceID == device.uid {
                return true
            }
            return outputGroups
                .first(where: { $0.routeTargetID == route.outputDeviceID })?
                .deviceUIDs
                .contains(device.uid) == true
        }
    }

    public func routeStatus(for source: AudioSource) -> String {
        let route = route(for: source)
        if settings.demoMode {
            return route.routeMode == .followSystemOutput ? "Demo" : "Simulated"
        }
        if route.routeMode == .followSystemOutput {
            return "Working"
        }
        if let outputID = route.outputDeviceID,
           outputGroups.contains(where: { $0.routeTargetID == outputID }) {
            return "Requires Audio Backend"
        }
        switch route.status {
        case .active:
            return supportsTruePerAppRouting ? "Live" : "Working"
        case .savedOnly:
            return "Saved Only"
        case .simulated:
            return "Simulated"
        case .requiresBackend:
            return "Requires Audio Backend"
        case .deviceMissing:
            return "Device Missing"
        }
    }

    public func routeStatusIsWarning(for source: AudioSource) -> Bool {
        ["Requires Audio Backend", "Unsupported", "Device Missing"].contains(routeStatus(for: source))
    }

    public func saveCurrentSetup() {
        let preset = AudioPreset(
            name: "Setup \(presetManager.presets.count + 1)",
            outputDeviceUID: currentOutput?.uid,
            inputDeviceUID: currentInput?.uid,
            systemVolume: currentOutput?.volume,
            inputVolume: currentInput?.volume,
            systemMuted: currentOutput?.isMuted ?? false,
            appVolumes: Dictionary(uniqueKeysWithValues: audioSources.map { ($0.id, $0.volume) }),
            mutedApps: Dictionary(uniqueKeysWithValues: audioSources.map { ($0.id, $0.isMuted) }),
            appOutputAssignments: Dictionary(uniqueKeysWithValues: audioSources.compactMap { source in
                source.assignedOutputDeviceID.map { (source.id, $0) }
            }),
            eqPreset: eqManager.state.selectedPreset
        )
        presetManager.savePreset(preset)
    }

    public func applyPreset(_ preset: AudioPreset) {
        if let outputUID = preset.outputDeviceUID,
           let output = outputDevices.first(where: { $0.uid == outputUID }) {
            setDefaultDevice(output)
        }
        if let inputUID = preset.inputDeviceUID,
           let input = inputDevices.first(where: { $0.uid == inputUID }) {
            setDefaultDevice(input)
        }
        if let volume = preset.systemVolume {
            setSystemOutputVolume(volume)
        }
        if let inputVolume = preset.inputVolume {
            setInputVolume(inputVolume)
        }
        if let output = currentOutput {
            setDeviceMuted(output, isMuted: preset.systemMuted)
        }
        eqManager.applyPreset(preset.eqPreset)
        audioSources = audioSources.map { source in
            var updated = source
            if let volume = preset.appVolumes[source.id] {
                updated.volume = volume
                audioRoutingManager.setSourceVolume(sourceID: source.id, volume: volume)
            }
            if let muted = preset.mutedApps[source.id] {
                updated.isMuted = muted
                audioRoutingManager.muteSource(sourceID: source.id, muted: muted)
            }
            if let outputID = preset.appOutputAssignments[source.id] {
                updated.assignedOutputDeviceID = outputID
                updated.followsSystemOutput = false
                updated.routeMode = .customOutput
                audioRoutingManager.assignOutputDevice(sourceID: source.id, deviceID: outputID)
            } else {
                updated.assignedOutputDeviceID = nil
                updated.followsSystemOutput = true
                updated.routeMode = .followSystemOutput
                audioRoutingManager.resetSourceToSystemOutput(sourceID: source.id)
            }
            return updated
        }
    }

    public func setLaunchAtLogin(_ enabled: Bool) {
        do {
            try settings.setLaunchAtLogin(enabled)
        } catch {
            lastError = "Launch at Login could not be changed: \(error.localizedDescription)"
        }
    }

    public func resetAllSettings() {
        settings.reset()
        eqManager.applyPreset(.flat)
        shortcutManager.reset()
        presetManager.reset()
        audioSources = audioSources.map {
            var source = $0
            source.volume = 1
            source.isMuted = false
            source.assignedOutputDeviceID = nil
            source.followsSystemOutput = true
            source.routeMode = .followSystemOutput
            audioRoutingManager.resetSourceToSystemOutput(sourceID: source.id)
            return source
        }
        outputGroups.removeAll()
    }

    public func showUnsupportedNote(_ note: String) {
        guard settings.showUnsupportedNotes else { return }
        unsupportedNote = note
    }

    public func dismissUnsupportedNote() {
        unsupportedNote = nil
    }

    func statusStyle(for source: AudioSource) -> RouteVisualStatus {
        switch routeStatus(for: source) {
        case "Live": return .live
        case "Demo": return .demo
        case "Simulated": return .simulated
        case "Saved Only": return .savedOnly
        case "Requires Audio Backend": return .requiresBackend
        case "Device Missing": return .deviceMissing
        case "Unsupported": return .unsupported
        default: return .working
        }
    }

    public var debugDeviceList: String {
        devices
            .map { "\($0.kind.title): \($0.name) [\($0.uid)] \($0.typeDescription) default=\($0.isDefault) volume=\($0.volume.map { String(format: "%.2f", $0) } ?? "n/a")" }
            .joined(separator: "\n")
    }

    private func updateAudioSource(_ id: String, transform: (inout AudioSource) -> Void) {
        if let index = audioSources.firstIndex(where: { $0.id == id }) {
            transform(&audioSources[index])
        }
    }

    private func updateOutputGroup(_ id: UUID, transform: (inout OutputDeviceGroup) -> Void) {
        guard let index = outputGroups.firstIndex(where: { $0.id == id }) else { return }
        transform(&outputGroups[index])
    }

    private func startDeviceObservationIfNeeded() {
        guard !settings.demoMode, deviceObservation == nil else { return }
        deviceObservation = deviceManager.observeDeviceChanges { [weak self] in
            Task { @MainActor [weak self] in
                self?.refresh(silent: true)
            }
        }
    }

    private func saveOutputGroups() {
        guard let data = try? JSONEncoder().encode(outputGroups) else { return }
        try? data.write(to: outputGroupsURL, options: .atomic)
    }

    private func configureMeterTimer() {
        let shouldAnimate = settings.demoMode || liveMeteringAvailable
        if shouldAnimate {
            guard meterTimer == nil else { return }
            meterTimer = Timer.scheduledTimer(withTimeInterval: 0.16, repeats: true) { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.tickMeters()
                }
            }
        } else {
            meterTimer?.invalidate()
            meterTimer = nil
            clearMetersIfNeeded()
        }
    }

    private func clearMetersIfNeeded() {
        guard systemOutputMeter != 0
            || inputMeter != 0
            || sourceMeters.values.contains(where: { $0 != 0 })
            || deviceMeters.values.contains(where: { $0 != 0 }) else {
            return
        }
        systemOutputMeter = 0
        inputMeter = 0
        sourceMeters = Dictionary(uniqueKeysWithValues: audioSources.map { ($0.id, 0) })
        deviceMeters = Dictionary(uniqueKeysWithValues: devices.map { ($0.id, 0) })
    }

    private func tickMeters() {
        if !settings.demoMode {
            tickLiveMeters()
            return
        }
        meterPhase += 0.19
        systemOutputMeter = abs(sin(meterPhase * 0.72)) * 0.82 + 0.08
        inputMeter = abs(sin(meterPhase * 0.51 + 1.1)) * 0.65
        sourceMeters = Dictionary(uniqueKeysWithValues: audioSources.map { source in
            let seed = Double(abs(source.id.hashValue % 100)) / 31.0
            let activeBoost = source.isProducingAudio ? 0.35 : 0.10
            let level = source.isMuted ? 0 : min(1, abs(sin(meterPhase + seed)) * 0.55 + activeBoost)
            return (source.id, level)
        })
        deviceMeters = Dictionary(uniqueKeysWithValues: devices.map { device in
            let routed = routedSources(to: device)
            let base = routed.isEmpty ? (device.isDefault ? systemOutputMeter : 0.14) : min(1, routed.map { sourceMeters[$0.id] ?? 0 }.reduce(0, +) / Double(max(1, routed.count)) + 0.12)
            return (device.id, device.kind == .input ? inputMeter : base)
        })
    }

    private func tickLiveMeters() {
        sourceMeters = Dictionary(uniqueKeysWithValues: audioSources.map { source in
            let level = audioRoutingManager.currentLevel(for: source.id) ?? source.currentLevel ?? 0
            return (source.id, level)
        })
        systemOutputMeter = sourceMeters.values.max() ?? 0
        inputMeter = 0
        deviceMeters = Dictionary(uniqueKeysWithValues: devices.map { device in
            let routed = routedSources(to: device)
            let level = routed.isEmpty
                ? (device.isDefault ? systemOutputMeter : 0)
                : min(1, routed.map { sourceMeters[$0.id] ?? 0 }.reduce(0, +) / Double(max(1, routed.count)))
            return (device.id, device.kind == .input ? 0 : level)
        })
    }

    private func focusedSources(from detectedSources: [AudioSource]) -> [AudioSource] {
        Self.focusedSourceSpecs.map { spec in
            let detectedSource = detectedSources.first { detected in
                detected.bundleIdentifier == spec.bundleIdentifier
                    || detected.id == spec.bundleIdentifier
                    || detected.appName.localizedCaseInsensitiveContains(spec.matchName)
            }

            let route = audioRoutingManager.route(for: spec.bundleIdentifier)
            return AudioSource(
                id: spec.bundleIdentifier,
                appName: spec.displayName,
                bundleIdentifier: spec.bundleIdentifier,
                processID: detectedSource?.processID ?? 0,
                audioObjectID: detectedSource?.audioObjectID,
                icon: detectedSource?.icon ?? spec.iconPath,
                isRunning: detectedSource?.isRunning ?? false,
                isProducingAudio: detectedSource?.isProducingAudio ?? false,
                lastActiveTime: detectedSource?.lastActiveTime ?? .distantPast,
                currentLevel: detectedSource?.currentLevel,
                volume: route.volume,
                isMuted: route.isMuted,
                routeMode: route.routeMode,
                assignedOutputDeviceID: route.outputDeviceID,
                followsSystemOutput: route.routeMode == .followSystemOutput
            )
        }
    }

    private var demoDevices: [AudioDevice] {
        [
            AudioDevice(audioObjectID: 10, uid: "demo-macbook", name: "MacBook Speakers", kind: .output, channelCount: 2, transport: .builtIn, isDefault: true, isAlive: true, volume: 0.72, balance: 0, sampleRate: 48000, canSetVolume: true, canSetMute: true, canSetBalance: true),
            AudioDevice(audioObjectID: 11, uid: "demo-bluetooth", name: "Bluetooth Speaker", kind: .output, channelCount: 2, transport: .bluetooth, isDefault: false, isAlive: true, volume: 0.82, balance: -0.08, sampleRate: 44100, canSetVolume: true, canSetMute: true, canSetBalance: false),
            AudioDevice(audioObjectID: 12, uid: "demo-airpods", name: "AirPods", kind: .output, channelCount: 2, transport: .bluetoothLE, isDefault: false, isAlive: true, volume: 0.64, balance: 0.04, sampleRate: 48000, canSetVolume: true, canSetMute: true, canSetBalance: true),
            AudioDevice(audioObjectID: 16, uid: "demo-mic", name: "MacBook Microphone", kind: .input, channelCount: 1, transport: .builtIn, isDefault: true, isAlive: true, volume: 0.66, sampleRate: 48000, canSetVolume: true, canSetMute: false, canSetBalance: false)
        ]
    }

    private var demoSources: [AudioSource] {
        Self.focusedSourceSpecs.map { spec in
            let route = audioRoutingManager.route(for: spec.bundleIdentifier)
            return AudioSource(
                id: spec.bundleIdentifier,
                appName: spec.displayName,
                bundleIdentifier: spec.bundleIdentifier,
                processID: Int32(abs(spec.bundleIdentifier.hashValue % 9000) + 100),
                icon: spec.iconPath,
                isProducingAudio: true,
                lastActiveTime: Date().addingTimeInterval(-3),
                currentLevel: 0.7,
                volume: route.volume,
                isMuted: route.isMuted,
                routeMode: route.routeMode,
                assignedOutputDeviceID: route.outputDeviceID,
                followsSystemOutput: route.routeMode == .followSystemOutput
            )
        }
    }

    private struct FocusedSourceSpec {
        let displayName: String
        let bundleIdentifier: String
        let matchName: String
        let iconPath: String?
    }

    private static let focusedSourceSpecs: [FocusedSourceSpec] = [
        FocusedSourceSpec(displayName: "Spotify", bundleIdentifier: "com.spotify.client", matchName: "spotify", iconPath: "/Applications/Spotify.app"),
        FocusedSourceSpec(displayName: "Apple Music", bundleIdentifier: "com.apple.Music", matchName: "music", iconPath: "/System/Applications/Music.app"),
        FocusedSourceSpec(displayName: "Chrome", bundleIdentifier: "com.google.Chrome", matchName: "chrome", iconPath: "/Applications/Google Chrome.app")
    ]

    private func refreshAfterDelay(interval: TimeInterval = 0.35) {
        Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))
            self?.refresh(silent: true)
        }
    }

    private func copyDevice(
        _ device: AudioDevice,
        isDefault: Bool? = nil,
        volume: Double? = nil,
        isMuted: Bool? = nil,
        balance: Double? = nil
    ) -> AudioDevice {
        AudioDevice(
            audioObjectID: device.audioObjectID,
            uid: device.uid,
            name: device.name,
            kind: device.kind,
            channelCount: device.channelCount,
            transport: device.transport,
            isDefault: isDefault ?? device.isDefault,
            isAlive: device.isAlive,
            volume: volume ?? device.volume,
            isMuted: isMuted ?? device.isMuted,
            balance: balance ?? device.balance,
            sampleRate: device.sampleRate,
            canSetVolume: device.canSetVolume,
            canSetMute: device.canSetMute,
            canSetBalance: device.canSetBalance
        )
    }
}

public enum SettingsSection: String, CaseIterable, Identifiable {
    case dashboard = "Dashboard"
    case mixer = "Mixer"
    case devices = "Devices"
    case eq = "EQ"
    case setups = "Setups"
    case shortcuts = "Shortcuts"
    case advanced = "Advanced"

    public var id: String { rawValue }

    public var systemImage: String {
        switch self {
        case .dashboard: return "point.3.connected.trianglepath.dotted"
        case .mixer: return "slider.horizontal.3"
        case .devices: return "speaker.wave.2"
        case .eq: return "waveform"
        case .setups: return "square.stack.3d.up"
        case .shortcuts: return "keyboard"
        case .advanced: return "gearshape.2"
        }
    }
}

private extension Array where Element == AudioDevice {
    func uniquedByUID() -> [AudioDevice] {
        var seen: Set<String> = []
        return filter { device in
            seen.insert(device.uid).inserted
        }
    }
}
