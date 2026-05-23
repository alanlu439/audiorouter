import Foundation

public final class VirtualDriverAudioRoutingBackend: AudioRoutingBackend {
    public let supportsPerAppRouting = true
    public let backendName = "Virtual audio driver"

    public init() {}

    public func listAudioSources() throws -> [AudioSource] {
        // TODO: A real implementation would enumerate streams owned by the virtual driver.
        []
    }

    public func listOutputDevices() throws -> [AudioDevice] {
        // TODO: The driver-backed backend would share CoreAudio device discovery with the public backend.
        []
    }

    public func routeSourceToDevice(sourceID: String, deviceID: String?) throws {
        // TODO: Connect the source stream to the selected physical output and prevent duplicate system playback.
    }

    public func setSourceVolume(sourceID: String, volume: Double) throws {
        // TODO: Apply gain inside the driver/audio engine before rendering to the target device.
    }

    public func muteSource(sourceID: String, muted: Bool) throws {
        // TODO: Mute the driver-owned source stream.
    }
}
