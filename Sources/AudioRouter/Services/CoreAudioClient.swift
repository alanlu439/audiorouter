import AppKit
import CoreAudio
import Foundation

final class CoreAudioClient {
    func devices() throws -> [AudioDevice] {
        let deviceIDs = try objectIDArray(
            objectID: AudioObjectID(kAudioObjectSystemObject),
            selector: kAudioHardwarePropertyDevices
        )
        let defaultOutput = try? objectID(
            objectID: AudioObjectID(kAudioObjectSystemObject),
            selector: kAudioHardwarePropertyDefaultOutputDevice
        )
        let defaultInput = try? objectID(
            objectID: AudioObjectID(kAudioObjectSystemObject),
            selector: kAudioHardwarePropertyDefaultInputDevice
        )

        var devices: [AudioDevice] = []
        for deviceID in deviceIDs {
            let uid = (try? stringProperty(deviceID, selector: kAudioDevicePropertyDeviceUID)) ?? "device-\(deviceID)"
            let name = (try? stringProperty(deviceID, selector: kAudioObjectPropertyName)) ?? "Audio Device \(deviceID)"
            let transportValue = (try? uint32Property(deviceID, selector: kAudioDevicePropertyTransportType)) ?? 0
            let alive = ((try? uint32Property(deviceID, selector: kAudioDevicePropertyDeviceIsAlive)) ?? 1) != 0
            let transport = transport(from: transportValue)

            let outputChannels = (try? channelCount(deviceID: deviceID, scope: kAudioDevicePropertyScopeOutput)) ?? 0
            if outputChannels > 0 {
                devices.append(makeDevice(
                    deviceID: deviceID,
                    uid: uid,
                    name: name,
                    kind: .output,
                    channelCount: outputChannels,
                    transport: transport,
                    isDefault: defaultOutput == deviceID,
                    isAlive: alive
                ))
            }

            let inputChannels = (try? channelCount(deviceID: deviceID, scope: kAudioDevicePropertyScopeInput)) ?? 0
            if inputChannels > 0 {
                devices.append(makeDevice(
                    deviceID: deviceID,
                    uid: uid,
                    name: name,
                    kind: .input,
                    channelCount: inputChannels,
                    transport: transport,
                    isDefault: defaultInput == deviceID,
                    isAlive: alive
                ))
            }
        }

        return devices.sorted { lhs, rhs in
            if lhs.kind != rhs.kind {
                return lhs.kind == .output
            }
            if lhs.isDefault != rhs.isDefault {
                return lhs.isDefault
            }
            return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
        }
    }

    func audioAppSessions() throws -> [AudioAppSession] {
        let processIDs = try objectIDArray(
            objectID: AudioObjectID(kAudioObjectSystemObject),
            selector: kAudioHardwarePropertyProcessObjectList
        )

        return processIDs.compactMap { processID in
            guard let pid = try? pidProperty(processID, selector: kAudioProcessPropertyPID) else {
                return nil
            }
            let bundleID = (try? stringProperty(processID, selector: kAudioProcessPropertyBundleID))
                .flatMap { $0.isEmpty ? nil : $0 }
            let runningApp = NSRunningApplication(processIdentifier: pid)
            let name = runningApp?.localizedName
                ?? bundleID?.split(separator: ".").last.map(String.init)
                ?? "Process \(pid)"
            let isRunningOutput = ((try? uint32Property(processID, selector: kAudioProcessPropertyIsRunningOutput)) ?? 0) != 0
            let devices = (try? objectIDArray(
                objectID: processID,
                selector: kAudioProcessPropertyDevices,
                scope: kAudioObjectPropertyScopeOutput
            )) ?? []
            guard isRunningOutput || !devices.isEmpty else {
                return nil
            }

            return AudioAppSession(
                id: bundleID ?? "pid-\(pid)",
                pid: pid,
                bundleID: bundleID,
                displayName: name,
                iconPath: runningApp?.bundleURL?.path,
                isProducingAudio: isRunningOutput
            )
        }
        .sorted { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }
    }

