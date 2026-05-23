import AppKit
import Foundation

public final class PublicAPIAudioRoutingBackend: AudioRoutingBackend {
    public let supportsPerAppRouting = false
    public let backendName = "Public macOS APIs"

    private let client: CoreAudioClient

    public convenience init() {
        self.init(client: CoreAudioClient())
    }

    init(client: CoreAudioClient) {
        self.client = client
    }

    public func listAudioSources() throws -> [AudioSource] {
        let detected = try client.audioSources()
        let baseSources = detected.isEmpty ? fallbackSources() : detected
        return withSystemSoundsSource(baseSources)
    }

    public func listOutputDevices() throws -> [AudioDevice] {
        try client.devices().filter { $0.kind == .output }
    }

    public func routeSourceToDevice(sourceID: String, deviceID: String?) throws {
        // TODO: Public macOS APIs do not provide direct arbitrary per-app output-device routing.
        // Real routing requires owning app render streams through a virtual audio driver or AudioServerPlugIn.
        throw AudioRoutingBackendError.unsupported("True per-app routing requires an audio routing driver.")
    }

    public func setSourceVolume(sourceID: String, volume: Double) throws {
        // TODO: Public APIs do not expose direct per-app output gain for arbitrary apps.
        throw AudioRoutingBackendError.unsupported("Per-app volume requires an audio routing driver.")
    }

    public func muteSource(sourceID: String, muted: Bool) throws {
        // TODO: Public APIs do not expose direct per-app mute for arbitrary apps.
        throw AudioRoutingBackendError.unsupported("Per-app mute requires an audio routing driver.")
    }

    private func fallbackSources() -> [AudioSource] {
        NSWorkspace.shared.runningApplications
            .filter { $0.activationPolicy == .regular }
            .prefix(8)
            .map { app in
                AudioSource(
                    id: app.bundleIdentifier ?? "pid-\(app.processIdentifier)",
                    appName: app.localizedName ?? "App \(app.processIdentifier)",
                    bundleIdentifier: app.bundleIdentifier,
                    processID: app.processIdentifier,
                    icon: app.bundleURL?.path,
                    isProducingAudio: false
                )
            }
    }

    private func withSystemSoundsSource(_ sources: [AudioSource]) -> [AudioSource] {
        guard !sources.contains(where: { $0.id == "system-sounds" }) else {
            return sources
        }
        let systemSounds = AudioSource(
            id: "system-sounds",
            appName: "System Sounds",
            bundleIdentifier: "com.apple.systemsounds",
            processID: 0,
            icon: nil,
            isProducingAudio: false
        )
        return [systemSounds] + sources
    }
}
