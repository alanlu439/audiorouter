import Foundation

public typealias AudioOutputDevice = AudioDevice

public extension AudioDevice {
    var type: AudioTransport { transport }
    var isConnected: Bool { isAlive }
    var supportsVolume: Bool { canSetVolume }
    var supportsMute: Bool { canSetMute }
    var supportsBalance: Bool { canSetBalance }
}
