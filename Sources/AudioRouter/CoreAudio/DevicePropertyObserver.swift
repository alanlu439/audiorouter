import CoreAudio
import Dispatch
import Foundation

public final class DevicePropertyObservation {
    private let lock = NSLock()
    private var cancelHandler: (() -> Void)?

    init(cancelHandler: @escaping () -> Void) {
        self.cancelHandler = cancelHandler
    }

    public func cancel() {
        lock.lock()
        let handler = cancelHandler
        cancelHandler = nil
        lock.unlock()
        handler?()
    }

    deinit {
        cancel()
    }
}

final class DevicePropertyObserver {
    private let queue = DispatchQueue(label: "com.local.AudioRouter.device-observer")
    private let systemObject = AudioObjectID(kAudioObjectSystemObject)
    private var registrations: [(AudioObjectPropertyAddress, AudioObjectPropertyListenerBlock)] = []
    private let onChange: @Sendable () -> Void

    init(onChange: @escaping @Sendable () -> Void) {
        self.onChange = onChange
    }

    func start() throws -> DevicePropertyObservation {
        let selectors: [AudioObjectPropertySelector] = [
            kAudioHardwarePropertyDevices,
            kAudioHardwarePropertyDefaultOutputDevice,
            kAudioHardwarePropertyDefaultInputDevice,
            kAudioHardwarePropertyDefaultSystemOutputDevice
        ]

        for selector in selectors {
            var address = AudioObjectPropertyAddress(
                mSelector: selector,
                mScope: kAudioObjectPropertyScopeGlobal,
                mElement: kAudioObjectPropertyElementMain
            )
            let listener: AudioObjectPropertyListenerBlock = { [onChange] _, _ in
                onChange()
            }
            let status = AudioObjectAddPropertyListenerBlock(systemObject, &address, queue, listener)
            guard status == noErr else {
                stop()
                throw AudioRouterError.coreAudio("Observe CoreAudio hardware property changes", status)
            }
            registrations.append((address, listener))
        }

        return DevicePropertyObservation { [self] in
            self.stop()
        }
    }

    private func stop() {
        for registration in registrations {
            var address = registration.0
            AudioObjectRemovePropertyListenerBlock(systemObject, &address, queue, registration.1)
        }
        registrations.removeAll()
    }

    deinit {
        stop()
    }
}
