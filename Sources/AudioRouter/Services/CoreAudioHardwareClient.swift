import AppKit
import CoreAudio
import Foundation

final class CoreAudioHardwareClient {
    func outputDevices() throws -> [AudioDeviceInfo] {
        let deviceIDs = try objectIDArray(
            objectID: AudioObjectID(kAudioObjectSystemObject),
            selector: kAudioHardwarePropertyDevices
        )
        let defaultOutput = try? objectID(
            objectID: AudioObjectID(kAudioObjectSystemObject),
            selector: kAudioHardwarePropertyDefaultOutputDevice
        )

        return deviceIDs.compactMap { deviceID in
            do {
                let channels = try channelCount(deviceID: deviceID, scope: kAudioDevicePropertyScopeOutput)
                guard channels > 0 else { return nil }
                let uid = try stringProperty(deviceID, selector: kAudioDevicePropertyDeviceUID)
                let name = (try? stringProperty(deviceID, selector: kAudioObjectPropertyName)) ?? "Output \(deviceID)"
                let transportValue = (try? uint32Property(deviceID, selector: kAudioDevicePropertyTransportType)) ?? 0
                let alive = ((try? uint32Property(deviceID, selector: kAudioDevicePropertyDeviceIsAlive)) ?? 1) != 0
                let volume = outputVolume(deviceID: deviceID, channelCount: channels)
                let muted = isMuted(deviceID: deviceID)

                return AudioDeviceInfo(
                    audioObjectID: deviceID,
                    uid: uid,
                    name: name,
                    outputChannelCount: channels,
                    transport: transport(from: transportValue),
                    isDefaultOutput: defaultOutput == deviceID,
                    isAlive: alive,
                    outputVolume: volume,
                    isMuted: muted,
                    canSetVolume: canSetOutputVolume(deviceID: deviceID, channelCount: channels),
                    canSetMute: canSetMute(deviceID: deviceID)
                )
            } catch {
                return nil
            }
        }
        .sorted { lhs, rhs in
            if lhs.isDefaultOutput != rhs.isDefaultOutput {
                return lhs.isDefaultOutput
            }
            return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
        }
    }

    func audioProcesses() throws -> [AudioProcessInfo] {
        let processIDs = try objectIDArray(
            objectID: AudioObjectID(kAudioObjectSystemObject),
            selector: kAudioHardwarePropertyProcessObjectList
        )

        return processIDs.compactMap { processID in
            do {
                let pid = try pidProperty(processID, selector: kAudioProcessPropertyPID)
                let bundleID = try? stringProperty(processID, selector: kAudioProcessPropertyBundleID)
                let isRunningOutput = ((try? uint32Property(processID, selector: kAudioProcessPropertyIsRunningOutput)) ?? 0) != 0
                let devices = (try? objectIDArray(
                    objectID: processID,
                    selector: kAudioProcessPropertyDevices,
                    scope: kAudioObjectPropertyScopeOutput
                )) ?? []

                let runningAppName = NSRunningApplication(processIdentifier: pid)?.localizedName
                let displayName = runningAppName
                    ?? bundleID?.split(separator: ".").last.map(String.init)
                    ?? "Process \(pid)"

                return AudioProcessInfo(
                    processObjectID: processID,
                    pid: pid,
                    bundleID: bundleID?.isEmpty == true ? nil : bundleID,
                    displayName: displayName,
                    isRunningOutput: isRunningOutput,
                    deviceObjectIDs: devices
                )
            } catch {
                return nil
            }
        }
        .filter { $0.isRunningOutput || !$0.deviceObjectIDs.isEmpty }
        .sorted { lhs, rhs in
            lhs.displayName.localizedCaseInsensitiveCompare(rhs.displayName) == .orderedAscending
        }
    }

