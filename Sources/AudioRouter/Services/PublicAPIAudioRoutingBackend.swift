import AppKit
import Foundation

public final class PublicAPIAudioRoutingBackend: AudioRoutingBackend {
    public let supportsPerAppRouting = false
    public let backendName = "Public macOS APIs"

    private let client: CoreAudioClient
    private let processMonitor: ProcessAudioMonitor

    public convenience init() {
        self.init(client: CoreAudioClient(), processMonitor: ProcessAudioMonitor())
    }

    init(client: CoreAudioClient, processMonitor: ProcessAudioMonitor = ProcessAudioMonitor()) {
        self.client = client
        self.processMonitor = processMonitor
    }

    public func listAudioSources() throws -> [AudioSource] {
        processMonitor.snapshot().sources
    }

    public func listOutputDevices() throws -> [AudioDevice] {
        try client.devices().filter { $0.kind == .output }
    }

    public func routeSourceToDevice(sourceID: String, deviceID: String?) throws {
        // TODO: Public macOS APIs do not provide direct arbitrary per-app output-device routing.
        // Real routing requires owning app render streams through a virtual audio driver or AudioServerPlugIn.
        throw AudioRoutingBackendError.unsupported("True per-app routing requires an audio routing backend.")
    }

    public func setSourceVolume(sourceID: String, volume: Double) throws {
        // TODO: Public APIs do not expose direct per-app output gain for arbitrary apps.
        throw AudioRoutingBackendError.unsupported("Per-app volume requires an audio routing backend.")
    }

    public func muteSource(sourceID: String, muted: Bool) throws {
        // TODO: Public APIs do not expose direct per-app mute for arbitrary apps.
        throw AudioRoutingBackendError.unsupported("Per-app mute requires an audio routing backend.")
    }
}
