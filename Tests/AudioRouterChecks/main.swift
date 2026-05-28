import AudioRouterCore
import Foundation

@MainActor
func runChecks() throws {
    checkEQPresets()
    try checkPresetPersistence()
    checkShortcutPersistence()
    checkDeviceModelIDs()
    checkFocusedOutputFiltering()
    checkRouteBackwardCompatibility()
    try checkRoutingManagerRoutesAndFallback()
    try checkDeviceAdditionPreservesCurrentOutput()
    try checkCustomRouteAppPersistence()
    checkUpdateVersionComparison()
    checkAutomaticUpdateCheckPersistence()
    try checkRouteHealthDiagnostics()
}

func checkEQPresets() {
    precondition(EQPreset.allCases.count == 7, "Expected seven EQ presets")
    precondition(EQPreset.music.bands.count == 10, "Music preset should expose ten bands")
    precondition(EQPreset.custom.bands.count == 10, "Custom preset should expose ten bands")
}

func checkPresetPersistence() throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    let manager = PresetManager(fileURL: directory.appendingPathComponent("presets.json"))
    let preset = AudioPreset(
        name: "Desk",
        outputDeviceUID: "output-1",
        inputDeviceUID: "input-1",
        systemVolume: 0.7,
        inputVolume: 0.4,
        systemMuted: false,
        appVolumes: ["music": 0.8],
        mutedApps: ["music": false],
        appOutputAssignments: ["music": "output-1"],
        eqPreset: .music
    )
    manager.savePreset(preset)

    let reloaded = PresetManager(fileURL: directory.appendingPathComponent("presets.json"))
    precondition(reloaded.presets.first?.name == "Desk", "Preset name did not persist")
    precondition(reloaded.presets.first?.eqPreset == .music, "Preset EQ did not persist")

    let exported = reloaded.exportJSON()
    let imported = PresetManager(fileURL: directory.appendingPathComponent("imported.json"))
    imported.importJSON(exported)
    precondition(imported.presets.first?.name == "Desk", "Preset JSON import did not restore setup")
}

func checkShortcutPersistence() {
    let suite = UserDefaults(suiteName: "AudioRouterChecks-\(UUID().uuidString)")!
    let manager = ShortcutManager(defaults: suite)
    manager.update(action: .muteSystem, key: "x", modifiers: [.command])
    let reloaded = ShortcutManager(defaults: suite)
    precondition(reloaded.shortcut(for: .muteSystem).key == "x", "Shortcut key did not persist")
}

func checkDeviceModelIDs() {
    let output = AudioDevice(
        audioObjectID: 1,
        uid: "abc",
        name: "Speaker",
        kind: .output,
        channelCount: 2,
        transport: .builtIn,
        isDefault: true,
        isAlive: true
    )
    let input = AudioDevice(
        audioObjectID: 1,
        uid: "abc",
        name: "Mic",
        kind: .input,
        channelCount: 1,
        transport: .builtIn,
        isDefault: true,
        isAlive: true
    )
    precondition(output.id != input.id, "Input and output identities must not collide")
}

func checkFocusedOutputFiltering() {
    let devices = [
        AudioDevice(audioObjectID: 1, uid: "built-in", name: "MacBook Speakers", kind: .output, channelCount: 2, transport: .builtIn, isDefault: true, isAlive: true),
        AudioDevice(audioObjectID: 2, uid: "airpods", name: "AirPods", kind: .output, channelCount: 2, transport: .bluetoothLE, isDefault: false, isAlive: true),
        AudioDevice(audioObjectID: 3, uid: "hdmi", name: "HDMI", kind: .output, channelCount: 2, transport: .hdmi, isDefault: false, isAlive: true),
        AudioDevice(audioObjectID: 4, uid: "old-speaker", name: "Old Speaker", kind: .output, channelCount: 2, transport: .bluetooth, isDefault: false, isAlive: false),
        AudioDevice(audioObjectID: 5, uid: "mic", name: "Mic", kind: .input, channelCount: 1, transport: .builtIn, isDefault: true, isAlive: true)
    ]
    let routedOutputs = AudioRouterStore.routeOutputDevices(from: devices)
    precondition(routedOutputs.map(\.uid) == ["built-in", "airpods"], "Only connected Bluetooth outputs and system speakers should be shown")
}

