import CoreAudio
import Foundation

public struct PublishedAppInputDevice: Identifiable, Hashable {
    public var id: String { uid }
    public let sourceID: String
    public let sourceName: String
    public let uid: String
    public let name: String
    public let channelCount: Int

    public init(sourceID: String, sourceName: String, uid: String, name: String, channelCount: Int) {
        self.sourceID = sourceID
        self.sourceName = sourceName
        self.uid = uid
        self.name = name
        self.channelCount = channelCount
    }
}

public protocol AppInputPublishing {
    var isSupportedOnThisOS: Bool { get }
    var publishedDevices: [PublishedAppInputDevice] { get }
    var lastMessage: String? { get }

    func sync(sources: [AudioSource], enabled: Bool)
    func stopAll()
}

public final class AppInputDevicePublisher: AppInputPublishing {
    private struct PublishedSession {
        let sourceID: String
        let sourceName: String
        let processObjectID: AudioObjectID
        let tapID: AudioObjectID
        let aggregateDeviceID: AudioObjectID
        let uid: String
        let name: String
        let channelCount: Int
    }

    public private(set) var lastMessage: String?
    private var sessionsBySourceID: [String: PublishedSession] = [:]
    private let uidPrefix = "com.local.AudioRouter.input."

    public init() {}

    public var isSupportedOnThisOS: Bool {
        if #available(macOS 14.2, *) {
            return true
        }
        return false
    }

    public var publishedDevices: [PublishedAppInputDevice] {
        sessionsBySourceID.values
            .map {
                PublishedAppInputDevice(
                    sourceID: $0.sourceID,
                    sourceName: $0.sourceName,
                    uid: $0.uid,
                    name: $0.name,
                    channelCount: $0.channelCount
                )
            }
            .sorted { $0.sourceName.localizedCaseInsensitiveCompare($1.sourceName) == .orderedAscending }
    }

    public func sync(sources: [AudioSource], enabled: Bool) {
        guard enabled, isSupportedOnThisOS else {
            stopAll()
            lastMessage = enabled ? "App input devices require macOS 14.2 or newer." : nil
            return
        }

        let desiredSourceIDs = Set(sources.map(\.id))
        for sourceID in sessionsBySourceID.keys where !desiredSourceIDs.contains(sourceID) {
            stopInput(for: sourceID)
        }

        var publishedCount = 0
        var waitingSourceNames: [String] = []
        for source in sources where source.id != "system-sounds" {
            guard source.audioObjectID != nil else {
                waitingSourceNames.append(source.appName)
                continue
            }
            do {
                try publishInput(for: source)
                publishedCount += 1
            } catch {
                lastMessage = "\(source.appName) mixer input is waiting: \(error.localizedDescription)"
            }
        }

        if publishedCount > 0 {
            lastMessage = "\(publishedCount) app mixer input\(publishedCount == 1 ? "" : "s") published."
        } else if !waitingSourceNames.isEmpty {
            lastMessage = "No mixer inputs published yet. Play audio once in \(waitingSourceNames.prefix(2).joined(separator: ", ")) so macOS exposes a process tap."
        }
    }

    public func stopAll() {
        for sourceID in Array(sessionsBySourceID.keys) {
            stopInput(for: sourceID)
        }
    }

    public static func inputDeviceUID(for source: AudioSource) -> String {
        "com.local.AudioRouter.input.\(stableIdentifier(for: source))"
    }

    public static func inputDeviceName(for source: AudioSource) -> String {
        "AudioRouter \(source.appName) Input"
    }

    private func publishInput(for source: AudioSource) throws {
        guard let processObjectID = source.audioObjectID else {
            throw AudioRoutingBackendError.unsupported("Start playback in \(source.appName) so Core Audio exposes a process tap.")
        }

        let uid = Self.inputDeviceUID(for: source)
        if let session = sessionsBySourceID[source.id],
           session.processObjectID == AudioObjectID(processObjectID),
           session.uid == uid {
            return
        }

        stopInput(for: source.id)

        if #available(macOS 14.2, *) {
            destroyExistingAggregateDevice(uid: uid)

            let tapDescription = CATapDescription(stereoMixdownOfProcesses: [AudioObjectID(processObjectID)])
            tapDescription.name = "AudioRouter \(source.appName) Mixer Input Tap"
            tapDescription.isPrivate = false
            tapDescription.muteBehavior = .unmuted

            var tapID = AudioObjectID(kAudioObjectUnknown)
            try checkTapStatus(
                AudioHardwareCreateProcessTap(tapDescription, &tapID),
                operation: "Create app mixer input tap"
            )

            do {
                let tapUID = try stringProperty(tapID, selector: kAudioTapPropertyUID)
                let publishedDevice = try createPublicAggregateInputDevice(
                    source: source,
                    uid: uid,
                    tapUID: tapUID
                )
                sessionsBySourceID[source.id] = PublishedSession(
                    sourceID: source.id,
                    sourceName: source.appName,
                    processObjectID: AudioObjectID(processObjectID),
                    tapID: tapID,
                    aggregateDeviceID: publishedDevice.deviceID,
                    uid: uid,
                    name: Self.inputDeviceName(for: source),
                    channelCount: publishedDevice.channelCount
                )
            } catch {
                AudioHardwareDestroyProcessTap(tapID)
                throw error
            }
            return
        }

        throw AudioRoutingBackendError.unsupported("App mixer inputs require macOS 14.2 or newer.")
    }

    private func stopInput(for sourceID: String) {
        guard let session = sessionsBySourceID.removeValue(forKey: sourceID) else { return }
        AudioHardwareDestroyAggregateDevice(session.aggregateDeviceID)
        if #available(macOS 14.2, *) {
            AudioHardwareDestroyProcessTap(session.tapID)
        }
    }

    private func createPublicAggregateInputDevice(
        source: AudioSource,
        uid: String,
        tapUID: String
    ) throws -> (deviceID: AudioObjectID, channelCount: Int) {
        let tap: [String: Any] = [
            kAudioSubTapUIDKey: tapUID,
            kAudioSubTapDriftCompensationKey: 1,
            kAudioSubTapDriftCompensationQualityKey: kAudioAggregateDriftCompensationHighQuality
        ]
        let description: [String: Any] = [
            kAudioAggregateDeviceUIDKey: uid,
            kAudioAggregateDeviceNameKey: Self.inputDeviceName(for: source),
            kAudioAggregateDeviceIsPrivateKey: 0,
            kAudioAggregateDeviceTapListKey: [tap]
        ]

        var aggregateDeviceID = AudioObjectID(kAudioObjectUnknown)
        try check(
            AudioHardwareCreateAggregateDevice(description as CFDictionary, &aggregateDeviceID),
            "Create app mixer input device"
        )
        do {
            try attachTapList(tapUID: tapUID, to: aggregateDeviceID)
            let channels = try waitForInputChannels(deviceID: aggregateDeviceID)
            return (aggregateDeviceID, channels)
        } catch {
            AudioHardwareDestroyAggregateDevice(aggregateDeviceID)
            throw error
        }
    }

    private func attachTapList(tapUID: String, to aggregateDeviceID: AudioObjectID) throws {
        var address = propertyAddress(selector: kAudioAggregateDevicePropertyTapList)
        var propertySize: UInt32 = 0
        try check(
            AudioObjectGetPropertyDataSize(aggregateDeviceID, &address, 0, nil, &propertySize),
            "Read mixer input tap list size"
        )

        var existingList: CFArray?
        if propertySize > 0 {
            try check(
                withUnsafeMutablePointer(to: &existingList) { pointer in
                    AudioObjectGetPropertyData(
                        aggregateDeviceID,
                        &address,
                        0,
                        nil,
                        &propertySize,
                        pointer
                    )
                },
                "Read mixer input tap list"
            )
        }

        var tapUIDs = existingList as? [CFString] ?? []
        let tapCFUID = tapUID as CFString
        if !tapUIDs.contains(where: { ($0 as String) == tapUID }) {
            tapUIDs.append(tapCFUID)
        }

        var nextList: CFArray? = tapUIDs as CFArray
        let nextSize = UInt32(max(1, tapUIDs.count) * MemoryLayout<CFString>.stride)
        try check(
            withUnsafeMutablePointer(to: &nextList) { pointer in
                AudioObjectSetPropertyData(
                    aggregateDeviceID,
                    &address,
                    0,
                    nil,
                    nextSize,
                    pointer
                )
            },
            "Publish process tap as mixer input"
        )

        let verifiedUIDs = (try? tapUIDList(from: aggregateDeviceID)) ?? []
        guard verifiedUIDs.contains(tapUID) else {
            throw AudioRoutingBackendError.unsupported("macOS created the app input device, but HAL did not attach the process tap.")
        }
    }

    private func tapUIDList(from aggregateDeviceID: AudioObjectID) throws -> [String] {
        var address = propertyAddress(selector: kAudioAggregateDevicePropertyTapList)
        var propertySize: UInt32 = 0
        try check(
            AudioObjectGetPropertyDataSize(aggregateDeviceID, &address, 0, nil, &propertySize),
            "Verify mixer input tap list size"
        )
        guard propertySize > 0 else { return [] }

        var list: CFArray?
        try check(
            withUnsafeMutablePointer(to: &list) { pointer in
                AudioObjectGetPropertyData(
                    aggregateDeviceID,
                    &address,
                    0,
                    nil,
                    &propertySize,
                    pointer
                )
            },
            "Verify mixer input tap list"
        )
        return (list as? [CFString] ?? []).map { $0 as String }
    }

    private func waitForInputChannels(deviceID: AudioObjectID) throws -> Int {
        var lastCount = 0
        for _ in 0..<40 {
            lastCount = (try? channelCount(deviceID: deviceID, scope: kAudioDevicePropertyScopeInput)) ?? 0
            if lastCount > 0 {
                return lastCount
            }
            Thread.sleep(forTimeInterval: 0.05)
        }
        throw AudioRoutingBackendError.unsupported("macOS created the tap device, but it did not expose input channels to other apps.")
    }

    private func destroyExistingAggregateDevice(uid: String) {
        guard let deviceID = try? deviceID(for: uid) else { return }
        AudioHardwareDestroyAggregateDevice(deviceID)
    }

    private func deviceID(for uid: String) throws -> AudioObjectID {
        for deviceID in try objectIDArray(
            objectID: AudioObjectID(kAudioObjectSystemObject),
            selector: kAudioHardwarePropertyDevices
        ) where (try? stringProperty(deviceID, selector: kAudioDevicePropertyDeviceUID)) == uid {
            return deviceID
        }
        throw AudioRouterError.missingDevice
    }

    private func objectIDArray(
        objectID: AudioObjectID,
        selector: AudioObjectPropertySelector,
        scope: AudioObjectPropertyScope = kAudioObjectPropertyScopeGlobal
    ) throws -> [AudioObjectID] {
        var address = propertyAddress(selector: selector, scope: scope)
        var size: UInt32 = 0
        try check(
            AudioObjectGetPropertyDataSize(objectID, &address, 0, nil, &size),
            "Read CoreAudio object array size"
        )
        guard size > 0 else { return [] }

        let count = Int(size) / MemoryLayout<AudioObjectID>.stride
        var values = Array(repeating: AudioObjectID(kAudioObjectUnknown), count: count)
        try check(
            AudioObjectGetPropertyData(objectID, &address, 0, nil, &size, &values),
            "Read CoreAudio object array"
        )
        return values.filter { $0 != AudioObjectID(kAudioObjectUnknown) }
    }

    private func channelCount(deviceID: AudioObjectID, scope: AudioObjectPropertyScope) throws -> Int {
        var address = propertyAddress(selector: kAudioDevicePropertyStreamConfiguration, scope: scope)
        var size: UInt32 = 0
        try check(
            AudioObjectGetPropertyDataSize(deviceID, &address, 0, nil, &size),
            "Read mixer input stream configuration size"
        )
        guard size > 0 else { return 0 }

        let rawPointer = UnsafeMutableRawPointer.allocate(
            byteCount: Int(size),
            alignment: MemoryLayout<AudioBufferList>.alignment
        )
        defer { rawPointer.deallocate() }

        let bufferList = rawPointer.bindMemory(to: AudioBufferList.self, capacity: 1)
        try check(
            AudioObjectGetPropertyData(deviceID, &address, 0, nil, &size, bufferList),
            "Read mixer input stream configuration"
        )
        return UnsafeMutableAudioBufferListPointer(bufferList).reduce(0) { $0 + Int($1.mNumberChannels) }
    }

    private func stringProperty(_ objectID: AudioObjectID, selector: AudioObjectPropertySelector) throws -> String {
        var address = propertyAddress(selector: selector)
        var value: CFString = "" as CFString
        var size = UInt32(MemoryLayout<CFString>.size)
        try check(
            withUnsafeMutablePointer(to: &value) { pointer in
                AudioObjectGetPropertyData(objectID, &address, 0, nil, &size, pointer)
            },
            "Read CoreAudio string property"
        )
        return value as String
    }

    private func propertyAddress(
        selector: AudioObjectPropertySelector,
        scope: AudioObjectPropertyScope = kAudioObjectPropertyScopeGlobal,
        element: AudioObjectPropertyElement = kAudioObjectPropertyElementMain
    ) -> AudioObjectPropertyAddress {
        AudioObjectPropertyAddress(mSelector: selector, mScope: scope, mElement: element)
    }

    private func checkTapStatus(_ status: OSStatus, operation: String) throws {
        guard status == noErr else {
            if status == kAudioHardwareIllegalOperationError {
                throw AudioRoutingBackendError.unsupported("macOS denied process-tap capture. Grant AudioRouter System Audio Recording permission, then try again.")
            }
            throw AudioRouterError.coreAudio(operation, status)
        }
    }

    private func check(_ status: OSStatus, _ operation: String) throws {
        guard status == noErr else {
            throw AudioRouterError.coreAudio(operation, status)
        }
    }

    private static func stableIdentifier(for source: AudioSource) -> String {
        let rawValue = source.bundleIdentifier ?? source.id
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: ".-"))
        let normalized = rawValue.unicodeScalars.map { scalar in
            allowed.contains(scalar) ? Character(scalar) : "-"
        }
        let value = String(normalized)
            .split(separator: "-")
            .joined(separator: "-")
            .trimmingCharacters(in: CharacterSet(charactersIn: ".-"))
        return value.isEmpty ? "source" : value
    }
}
