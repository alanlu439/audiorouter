import Foundation

public final class FutureRoutingPluginBackend: AudioRoutingBackend {
    public let supportsPerAppRouting = true
    public let supportsPerAppVolume = true
    public let supportsPerAppMute = true
    public let supportsLiveProcessMeters = true
    public let backendName = "Future Routing Plugin"

    public init() {}

    public func listAudioSources() throws -> [AudioSource] {
        // TODO: Enumerate source streams owned by an Audio Server Driver Plug-in or virtual audio device.
        []
    }

    public func listOutputDevices() throws -> [AudioDevice] {
        // TODO: Share CoreAudio hardware discovery with AudioDeviceService.
        []
    }

    public func routeSourceToDevice(sourceID: String, deviceID: String?) throws {
        // TODO: Connect a captured app stream to a physical output renderer with low-latency buffering.
    }

    public func setSourceVolume(sourceID: String, volume: Double) throws {
        // TODO: Apply gain inside the audio graph before the selected output render path.
    }

    public func muteSource(sourceID: String, muted: Bool) throws {
        // TODO: Gate or zero the app stream inside the backend audio graph.
    }
}