    func setDefaultDevice(uid: String, kind: AudioDeviceKind) throws {
        let deviceID = try deviceID(for: uid)
        let selector: AudioObjectPropertySelector = kind == .output
            ? kAudioHardwarePropertyDefaultOutputDevice
            : kAudioHardwarePropertyDefaultInputDevice
        var address = propertyAddress(selector: selector)
        var mutableID = deviceID
        try check(
            AudioObjectSetPropertyData(
                AudioObjectID(kAudioObjectSystemObject),
                &address,
                0,
                nil,
                UInt32(MemoryLayout<AudioObjectID>.size),
                &mutableID
            ),
            "Set default \(kind.rawValue) device"
        )

        if kind == .output {
            var systemAddress = propertyAddress(selector: kAudioHardwarePropertyDefaultSystemOutputDevice)
            try check(
                AudioObjectSetPropertyData(
                    AudioObjectID(kAudioObjectSystemObject),
                    &systemAddress,
                    0,
                    nil,
                    UInt32(MemoryLayout<AudioObjectID>.size),
                    &mutableID
                ),
                "Set default system output device"
            )
        }
    }

    func setVolume(uid: String, kind: AudioDeviceKind, volume: Double) throws {
        let deviceID = try deviceID(for: uid)
        let scope = scope(for: kind)
        let clamped = Float32(volume.clampedUnit)
        if isSettable(deviceID, selector: kAudioDevicePropertyVolumeScalar, scope: scope) {
            try setFloat32Property(deviceID, selector: kAudioDevicePropertyVolumeScalar, scope: scope, value: clamped)
            return
        }

        let channels = max(1, try channelCount(deviceID: deviceID, scope: scope))
        var didSetChannel = false
        for channel in 1...channels where isSettable(
            deviceID,
            selector: kAudioDevicePropertyVolumeScalar,
            scope: scope,
            element: AudioObjectPropertyElement(channel)
        ) {
            try setFloat32Property(
                deviceID,
                selector: kAudioDevicePropertyVolumeScalar,
                scope: scope,
                element: AudioObjectPropertyElement(channel),
                value: clamped
            )
            didSetChannel = true
        }

        if !didSetChannel {
            throw AudioRouterError.unsupportedControl("\(kind.title) volume")
        }
    }

    func setMuted(uid: String, kind: AudioDeviceKind, isMuted: Bool) throws {
        let deviceID = try deviceID(for: uid)
        let scope = scope(for: kind)
        guard isSettable(deviceID, selector: kAudioDevicePropertyMute, scope: scope) else {
            throw AudioRouterError.unsupportedControl("\(kind.title) mute")
        }
        try setUInt32Property(
            deviceID,
            selector: kAudioDevicePropertyMute,
            scope: scope,
            value: isMuted ? 1 : 0
        )
    }

    func setBalance(uid: String, kind: AudioDeviceKind, balance: Double) throws {
        let deviceID = try deviceID(for: uid)
        let scope = scope(for: kind)
        guard canSetBalance(deviceID: deviceID, scope: scope) else {
            throw AudioRouterError.unsupportedControl("\(kind.title) balance")
        }

        let left = (try? float32Property(
            deviceID,
            selector: kAudioDevicePropertyVolumeScalar,
            scope: scope,
            element: 1
        )) ?? 0.5
        let right = (try? float32Property(
            deviceID,
            selector: kAudioDevicePropertyVolumeScalar,
            scope: scope,
            element: 2
        )) ?? 0.5
        let base = max(0.05, min(1, Double(max(left, right))))
        let clamped = balance.clampedBalance
        let leftValue = Float32(clamped > 0 ? base * (1 - clamped) : base)
        let rightValue = Float32(clamped < 0 ? base * (1 + clamped) : base)

        try setFloat32Property(
            deviceID,
            selector: kAudioDevicePropertyVolumeScalar,
            scope: scope,
            element: 1,
            value: leftValue
        )
        try setFloat32Property(
            deviceID,
            selector: kAudioDevicePropertyVolumeScalar,
            scope: scope,
            element: 2,
            value: rightValue
        )
    }