func checkRouteBackwardCompatibility() {
    let json = """
    [{"sourceAppID":"spotify","outputDeviceID":"speaker","volume":0.8,"isMuted":false,"routeMode":"customDevice"}]
    """
    let routes = try! JSONDecoder().decode([AudioRoute].self, from: Data(json.utf8))
    precondition(routes.first?.routeMode == .customOutput, "Old customDevice route mode should migrate")
    precondition(routes.first?.status == .requiresBackend, "Migrated custom routes should be backend-required by default")
}

func checkRoutingManagerRoutesAndFallback() throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    let fileURL = directory.appendingPathComponent("routes.json")
    let manager = AudioRoutingManager(backend: FakeRoutingBackend(), fileURL: fileURL)

    let sources = manager.getActiveAudioSources()
    precondition(sources.first?.appName == "Spotify", "Expected fake Spotify source")
    manager.assignOutputDevice(sourceID: "spotify", deviceID: "speaker")

    let customRoute = manager.route(for: "spotify")
    precondition(customRoute.routeMode == .customOutput, "Route should be custom after output assignment")
    precondition(customRoute.status == .requiresBackend, "Public backend routes should be marked backend-required")
    precondition(customRoute.outputDeviceID == "speaker", "Route did not save the selected output")

    let reloaded = AudioRoutingManager(backend: FakeRoutingBackend(), fileURL: fileURL)
    precondition(reloaded.route(for: "spotify").outputDeviceID == "speaker", "Route did not persist")

    reloaded.handleDeviceDisconnected(deviceID: "speaker")
    precondition(reloaded.route(for: "spotify").routeMode == .customOutput, "Disconnected route should keep the saved custom route")
    precondition(reloaded.route(for: "spotify").status == .deviceMissing, "Disconnected route should be marked missing instead of reset")
    reloaded.handleDeviceReconnected(deviceID: "speaker")
    precondition(reloaded.route(for: "spotify").status == .savedOnly, "Reconnected route should be ready to retry")
}

@MainActor
func checkDeviceAdditionPreservesCurrentOutput() throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

    let builtIn = AudioDevice(
        audioObjectID: 1,
        uid: "speaker",
        name: "MacBook Speakers",
        kind: .output,
        channelCount: 2,
        transport: .builtIn,
        isDefault: true,
        isAlive: true
    )
    let airPods = AudioDevice(
        audioObjectID: 2,
        uid: "airpods",
        name: "AirPods",
        kind: .output,
        channelCount: 2,
        transport: .bluetoothLE,
        isDefault: true,
        isAlive: true
    )

    let deviceManager = FakeDeviceManager(devices: [builtIn])
    let settings = AppSettingsStore(defaults: UserDefaults(suiteName: "AudioRouterChecks-\(UUID().uuidString)")!)
    let routingManager = AudioRoutingManager(
        backend: FakeRoutingBackend(),
        fileURL: directory.appendingPathComponent("routes.json")
    )
    routingManager.assignOutputDevice(sourceID: "spotify", deviceID: "speaker")
    let store = AudioRouterStore(
        deviceManager: deviceManager,
        settings: settings,
        audioRoutingManager: routingManager,
        outputGroupsURL: directory.appendingPathComponent("groups.json"),
        appSourcesURL: directory.appendingPathComponent("sources.json"),
        hiddenDefaultSourcesURL: directory.appendingPathComponent("hidden-defaults.json"),
        sourceOrderURL: directory.appendingPathComponent("source-order.json")
    )

    store.refresh(silent: true)
    precondition(store.currentOutput?.uid == "speaker", "Initial current output should be the built-in speaker")

    deviceManager.devices = [airPods]
    store.refresh(silent: true)
    precondition(deviceManager.defaultOutputSetRequests.isEmpty, "AudioRouter should not switch outputs while the previous output is temporarily absent")

    deviceManager.devices = [
        AudioDevice(
            audioObjectID: builtIn.audioObjectID,
            uid: builtIn.uid,
            name: builtIn.name,
            kind: builtIn.kind,
            channelCount: builtIn.channelCount,
            transport: builtIn.transport,
            isDefault: false,
            isAlive: builtIn.isAlive
        ),
        airPods
    ]
    store.refresh(silent: true)

    precondition(deviceManager.defaultOutputSetRequests.contains("speaker"), "Newly added default output should not steal system audio")
    precondition(store.currentOutput?.uid == "speaker", "AudioRouter should keep the previous output active after device addition")
    precondition(routingManager.route(for: "spotify").outputDeviceID == "speaker", "Existing custom route should remain assigned")
    precondition(routingManager.route(for: "spotify").routeMode == .customOutput, "Existing custom route should not reset on device addition")
}

