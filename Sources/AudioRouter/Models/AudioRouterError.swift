import Foundation

public enum AudioRouterError: LocalizedError, Equatable {
    case missingDevice
    case unsupportedControl(String)
    case coreAudio(String, Int32)
    case persistence(String)

    public var errorDescription: String? {
        switch self {
        case .missingDevice:
            return "That audio device is no longer available."
        case let .unsupportedControl(control):
            return "\(control) is not supported by this device through public macOS audio APIs."
        case let .coreAudio(operation, status):
            return "\(operation) failed with OSStatus \(status)."
        case let .persistence(message):
            return message
        }
    }
}
