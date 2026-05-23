import Combine
import Foundation

@MainActor
public final class AudioRouterStore: ObservableObject {
    @Published public private(set) var devices: [AudioDevice] = []
    @Published public private(set) var appSessions: [AudioAppSession] = []
    @Published public private(set) var lastError: String?
    @Published public private(set) var unsupportedNote: String?
    @Published public var selectedSettingsSection: SettingsSection = .general

    public let settings: AppSettingsStore
    public let eqManager: EQManager
    public let presetManager: PresetManager
    public let shortcutManager: ShortcutManager

    private let deviceManager: AudioDeviceManaging
    private let volumeManager: SystemVolumeManager
    private let appSessionManager: AppAudioSessionManager
    private var refreshTimer: Timer?
    private var cancellables: Set<AnyCancellable> = []

    public init(
        deviceManager: AudioDeviceManaging = AudioDeviceManager(),
        settings: AppSettingsStore = AppSettingsStore(),
        eqManager: EQManager = EQManager(),
        presetManager: PresetManager = PresetManager(),
        shortcutManager: ShortcutManager = ShortcutManager(),
        appSessionManager: AppAudioSessionManager = AppAudioSessionManager()
    ) {
        self.deviceManager = deviceManager
        self.volumeManager = SystemVolumeManager(deviceManager: deviceManager)
        self.settings = settings
        self.eqManager = eqManager
        self.presetManager = presetManager
        self.shortcutManager = shortcutManager
        self.appSessionManager = appSessionManager

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
        devices.filter { $0.kind == .output }
    }

    public var inputDevices: [AudioDevice] {
        devices.filter { $0.kind == .input }
    }

    public var currentOutput: AudioDevice? {
        outputDevices.first { $0.isDefault } ?? outputDevices.first
    }

    public var currentInput: AudioDevice? {
        inputDevices.first { $0.isDefault } ?? inputDevices.first
    }

    public func start() {
        refresh()
        guard refreshTimer == nil else { return }
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 2.5, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.refresh(silent: true)
            }
        }
    }

    public func stop() {
        refreshTimer?.invalidate()
        refreshTimer = nil
    }

    public func refresh(silent: Bool = false) {
        do {
            devices = try deviceManager.refreshDevices()
            appSessions = appSessionManager.refreshSessions(existing: appSessions)
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
        do {
            if device.kind == .output {
                try volumeManager.setOutputVolume(device: device, volume: clamped)
            } else {
                try volumeManager.setInputVolume(device: device, volume: clamped)
            }
            refreshAfterDelay()
        } catch {
            lastError = error.localizedDescription
            refreshAfterDelay(interval: 0.1)
        }
    }

    public func setDeviceMuted(_ device: AudioDevice, isMuted: Bool) {
        devices = devices.map { $0.id == device.id ? copyDevice($0, isMuted: isMuted) : $0 }
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
        do {
            try volumeManager.setBalance(device: device, balance: clamped)
            refreshAfterDelay()
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
        let outputs = outputDevices
        guard outputs.count > 1 else { return }
        let currentIndex = outputs.firstIndex { $0.uid == currentOutput?.uid } ?? 0
        let nextIndex = outputs.index(after: currentIndex) == outputs.endIndex ? outputs.startIndex : outputs.index(after: currentIndex)
        setDefaultDevice(outputs[nextIndex])
    }

    public func setAppVolume(session: AudioAppSession, volume: Double) {
        let updated = appSessionManager.setVolume(volume, for: session)
        updateAppSession(updated)
        showUnsupportedNote("Per-app volume is stored in AudioRouter for presets, but real per-app output gain needs a virtual audio driver or system audio plug-in.")
    }

    public func setAppMuted(session: AudioAppSession, isMuted: Bool) {
        let updated = appSessionManager.setMuted(isMuted, for: session)
        updateAppSession(updated)
        showUnsupportedNote("Per-app mute is represented in the UI. Muting arbitrary app audio system-wide requires an audio driver or plug-in.")
    }

    public func assignAppOutput(session: AudioAppSession, uid: String?) {
        let updated = appSessionManager.assignOutput(uid, for: session)
        updateAppSession(updated)
        showUnsupportedNote("Per-app output redirection cannot be completed with public APIs alone. AudioRouter keeps the assignment ready for a future driver-backed engine.")
    }

    public func saveCurrentSetup() {
        let preset = AudioPreset(
            name: "Setup \(presetManager.presets.count + 1)",
            outputDeviceUID: currentOutput?.uid,
            inputDeviceUID: currentInput?.uid,
            systemVolume: currentOutput?.volume,
            inputVolume: currentInput?.volume,
            systemMuted: currentOutput?.isMuted ?? false,
            appVolumes: Dictionary(uniqueKeysWithValues: appSessions.map { ($0.id, $0.volume) }),
            mutedApps: Dictionary(uniqueKeysWithValues: appSessions.map { ($0.id, $0.isMuted) }),
            appOutputAssignments: Dictionary(uniqueKeysWithValues: appSessions.compactMap { session in
                session.assignedOutputUID.map { (session.id, $0) }
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
        appSessions = appSessions.map { session in
            var updated = session
            if let volume = preset.appVolumes[session.id] {
                updated.volume = volume
            }
            if let muted = preset.mutedApps[session.id] {
                updated.isMuted = muted
            }
            updated.assignedOutputUID = preset.appOutputAssignments[session.id]
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
        appSessions = appSessions.map {
            var session = $0
            session.volume = 1
            session.isMuted = false
            session.assignedOutputUID = nil
            return session
        }
    }

    public func showUnsupportedNote(_ note: String) {
        guard settings.showUnsupportedNotes else { return }
        unsupportedNote = note
    }

    public func dismissUnsupportedNote() {
        unsupportedNote = nil
    }

    public var debugDeviceList: String {
        devices
            .map { "\($0.kind.title): \($0.name) [\($0.uid)] \($0.typeDescription) default=\($0.isDefault) volume=\($0.volume.map { String(format: "%.2f", $0) } ?? "n/a")" }
            .joined(separator: "\n")
    }

    private func updateAppSession(_ session: AudioAppSession) {
        if let index = appSessions.firstIndex(where: { $0.id == session.id }) {
            appSessions[index] = session
        }
    }

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
            canSetVolume: device.canSetVolume,
            canSetMute: device.canSetMute,
            canSetBalance: device.canSetBalance
        )
    }
}

public enum SettingsSection: String, CaseIterable, Identifiable {
    case general = "General"
    case devices = "Devices"
    case shortcuts = "Shortcuts"
    case presets = "Presets"
    case advanced = "Advanced"

    public var id: String { rawValue }

    public var systemImage: String {
        switch self {
        case .general: return "gearshape"
        case .devices: return "speaker.wave.2"
        case .shortcuts: return "keyboard"
        case .presets: return "square.stack.3d.up"
        case .advanced: return "slider.horizontal.3"
        }
    }
}
