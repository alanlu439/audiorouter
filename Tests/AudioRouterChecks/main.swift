import AudioRouterCore
import Foundation

func runChecks() throws {
    checkEQPresets()
    try checkPresetPersistence()
    checkShortcutPersistence()
    checkDeviceModelIDs()
    checkFocusedOutputFiltering()
    checkRouteBackwardCompatibility()
    try checkRoutingManagerRoutesAndFallback()
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
    precondition(reloaded.route(for: "spotify").routeMode == .followSystemOutput, "Disconnected route should fall back")
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

do {
    try runChecks()
    print("AudioRouter checks passed")
} catch {
    fputs("AudioRouter checks failed: \(error)\n", stderr)
    exit(1)
}
