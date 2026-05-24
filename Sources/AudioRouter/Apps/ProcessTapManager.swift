import CoreAudio
import Foundation

public enum ProcessTapProbeStatus: Codable, Equatable {
    case unavailable(String)
    case permissionDenied(String)
    case tapCreated
}

public struct ProcessTapProbeResult: Codable, Equatable {
    public let status: ProcessTapProbeStatus
    public let message: String

    public init(status: ProcessTapProbeStatus, message: String) {
        self.status = status
        self.message = message
    }
}

public final class ProcessTapManager {
    public init() {}

    public var isSupportedOnThisOS: Bool {
        if #available(macOS 14.2, *) {
            return true
        }
        return false
    }

    public func probeProcessTap(for processObjectID: UInt32) -> ProcessTapProbeResult {
        guard isSupportedOnThisOS else {
            return ProcessTapProbeResult(
                status: .unavailable("Process taps require macOS 14.2 or newer."),
                message: "Process taps require macOS 14.2 or newer."
            )
        }

        if #available(macOS 14.2, *) {
            let description = CATapDescription(stereoMixdownOfProcesses: [AudioObjectID(processObjectID)])
            description.name = "AudioRouter Process Tap Probe"
            description.isPrivate = true
            description.muteBehavior = .unmuted

            var tapID = AudioObjectID(kAudioObjectUnknown)
            let status = AudioHardwareCreateProcessTap(description, &tapID)
            if status == noErr {
                AudioHardwareDestroyProcessTap(tapID)
                return ProcessTapProbeResult(
                    status: .tapCreated,
                    message: "Process tap permission is available. Full level metering still needs aggregate-device IO plumbing."
                )
            }

            if status == kAudioHardwareIllegalOperationError {
                return ProcessTapProbeResult(
                    status: .permissionDenied("System Audio Recording permission was denied or has not been granted."),
                    message: "macOS denied process-tap capture. Grant AudioRouter system audio recording permission in System Settings, then try again."
                )
            }

            return ProcessTapProbeResult(
                status: .unavailable("Process tap probe failed with OSStatus \(status)."),
                message: "Process tap probe failed with OSStatus \(status)."
            )
        }

        return ProcessTapProbeResult(
            status: .unavailable("Process taps are unavailable on this OS."),
            message: "Process taps are unavailable on this OS."
        )
    }
}