    func setDefaultOutput(deviceUID: String) throws {
        let deviceID = try deviceID(for: deviceUID)
        var outputAddress = propertyAddress(selector: kAudioHardwarePropertyDefaultOutputDevice)
        var systemAddress = propertyAddress(selector: kAudioHardwarePropertyDefaultSystemOutputDevice)
        var mutableID = deviceID
        let size = UInt32(MemoryLayout<AudioObjectID>.size)
        try check(
            AudioObjectSetPropertyData(
                AudioObjectID(kAudioObjectSystemObject),
                &outputAddress,
                0,
                nil,
                size,
                &mutableID
            ),
            "Set default output device"
        )
        try check(
            AudioObjectSetPropertyData(
                AudioObjectID(kAudioObjectSystemObject),
                &systemAddress,
                0,
                nil,
                size,
                &mutableID
            ),
            "Set default system output device"
        )
    }

    func setOutputVolume(deviceUID: String, volume: Double) throws {
        let deviceID = try deviceID(for: deviceUID)
        let clamped = Float32(max(0, min(volume, 1)))
        if isSettable(deviceID, selector: kAudioDevicePropertyVolumeScalar, scope: kAudioDevicePropertyScopeOutput) {
            try setFloat32Property(
                deviceID,
                selector: kAudioDevicePropertyVolumeScalar,
                scope: kAudioDevicePropertyScopeOutput,
                value: clamped
            )
            return
        }

        let channels = max(1, try channelCount(deviceID: deviceID, scope: kAudioDevicePropertyScopeOutput))
        var didSetChannel = false
        for channel in 1...channels where isSettable(
            deviceID,
            selector: kAudioDevicePropertyVolumeScalar,
            scope: kAudioDevicePropertyScopeOutput,
            element: AudioObjectPropertyElement(channel)
        ) {
            try setFloat32Property(
                deviceID,
                selector: kAudioDevicePropertyVolumeScalar,
                scope: kAudioDevicePropertyScopeOutput,
                element: AudioObjectPropertyElement(channel),
                value: clamped
            )
            didSetChannel = true
        }

        if !didSetChannel {
            throw AudioRoutingError.coreAudio("Set output device volume", kAudioHardwareUnsupportedOperationError)
        }
    }

    func setMuted(deviceUID: String, isMuted: Bool) throws {
        let deviceID = try deviceID(for: deviceUID)
        guard isSettable(deviceID, selector: kAudioDevicePropertyMute, scope: kAudioDevicePropertyScopeOutput) else {
            throw AudioRoutingError.coreAudio("Set output device mute", kAudioHardwareUnsupportedOperationError)
        }
        try setUInt32Property(
            deviceID,
            selector: kAudioDevicePropertyMute,
            scope: kAudioDevicePropertyScopeOutput,
            value: isMuted ? 1 : 0
        )
    }

    private func objectID(
        objectID: AudioObjectID,
        selector: AudioObjectPropertySelector,
        scope: AudioObjectPropertyScope = kAudioObjectPropertyScopeGlobal
    ) throws -> AudioObjectID {
        var address = propertyAddress(selector: selector, scope: scope)
        var value = AudioObjectID(kAudioObjectUnknown)
        var size = UInt32(MemoryLayout<AudioObjectID>.size)
        let status = AudioObjectGetPropertyData(objectID, &address, 0, nil, &size, &value)
        try check(status, "Read CoreAudio object id")
        return value
    }

    private func objectIDArray(
        objectID: AudioObjectID,
        selector: AudioObjectPropertySelector,
        scope: AudioObjectPropertyScope = kAudioObjectPropertyScopeGlobal
    ) throws -> [AudioObjectID] {
        var address = propertyAddress(selector: selector, scope: scope)
        var size: UInt32 = 0
        let sizeStatus = AudioObjectGetPropertyDataSize(objectID, &address, 0, nil, &size)
        try check(sizeStatus, "Read CoreAudio object array size")
        guard size > 0 else { return [] }

        let count = Int(size) / MemoryLayout<AudioObjectID>.stride
        var values = Array(repeating: AudioObjectID(kAudioObjectUnknown), count: count)
        let dataStatus = AudioObjectGetPropertyData(objectID, &address, 0, nil, &size, &values)
        try check(dataStatus, "Read CoreAudio object array")
        return values.filter { $0 != AudioObjectID(kAudioObjectUnknown) }
    }