func checkUpdateVersionComparison() {
    precondition(UpdateManager.releaseAssetName == "AudioRouter-macOS.zip", "Updater should fetch the ZIP release asset")
    precondition(UpdateManager.isVersion("0.1.2", newerThan: "0.1.1"), "Patch update should compare newer")
    precondition(UpdateManager.isVersion("0.2.0", newerThan: "0.1.9"), "Minor update should compare newer")
    precondition(UpdateManager.isVersion("v0.1.10", newerThan: "0.1.9"), "Version tags with v prefixes should compare correctly")
    precondition(UpdateManager.isVersion("0.1.3-beta", newerThan: "0.1.2"), "Version tags with suffixes should compare by numeric parts")
    precondition(!UpdateManager.isVersion("0.1.1", newerThan: "0.1.1"), "Same version should not compare newer")
    precondition(!UpdateManager.isVersion("0.1.0", newerThan: "0.1.1"), "Older version should not compare newer")
    precondition(UpdateManager.displayVersion(from: " v0.1.2 ") == "0.1.2", "Display version should trim whitespace and v prefix")
}

@MainActor
func checkAutomaticUpdateCheckPersistence() {
    let suiteName = "AudioRouterChecks-\(UUID().uuidString)"
    let suite = UserDefaults(suiteName: suiteName)!
    defer { suite.removePersistentDomain(forName: suiteName) }

    let date = Date(timeIntervalSince1970: 1_779_966_000)
    suite.set(date, forKey: UpdateManager.lastAutomaticCheckDefaultsKey)
    let manager = UpdateManager(
        defaults: suite,
        automaticCheckInterval: 60,
        currentVersionProvider: { "1.0.0" }
    )

    precondition(manager.lastCheckedAt == date, "Automatic update check timestamp should persist across launches")
    precondition(manager.currentVersion == "1.0.0", "Injected current version should be used for update checks")
}

@MainActor
func checkRouteHealthDiagnostics() throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    let settings = AppSettingsStore(defaults: UserDefaults(suiteName: "AudioRouterChecks-\(UUID().uuidString)")!)
    let store = AudioRouterStore(
        settings: settings,
        audioRoutingManager: AudioRoutingManager(backend: FakeRoutingBackend(), fileURL: directory.appendingPathComponent("routes.json")),
        outputGroupsURL: directory.appendingPathComponent("groups.json"),
        appSourcesURL: directory.appendingPathComponent("sources.json"),
        hiddenDefaultSourcesURL: directory.appendingPathComponent("hidden-defaults.json"),
        sourceOrderURL: directory.appendingPathComponent("source-order.json")
    )
    store.refresh()
    guard let source = store.audioSources.first else {
        preconditionFailure("Expected at least one fake source")
    }
    let health = store.routeHealthItems(for: source)
    precondition(health.contains { $0.id == "configured" }, "Route health should include configured app check")
    precondition(health.contains { $0.id == "backend" }, "Route health should include backend check")
    store.assignSourceOutput(source: source, uid: "speaker")
    precondition(store.routeFailureReason(for: source)?.contains("backend") == true
        || store.routeFailureReason(for: source)?.contains("route") == true,
        "Custom route should expose a useful failure reason")
}