    private func makeDevice(
        deviceID: AudioObjectID,
        uid: String,
        name: String,
        kind: AudioDeviceKind,
        channelCount: Int,
        transport: AudioTransport,
        isDefault: Bool,
        isAlive: Bool
    ) -> AudioDevice {
        let scope = scope(for: kind)
        return AudioDevice(
            audioObjectID: deviceID,
            uid: uid,
            name: name,
            kind: kind,
            channelCount: channelCount,
            transport: transport,
            isDefault: isDefault,
            isAlive: isAlive,
            volume: volume(deviceID: deviceID, scope: scope, channelCount: channelCount),
            isMuted: isMuted(deviceID: deviceID, scope: scope),
            balance: balance(deviceID: deviceID, scope: scope),
            canSetVolume: canSetVolume(deviceID: deviceID, scope: scope, channelCount: channelCount),
            canSetMute: isSettable(deviceID, selector: kAudioDevicePropertyMute, scope: scope),
            canSetBalance: canSetBalance(deviceID: deviceID, scope: scope)
        )
    }

    private func scope(for kind: AudioDeviceKind) -> AudioObjectPropertyScope {
        kind == .output ? kAudioDevicePropertyScopeOutput : kAudioDevicePropertyScopeInput
    }

    private func objectID(
        objectID: AudioObjectID,
        selector: AudioObjectPropertySelector,
        scope: AudioObjectPropertyScope = kAudioObjectPropertyScopeGlobal
    ) throws -> AudioObjectID {
        var address = propertyAddress(selector: selector, scope: scope)
        var value = AudioObjectID(kAudioObjectUnknown)
        var size = UInt32(MemoryLayout<AudioObjectID>.size)
        try check(AudioObjectGetPropertyData(objectID, &address, 0, nil, &size, &value), "Read CoreAudio object id")
        return value
    }

    private func objectIDArray(
        objectID: AudioObjectID,
        selector: AudioObjectPropertySelector,
        scope: AudioObjectPropertyScope = kAudioObjectPropertyScopeGlobal
    ) throws -> [AudioObjectID] {
        var address = propertyAddress(selector: selector, scope: scope)
        var size: UInt32 = 0
        try check(AudioObjectGetPropertyDataSize(objectID, &address, 0, nil, &size), "Read CoreAudio object array size")
        guard size > 0 else { return [] }

        let count = Int(size) / MemoryLayout<AudioObjectID>.stride
        var values = Array(repeating: AudioObjectID(kAudioObjectUnknown), count: count)
        try check(AudioObjectGetPropertyData(objectID, &address, 0, nil, &size, &values), "Read CoreAudio object array")
        return values.filter { $0 != AudioObjectID(kAudioObjectUnknown) }
    }

    private func deviceID(for uid: String) throws -> AudioObjectID {
        for deviceID in try objectIDArray(objectID: AudioObjectID(kAudioObjectSystemObject), selector: kAudioHardwarePropertyDevices) {
            if (try? stringProperty(deviceID, selector: kAudioDevicePropertyDeviceUID)) == uid {
                return deviceID
            }
        }
        throw AudioRouterError.missingDevice
    }

    private func stringProperty(
        _ objectID: AudioObjectID,
        selector: AudioObjectPropertySelector,
        scope: AudioObjectPropertyScope = kAudioObjectPropertyScopeGlobal
    ) throws -> String {
        var address = propertyAddress(selector: selector, scope: scope)
        var value: CFString = "" as CFString
        var size = UInt32(MemoryLayout<CFString>.size)
        try check(withUnsafeMutablePointer(to: &value) { pointer in
            AudioObjectGetPropertyData(objectID, &address, 0, nil, &size, pointer)
        }, "Read CoreAudio string property")
        return value as String
    }

    private func uint32Property(
        _ objectID: AudioObjectID,
        selector: AudioObjectPropertySelector,
        scope: AudioObjectPropertyScope = kAudioObjectPropertyScopeGlobal
    ) throws -> UInt32 {
        var address = propertyAddress(selector: selector, scope: scope)
        var value: UInt32 = 0
        var size = UInt32(MemoryLayout<UInt32>.size)
        try check(AudioObjectGetPropertyData(objectID, &address, 0, nil, &size, &value), "Read CoreAudio UInt32 property")
        return value
    }