    private func deviceID(for uid: String) throws -> AudioObjectID {
        let deviceIDs = try objectIDArray(
            objectID: AudioObjectID(kAudioObjectSystemObject),
            selector: kAudioHardwarePropertyDevices
        )

        for deviceID in deviceIDs {
            if (try? stringProperty(deviceID, selector: kAudioDevicePropertyDeviceUID)) == uid {
                return deviceID
            }
        }
        throw AudioRoutingError.missingDevice
    }

    private func stringProperty(
        _ objectID: AudioObjectID,
        selector: AudioObjectPropertySelector,
        scope: AudioObjectPropertyScope = kAudioObjectPropertyScopeGlobal
    ) throws -> String {
        var address = propertyAddress(selector: selector, scope: scope)
        var value: CFString = "" as CFString
        var size = UInt32(MemoryLayout<CFString>.size)
        let status = withUnsafeMutablePointer(to: &value) { pointer in
            AudioObjectGetPropertyData(objectID, &address, 0, nil, &size, pointer)
        }
        try check(status, "Read CoreAudio string property")
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
        let status = AudioObjectGetPropertyData(objectID, &address, 0, nil, &size, &value)
        try check(status, "Read CoreAudio UInt32 property")
        return value
    }

    private func float32Property(
        _ objectID: AudioObjectID,
        selector: AudioObjectPropertySelector,
        scope: AudioObjectPropertyScope = kAudioObjectPropertyScopeGlobal,
        element: AudioObjectPropertyElement = kAudioObjectPropertyElementMain
    ) throws -> Float32 {
        var address = propertyAddress(selector: selector, scope: scope, element: element)
        var value: Float32 = 0
        var size = UInt32(MemoryLayout<Float32>.size)
        let status = AudioObjectGetPropertyData(objectID, &address, 0, nil, &size, &value)
        try check(status, "Read CoreAudio Float32 property")
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
        let status = AudioObjectSetPropertyData(
            objectID,
            &address,
            0,
            nil,
            UInt32(MemoryLayout<Float32>.size),
            &mutableValue
        )
        try check(status, "Write CoreAudio Float32 property")
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
        let status = AudioObjectSetPropertyData(
            objectID,
            &address,
            0,
            nil,
            UInt32(MemoryLayout<UInt32>.size),
            &mutableValue
        )
        try check(status, "Write CoreAudio UInt32 property")
    }

    private func pidProperty(
        _ objectID: AudioObjectID,
        selector: AudioObjectPropertySelector
    ) throws -> pid_t {
        var address = propertyAddress(selector: selector, scope: kAudioObjectPropertyScopeGlobal)
        var value = pid_t(0)
        var size = UInt32(MemoryLayout<pid_t>.size)
        let status = AudioObjectGetPropertyData(objectID, &address, 0, nil, &size, &value)
        try check(status, "Read CoreAudio PID property")
        return value
    }

    private func channelCount(
        deviceID: AudioObjectID,
        scope: AudioObjectPropertyScope
    ) throws -> Int {
        var address = propertyAddress(selector: kAudioDevicePropertyStreamConfiguration, scope: scope)
        var size: UInt32 = 0
        let sizeStatus = AudioObjectGetPropertyDataSize(deviceID, &address, 0, nil, &size)
        try check(sizeStatus, "Read CoreAudio stream configuration size")
        guard size > 0 else { return 0 }

        let rawPointer = UnsafeMutableRawPointer.allocate(
            byteCount: Int(size),
            alignment: MemoryLayout<AudioBufferList>.alignment
        )
        defer { rawPointer.deallocate() }

        let bufferList = rawPointer.bindMemory(to: AudioBufferList.self, capacity: 1)
        let dataStatus = AudioObjectGetPropertyData(deviceID, &address, 0, nil, &size, bufferList)
        try check(dataStatus, "Read CoreAudio stream configuration")

        return UnsafeMutableAudioBufferListPointer(bufferList)
            .reduce(0) { $0 + Int($1.mNumberChannels) }
    }