@MainActor
func checkCustomRouteAppPersistence() throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

    let fakeAppURL = directory.appendingPathComponent("WaveLab.app", isDirectory: true)
    let contentsURL = fakeAppURL.appendingPathComponent("Contents", isDirectory: true)
    try FileManager.default.createDirectory(at: contentsURL, withIntermediateDirectories: true)
    let plist: [String: String] = [
        "CFBundleIdentifier": "com.example.WaveLab",
        "CFBundleName": "WaveLab",
        "CFBundlePackageType": "APPL"
    ]
    let plistData = try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)
    try plistData.write(to: contentsURL.appendingPathComponent("Info.plist"))

    let settingsSuite = UserDefaults(suiteName: "AudioRouterChecks-\(UUID().uuidString)")!
    let settings = AppSettingsStore(defaults: settingsSuite)
    settings.demoMode = true

    let appSourcesURL = directory.appendingPathComponent("app-sources.json")
    let routesURL = directory.appendingPathComponent("routes.json")
    let outputGroupsURL = directory.appendingPathComponent("output-groups.json")
    let hiddenDefaultSourcesURL = directory.appendingPathComponent("hidden-defaults.json")
    let sourceOrderURL = directory.appendingPathComponent("source-order.json")
    let store = AudioRouterStore(
        settings: settings,
        audioRoutingManager: AudioRoutingManager(backend: FakeRoutingBackend(), fileURL: routesURL),
        outputGroupsURL: outputGroupsURL,
        appSourcesURL: appSourcesURL,
        hiddenDefaultSourcesURL: hiddenDefaultSourcesURL,
        sourceOrderURL: sourceOrderURL
    )

    precondition(store.routeAppDisplayNames.contains("Spotify"), "Default route apps should be visible")
    store.refresh()
    guard let spotify = store.audioSources.first(where: { $0.bundleIdentifier == "com.spotify.client" }) else {
        preconditionFailure("Default Spotify source should be present in demo mode")
    }
    store.removeRouteApp(spotify)
    precondition(!store.routeAppDisplayNames.contains("Spotify"), "Default route app should be hideable")
    store.restoreDefaultRouteApps()
    precondition(store.routeAppDisplayNames.contains("Spotify"), "Hidden default route apps should be restorable")

    store.addRouteApp(bundleURL: fakeAppURL)
    precondition(store.routeAppDisplayNames.contains("WaveLab"), "Added app should appear in route app list")
    precondition(store.routeAppDisplayNames.last == "WaveLab", "New route apps should be added after default apps")
    precondition(store.audioSources.contains { $0.bundleIdentifier == "com.example.WaveLab" }, "Added app should appear as an audio source")

    let countAfterFirstAdd = store.routeAppDisplayNames.count
    store.addRouteApp(bundleURL: fakeAppURL)
    precondition(store.routeAppDisplayNames.count == countAfterFirstAdd, "Adding the same app twice should not duplicate it")

    guard let waveLab = store.audioSources.first(where: { $0.bundleIdentifier == "com.example.WaveLab" }) else {
        preconditionFailure("Added route app should be available for ordering")
    }
    while store.canMoveRouteApp(waveLab, offset: -1) {
        store.moveRouteApp(waveLab, offset: -1)
    }
    precondition(store.routeAppDisplayNames.first == "WaveLab", "Custom app order should be editable")
    precondition(
        store.reorderRouteApp(draggedSourceID: waveLab.id, targetSourceID: "com.google.Chrome"),
        "Drag/drop route app ordering should accept source and target IDs"
    )
    precondition(store.routeAppDisplayNames.last == "WaveLab", "Drag/drop route app ordering should move the dragged app")

    let reloadedSettings = AppSettingsStore(defaults: settingsSuite)
    reloadedSettings.demoMode = true
    let reloaded = AudioRouterStore(
        settings: reloadedSettings,
        audioRoutingManager: AudioRoutingManager(backend: FakeRoutingBackend(), fileURL: routesURL),
        outputGroupsURL: outputGroupsURL,
        appSourcesURL: appSourcesURL,
        hiddenDefaultSourcesURL: hiddenDefaultSourcesURL,
        sourceOrderURL: sourceOrderURL
    )
    precondition(reloaded.routeAppDisplayNames.contains("WaveLab"), "Added route app should persist")
    precondition(reloaded.routeAppDisplayNames.last == "WaveLab", "Custom route app order should persist")

    reloaded.refresh()
    guard let customSource = reloaded.audioSources.first(where: { $0.bundleIdentifier == "com.example.WaveLab" }) else {
        preconditionFailure("Reloaded route app should become a source")
    }
    reloaded.removeRouteApp(customSource)
    precondition(!reloaded.routeAppDisplayNames.contains("WaveLab"), "Removed route app should leave the configured list")
}