    private func float32Property(
        _ objectID: AudioObjectID,
        selector: AudioObjectPropertySelector,
        scope: AudioObjectPropertyScope,
        element: AudioObjectPropertyElement = kAudioObjectPropertyElementMain
    ) throws -> Float32 {
        var address = propertyAddress(selector: selector, scope: scope, element: element)
        var value: Float32 = 0
        var size = UInt32(MemoryLayout<Float32>.size)
        try check(AudioObjectGetPropertyData(objectID, &address, 0, nil, &size, &value), "Read CoreAudio Float32 property")
        return value
    }

    private func setFloat32Property(
        _ objectID: AudioObjectID,
        selector: AudioObjectPropertySelector,
        scope: AudioObjectPropertyScope,
        element: AudioObjectPropertyElement = kAudioObjectPropertyElementMain,
        value: Float32
    ) throws {
        var address = propertyAddress(selector: selector, scope: scope, element: element)
        var mutableValue = value
        try check(AudioObjectSetPropertyData(
            objectID,
            &address,
            0,
            nil,
            UInt32(MemoryLayout<Float32>.size),
            &mutableValue
        ), "Write CoreAudio Float32 property")
    }

    private func setUInt32Property(
        _ objectID: AudioObjectID,
        selector: AudioObjectPropertySelector,
        scope: AudioObjectPropertyScope,
        element: AudioObjectPropertyElement = kAudioObjectPropertyElementMain,
        value: UInt32
    ) throws {
        var address = propertyAddress(selector: selector, scope: scope, element: element)
        var mutableValue = value
        try check(AudioObjectSetPropertyData(
            objectID,
            &address,
            0,
            nil,
            UInt32(MemoryLayout<UInt32>.size),
            &mutableValue
        ), "Write CoreAudio UInt32 property")
    }

    private func pidProperty(_ objectID: AudioObjectID, selector: AudioObjectPropertySelector) throws -> pid_t {
        var address = propertyAddress(selector: selector)
        var value = pid_t(0)
        var size = UInt32(MemoryLayout<pid_t>.size)
        try check(AudioObjectGetPropertyData(objectID, &address, 0, nil, &size, &value), "Read CoreAudio PID property")
        return value
    }

    private func channelCount(deviceID: AudioObjectID, scope: AudioObjectPropertyScope) throws -> Int {
        var address = propertyAddress(selector: kAudioDevicePropertyStreamConfiguration, scope: scope)
        var size: UInt32 = 0
        try check(AudioObjectGetPropertyDataSize(deviceID, &address, 0, nil, &size), "Read CoreAudio stream configuration size")
        guard size > 0 else { return 0 }

        let rawPointer = UnsafeMutableRawPointer.allocate(byteCount: Int(size), alignment: MemoryLayout<AudioBufferList>.alignment)
        defer { rawPointer.deallocate() }

        let bufferList = rawPointer.bindMemory(to: AudioBufferList.self, capacity: 1)
        try check(AudioObjectGetPropertyData(deviceID, &address, 0, nil, &size, bufferList), "Read CoreAudio stream configuration")
        return UnsafeMutableAudioBufferListPointer(bufferList).reduce(0) { $0 + Int($1.mNumberChannels) }
    }

    private func propertyAddress(
        selector: AudioObjectPropertySelector,
        scope: AudioObjectPropertyScope = kAudioObjectPropertyScopeGlobal,
        element: AudioObjectPropertyElement = kAudioObjectPropertyElementMain
    ) -> AudioObjectPropertyAddress {
        AudioObjectPropertyAddress(mSelector: selector, mScope: scope, mElement: element)
    }

    private func hasProperty(
        _ objectID: AudioObjectID,
        selector: AudioObjectPropertySelector,
        scope: AudioObjectPropertyScope,
        element: AudioObjectPropertyElement = kAudioObjectPropertyElementMain
    ) -> Bool {
        var address = propertyAddress(selector: selector, scope: scope, element: element)
        return AudioObjectHasProperty(objectID, &address)
    }