    private func propertyAddress(
        selector: AudioObjectPropertySelector,
        scope: AudioObjectPropertyScope = kAudioObjectPropertyScopeGlobal,
        element: AudioObjectPropertyElement = kAudioObjectPropertyElementMain
    ) -> AudioObjectPropertyAddress {
        AudioObjectPropertyAddress(
            mSelector: selector,
            mScope: scope,
            mElement: element
        )
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
        var isSettable: DarwinBoolean = false
        let status = AudioObjectIsPropertySettable(objectID, &address, &isSettable)
        return status == noErr && isSettable.boolValue
    }

    private func outputVolume(deviceID: AudioObjectID, channelCount: Int) -> Double? {
        if hasProperty(deviceID, selector: kAudioDevicePropertyVolumeScalar, scope: kAudioDevicePropertyScopeOutput),
           let volume = try? float32Property(
                deviceID,
                selector: kAudioDevicePropertyVolumeScalar,
                scope: kAudioDevicePropertyScopeOutput
           ) {
            return Double(max(0, min(volume, 1)))
        }

        let channelVolumes = (1...max(1, channelCount)).compactMap { channel -> Float32? in
            guard hasProperty(
                deviceID,
                selector: kAudioDevicePropertyVolumeScalar,
                scope: kAudioDevicePropertyScopeOutput,
                element: AudioObjectPropertyElement(channel)
            ) else {
                return nil
            }
            return try? float32Property(
                deviceID,
                selector: kAudioDevicePropertyVolumeScalar,
                scope: kAudioDevicePropertyScopeOutput,
                element: AudioObjectPropertyElement(channel)
            )
        }
        guard !channelVolumes.isEmpty else { return nil }
        let average = channelVolumes.reduce(Float32(0), +) / Float32(channelVolumes.count)
        return Double(max(0, min(average, 1)))
    }

    private func isMuted(deviceID: AudioObjectID) -> Bool? {
        guard hasProperty(deviceID, selector: kAudioDevicePropertyMute, scope: kAudioDevicePropertyScopeOutput) else {
            return nil
        }
        return ((try? uint32Property(
            deviceID,
            selector: kAudioDevicePropertyMute,
            scope: kAudioDevicePropertyScopeOutput
        )) ?? 0) != 0
    }

    private func canSetOutputVolume(deviceID: AudioObjectID, channelCount: Int) -> Bool {
        if isSettable(deviceID, selector: kAudioDevicePropertyVolumeScalar, scope: kAudioDevicePropertyScopeOutput) {
            return true
        }
        return (1...max(1, channelCount)).contains { channel in
            isSettable(
                deviceID,
                selector: kAudioDevicePropertyVolumeScalar,
                scope: kAudioDevicePropertyScopeOutput,
                element: AudioObjectPropertyElement(channel)
            )
        }
    }

    private func canSetMute(deviceID: AudioObjectID) -> Bool {
        isSettable(deviceID, selector: kAudioDevicePropertyMute, scope: kAudioDevicePropertyScopeOutput)
    }

    private func check(_ status: OSStatus, _ operation: String) throws {
        guard status == noErr else {
            throw AudioRoutingError.coreAudio(operation, status)
        }
    }

    private func transport(from value: UInt32) -> AudioTransport {
        switch value {
        case kAudioDeviceTransportTypeBuiltIn:
            return .builtIn
        case kAudioDeviceTransportTypeBluetooth:
            return .bluetooth
        case kAudioDeviceTransportTypeBluetoothLE:
            return .bluetoothLE
        case kAudioDeviceTransportTypeUSB:
            return .usb
        case kAudioDeviceTransportTypeHDMI:
            return .hdmi
        case kAudioDeviceTransportTypeDisplayPort:
            return .displayPort
        case kAudioDeviceTransportTypeAirPlay:
            return .airPlay
        case kAudioDeviceTransportTypeAggregate:
            return .aggregate
        case kAudioDeviceTransportTypeVirtual:
            return .virtual
        case kAudioDeviceTransportTypeThunderbolt:
            return .thunderbolt
        default:
            return .unknown
        }
    }
}