private final class FakeRoutingBackend: AudioRoutingBackend {
    let supportsPerAppRouting = false
    let backendName = "Fake"

    func listAudioSources() throws -> [AudioSource] {
        [
            AudioSource(
                id: "spotify",
                appName: "Spotify",
                bundleIdentifier: "com.spotify.client",
                processID: 42,
                icon: nil,
                isProducingAudio: true
            )
        ]
    }

    func listOutputDevices() throws -> [AudioDevice] {
        [
            AudioDevice(
                audioObjectID: 1,
                uid: "speaker",
                name: "Bluetooth Speaker",
                kind: .output,
                channelCount: 2,
                transport: .bluetooth,
                isDefault: false,
                isAlive: true
            )
        ]
    }

    func routeSourceToDevice(sourceID: String, deviceID: String?) throws {}
    func setSourceVolume(sourceID: String, volume: Double) throws {}
    func muteSource(sourceID: String, muted: Bool) throws {}
}

private final class FakeDeviceManager: AudioDeviceManaging {
    var devices: [AudioDevice]
    private(set) var defaultOutputSetRequests: [String] = []

    init(devices: [AudioDevice]) {
        self.devices = devices
    }

    func refreshDevices() throws -> [AudioDevice] {
        devices
    }

    func listOutputDevices() throws -> [AudioOutputDevice] {
        devices.filter { $0.kind == .output }
    }

    func listInputDevices() throws -> [AudioDevice] {
        devices.filter { $0.kind == .input }
    }

    func getDefaultOutputDevice() throws -> AudioOutputDevice? {
        try listOutputDevices().first { $0.isDefault }
    }

    func getDefaultInputDevice() throws -> AudioDevice? {
        try listInputDevices().first { $0.isDefault }
    }

    func setDefaultOutputDevice(deviceID: String) throws {
        try setDefaultDevice(uid: deviceID, kind: .output)
    }

    func setDefaultInputDevice(deviceID: String) throws {
        try setDefaultDevice(uid: deviceID, kind: .input)
    }

    func setDefaultDevice(uid: String, kind: AudioDeviceKind) throws {
        if kind == .output {
            defaultOutputSetRequests.append(uid)
        }
        devices = devices.map { device in
            AudioDevice(
                audioObjectID: device.audioObjectID,
                uid: device.uid,
                name: device.name,
                kind: device.kind,
                channelCount: device.channelCount,
                transport: device.transport,
                isDefault: device.kind == kind && device.uid == uid,
                isAlive: device.isAlive,
                volume: device.volume,
                isMuted: device.isMuted,
                balance: device.balance,
                sampleRate: device.sampleRate,
                canSetVolume: device.canSetVolume,
                canSetMute: device.canSetMute,
                canSetBalance: device.canSetBalance
            )
        }
    }

    func getDeviceVolume(deviceID: String) throws -> Double? {
        devices.first { $0.uid == deviceID }?.volume
    }

    func setVolume(uid: String, kind: AudioDeviceKind, volume: Double) throws {}
    func setDeviceVolume(deviceID: String, volume: Double) throws {}

    func getDeviceMute(deviceID: String) throws -> Bool? {
        devices.first { $0.uid == deviceID }?.isMuted
    }

    func setMuted(uid: String, kind: AudioDeviceKind, isMuted: Bool) throws {}
    func setDeviceMute(deviceID: String, muted: Bool) throws {}

    func getDeviceBalance(deviceID: String) throws -> Double? {
        devices.first { $0.uid == deviceID }?.balance
    }

    func setBalance(uid: String, kind: AudioDeviceKind, balance: Double) throws {}
    func setDeviceBalance(deviceID: String, balance: Double) throws {}

    func observeDeviceChanges(_ onChange: @escaping @Sendable () -> Void) -> DevicePropertyObservation? {
        nil
    }
}

do {
    try MainActor.assumeIsolated {
        try runChecks()
    }
    print("AudioRouter checks passed")
} catch {
    fputs("AudioRouter checks failed: \(error)\n", stderr)
    exit(1)
}