    private func isSettable(
        _ objectID: AudioObjectID,
        selector: AudioObjectPropertySelector,
        scope: AudioObjectPropertyScope,
        element: AudioObjectPropertyElement = kAudioObjectPropertyElementMain
    ) -> Bool {
        var address = propertyAddress(selector: selector, scope: scope, element: element)
        var settable: DarwinBoolean = false
        let status = AudioObjectIsPropertySettable(objectID, &address, &settable)
        return status == noErr && settable.boolValue
    }

    private func volume(deviceID: AudioObjectID, scope: AudioObjectPropertyScope, channelCount: Int) -> Double? {
        if hasProperty(deviceID, selector: kAudioDevicePropertyVolumeScalar, scope: scope),
           let volume = try? float32Property(deviceID, selector: kAudioDevicePropertyVolumeScalar, scope: scope) {
            return Double(max(0, min(volume, 1)))
        }

        let values = (1...max(1, channelCount)).compactMap { channel -> Float32? in
            guard hasProperty(deviceID, selector: kAudioDevicePropertyVolumeScalar, scope: scope, element: AudioObjectPropertyElement(channel)) else {
                return nil
            }
            return try? float32Property(
                deviceID,
                selector: kAudioDevicePropertyVolumeScalar,
                scope: scope,
                element: AudioObjectPropertyElement(channel)
            )
        }
        guard !values.isEmpty else { return nil }
        return Double(values.reduce(0, +) / Float32(values.count)).clampedUnit
    }

    private func isMuted(deviceID: AudioObjectID, scope: AudioObjectPropertyScope) -> Bool? {
        guard hasProperty(deviceID, selector: kAudioDevicePropertyMute, scope: scope) else {
            return nil
        }
        return ((try? uint32Property(deviceID, selector: kAudioDevicePropertyMute, scope: scope)) ?? 0) != 0
    }

    private func balance(deviceID: AudioObjectID, scope: AudioObjectPropertyScope) -> Double? {
        guard canSetBalance(deviceID: deviceID, scope: scope),
              let left = try? float32Property(deviceID, selector: kAudioDevicePropertyVolumeScalar, scope: scope, element: 1),
              let right = try? float32Property(deviceID, selector: kAudioDevicePropertyVolumeScalar, scope: scope, element: 2) else {
            return nil
        }
        let maxVolume = max(left, right)
        guard maxVolume > 0 else { return 0 }
        return Double((right - left) / maxVolume).clampedBalance
    }

    private func canSetVolume(deviceID: AudioObjectID, scope: AudioObjectPropertyScope, channelCount: Int) -> Bool {
        if isSettable(deviceID, selector: kAudioDevicePropertyVolumeScalar, scope: scope) {
            return true
        }
        return (1...max(1, channelCount)).contains { channel in
            isSettable(
                deviceID,
                selector: kAudioDevicePropertyVolumeScalar,
                scope: scope,
                element: AudioObjectPropertyElement(channel)
            )
        }
    }

    private func canSetBalance(deviceID: AudioObjectID, scope: AudioObjectPropertyScope) -> Bool {
        isSettable(deviceID, selector: kAudioDevicePropertyVolumeScalar, scope: scope, element: 1)
            && isSettable(deviceID, selector: kAudioDevicePropertyVolumeScalar, scope: scope, element: 2)
    }

    private func transport(from value: UInt32) -> AudioTransport {
        switch value {
        case kAudioDeviceTransportTypeBuiltIn: return .builtIn
        case kAudioDeviceTransportTypeBluetooth: return .bluetooth
        case kAudioDeviceTransportTypeBluetoothLE: return .bluetoothLE
        case kAudioDeviceTransportTypeUSB: return .usb
        case kAudioDeviceTransportTypeHDMI: return .hdmi
        case kAudioDeviceTransportTypeDisplayPort: return .displayPort
        case kAudioDeviceTransportTypeAirPlay: return .airPlay
        case kAudioDeviceTransportTypeAggregate: return .aggregate
        case kAudioDeviceTransportTypeVirtual: return .virtual
        case kAudioDeviceTransportTypeThunderbolt: return .thunderbolt
        default: return .unknown
        }
    }

    private func check(_ status: OSStatus, _ operation: String) throws {
        guard status == noErr else {
            throw AudioRouterError.coreAudio(operation, status)
        }
    }
}
