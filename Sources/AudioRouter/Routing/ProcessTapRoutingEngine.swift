import AudioToolbox
import CoreAudio
import Darwin
import Foundation

final class ProcessTapRoutingEngine {
    private final class RouteControl {
        private let lock = NSLock()
        private var storedVolume: Float
        private var storedMuted: Bool
        private var storedLevel: Double = 0
        private var receivedBufferCount = 0

        init(volume: Double, muted: Bool) {
            self.storedVolume = Float(max(0, min(1.5, volume)))
            self.storedMuted = muted
        }

        func setVolume(_ volume: Double) {
            lock.lock()
            storedVolume = Float(max(0, min(1.5, volume)))
            lock.unlock()
        }

        func setMuted(_ muted: Bool) {
            lock.lock()
            storedMuted = muted
            lock.unlock()
        }

        func gain() -> Float {
            lock.lock()
            let value: Float = storedMuted ? 0 : storedVolume
            lock.unlock()
            return value
        }

        func updateLevel(_ level: Double) {
            lock.lock()
            storedLevel = max(0, min(1, level))
            receivedBufferCount += 1
            lock.unlock()
        }

        func level() -> Double {
            lock.lock()
            let value = storedLevel
            lock.unlock()
            return value
        }

        func hasReceivedBuffers() -> Bool {
            lock.lock()
            let value = receivedBufferCount > 0
            lock.unlock()
            return value
        }
    }

    private final class RouteStartProbe {
        private let lock = NSLock()
        private let semaphore = DispatchSemaphore(value: 0)
        private var signaled = false

        func signal() {
            lock.lock()
            let shouldSignal = !signaled
            signaled = true
            lock.unlock()
            if shouldSignal {
                semaphore.signal()
            }
        }

        func wait(seconds: Double) -> Bool {
            semaphore.wait(timeout: .now() + seconds) == .success
        }
    }

    private struct RouteSession {
        let sourceID: String
        let outputDeviceUID: String
        let tapID: AudioObjectID
        let aggregateDeviceID: AudioObjectID
        let ioProcID: AudioDeviceIOProcID
        let control: RouteControl
        let outputRenderer: RouteOutputRenderer
    }

    private final class PCMBufferPipe {
        private let lock = NSLock()
        private var storage: [UInt8]
        private var readIndex = 0
        private var writeIndex = 0
        private var availableByteCount = 0

        let channelCount: Int

        init(format: AudioStreamBasicDescription, seconds: Double = 1.0) {
            self.channelCount = max(1, Int(format.mChannelsPerFrame))
            let bytesPerSecond = max(4096, Int(format.mSampleRate) * max(1, Int(format.mBytesPerFrame)))
            self.storage = Array(repeating: 0, count: max(16_384, Int(Double(bytesPerSecond) * seconds)))
        }

        func writeInterleavedFloat32(
            from inputData: UnsafePointer<AudioBufferList>,
            outputChannelCount: Int,
            gain: Float
        ) -> (level: Double, wroteFrames: Bool) {
            let inputBuffers = UnsafeMutableAudioBufferListPointer(UnsafeMutablePointer(mutating: inputData))
            guard let frameCount = frameCount(for: inputBuffers), frameCount > 0 else {
                return (0, false)
            }

            lock.lock()
            defer { lock.unlock() }

            var squareSum: Double = 0
            var sampleCount = 0
            for frame in 0..<frameCount {
                for channel in 0..<outputChannelCount {
                    var sample = sampleAt(frame: frame, channel: channel, inputBuffers: inputBuffers) * gain
                    squareSum += Double(sample) * Double(sample)
                    sampleCount += 1
                    withUnsafeBytes(of: &sample) { sampleBytes in
                        for byte in sampleBytes {
                            writeByte(byte)
                        }
                    }
                }
            }

            guard sampleCount > 0 else { return (0, false) }
            return (min(1, sqrt(squareSum / Double(sampleCount)) * 3.2), true)
        }

        func read(into destination: UnsafeMutableRawPointer?, byteCount: Int) {
            guard let destination, byteCount > 0 else { return }
            let bytes = destination.assumingMemoryBound(to: UInt8.self)
            lock.lock()
            defer { lock.unlock() }

            for index in 0..<byteCount {
                if availableByteCount > 0 {
                    bytes[index] = storage[readIndex]
                    readIndex = (readIndex + 1) % storage.count
                    availableByteCount -= 1
                } else {
                    bytes[index] = 0
                }
            }
        }

        private func writeByte(_ byte: UInt8) {
            if availableByteCount == storage.count {
                readIndex = (readIndex + 1) % storage.count
                availableByteCount -= 1
            }
            storage[writeIndex] = byte
            writeIndex = (writeIndex + 1) % storage.count
            availableByteCount += 1
        }

        private func frameCount(for inputBuffers: UnsafeMutableAudioBufferListPointer) -> Int? {
            guard !inputBuffers.isEmpty else { return nil }
            if inputBuffers.count == 1 {
                let buffer = inputBuffers[0]
                let channelCount = max(1, Int(buffer.mNumberChannels))
                return Int(buffer.mDataByteSize) / (MemoryLayout<Float32>.size * channelCount)
            }
            return inputBuffers.compactMap { buffer in
                buffer.mData == nil ? nil : Int(buffer.mDataByteSize) / MemoryLayout<Float32>.size
            }.min()
        }

        private func sampleAt(
            frame: Int,
            channel: Int,
            inputBuffers: UnsafeMutableAudioBufferListPointer
        ) -> Float32 {
            if inputBuffers.count == 1 {
                let buffer = inputBuffers[0]
                guard let data = buffer.mData else { return 0 }
                let inputChannelCount = max(1, Int(buffer.mNumberChannels))
                let samples = data.assumingMemoryBound(to: Float32.self)
                return samples[frame * inputChannelCount + min(channel, inputChannelCount - 1)]
            }

            let buffer = inputBuffers[min(channel, inputBuffers.count - 1)]
            guard let data = buffer.mData else { return 0 }
            let inputChannelCount = max(1, Int(buffer.mNumberChannels))
            let samples = data.assumingMemoryBound(to: Float32.self)
            if inputChannelCount == 1 {
                return samples[frame]
            }
            return samples[frame * inputChannelCount + min(channel, inputChannelCount - 1)]
        }
    }

    private final class RouteOutputRenderer {
        private let queue: AudioQueueRef
        private let pipe: PCMBufferPipe
        private let bufferByteSize: UInt32
        private let stopLock = NSLock()
        private var stopped = false

        init(format: AudioStreamBasicDescription, outputDeviceUID: String, pipe: PCMBufferPipe) throws {
            self.pipe = pipe
            self.bufferByteSize = Self.preferredBufferByteSize(for: format)

            var mutableFormat = format
            var queueRef: AudioQueueRef?
            let callbackQueue = DispatchQueue(label: "com.local.AudioRouter.route-output.\(UUID().uuidString)")
            let bufferByteSize = self.bufferByteSize
            let status = AudioQueueNewOutputWithDispatchQueue(
                &queueRef,
                &mutableFormat,
                0,
                callbackQueue
            ) { queue, buffer in
                pipe.read(into: buffer.pointee.mAudioData, byteCount: Int(bufferByteSize))
                buffer.pointee.mAudioDataByteSize = bufferByteSize
                AudioQueueEnqueueBuffer(queue, buffer, 0, nil)
            }
            try Self.check(status, "Create output renderer")

            guard let queueRef else {
                throw AudioRouterError.coreAudio("Create output renderer", kAudioHardwareUnspecifiedError)
            }
            self.queue = queueRef

            var deviceUID = outputDeviceUID as CFString
            try Self.check(
                withUnsafePointer(to: &deviceUID) { pointer in
                    AudioQueueSetProperty(
                        queueRef,
                        kAudioQueueProperty_CurrentDevice,
                        pointer,
                        UInt32(MemoryLayout<CFString>.size)
                    )
                },
                "Select route output device"
            )

            for _ in 0..<4 {
                var buffer: AudioQueueBufferRef?
                try Self.check(AudioQueueAllocateBuffer(queueRef, bufferByteSize, &buffer), "Allocate output buffer")
                guard let buffer else {
                    throw AudioRouterError.coreAudio("Allocate output buffer", kAudioHardwareUnspecifiedError)
                }
                pipe.read(into: buffer.pointee.mAudioData, byteCount: Int(bufferByteSize))
                buffer.pointee.mAudioDataByteSize = bufferByteSize
                try Self.check(AudioQueueEnqueueBuffer(queueRef, buffer, 0, nil), "Prime output buffer")
            }

            try Self.check(AudioQueueStart(queueRef, nil), "Start output renderer")
        }

        deinit {
            stop()
        }

        func stop() {
            stopLock.lock()
            guard !stopped else {
                stopLock.unlock()
                return
            }
            stopped = true
            stopLock.unlock()
            AudioQueueStop(queue, true)
            AudioQueueDispose(queue, true)
        }

        private static func preferredBufferByteSize(for format: AudioStreamBasicDescription) -> UInt32 {
            let frames = max(256, Int(format.mSampleRate * 0.02))
            let bytes = frames * max(1, Int(format.mBytesPerFrame))
            return UInt32(min(max(bytes, 4096), 32_768))
        }

        private static func check(_ status: OSStatus, _ operation: String) throws {
            guard status == noErr else {
                throw AudioRouterError.coreAudio(operation, status)
            }
        }
    }

    private var sessions: [String: RouteSession] = [:]
    private var pendingVolumes: [String: Double] = [:]
    private var pendingMutes: [String: Bool] = [:]

    var isSupportedOnThisOS: Bool {
        if #available(macOS 14.2, *) {
            return true
        }
        return false
    }

    deinit {
        stopAll()
    }

    func startRoute(source: AudioSource, outputDevice: AudioDevice) throws {
        guard isSupportedOnThisOS else {
            throw AudioRoutingBackendError.unsupported("Live per-app routes require macOS 14.2 or newer.")
        }
        guard outputDevice.kind == .output, outputDevice.isAlive else {
            throw AudioRoutingBackendError.unsupported("The selected output device is not available.")
        }
        guard let processObjectID = source.audioObjectID else {
            throw AudioRoutingBackendError.unsupported("Start playback in \(source.appName), refresh AudioRouter, then assign the output again.")
        }
        if let session = sessions[source.id], session.outputDeviceUID == outputDevice.uid {
            return
        }

        stopRoute(sourceID: source.id)

        if #available(macOS 14.2, *) {
            let tapDescription = CATapDescription(stereoMixdownOfProcesses: [AudioObjectID(processObjectID)])
            tapDescription.name = "AudioRouter \(source.appName)"
            tapDescription.isPrivate = true
            tapDescription.muteBehavior = .mutedWhenTapped

            var tapID = AudioObjectID(kAudioObjectUnknown)
            try checkTapStatus(
                AudioHardwareCreateProcessTap(tapDescription, &tapID),
                operation: "Create process tap"
            )

            do {
                let tapUID = try stringProperty(tapID, selector: kAudioTapPropertyUID)
                let tapFormat = try streamFormat(tapID)
                guard canReadFloat32(tapFormat) else {
                    throw AudioRoutingBackendError.unsupported("This app's process tap uses an audio format AudioRouter cannot route yet.")
                }
                let playbackFormat = Self.playbackFormat(from: tapFormat)
                let pipe = PCMBufferPipe(format: playbackFormat)
                let outputRenderer = try RouteOutputRenderer(
                    format: playbackFormat,
                    outputDeviceUID: outputDevice.uid,
                    pipe: pipe
                )
                let aggregateDeviceID = try createAggregateDevice(
                    sourceName: source.appName,
                    tapUID: tapUID
                )

                do {
                    let control = RouteControl(
                        volume: pendingVolumes[source.id] ?? source.volume,
                        muted: pendingMutes[source.id] ?? source.isMuted
                    )
                    let startProbe = RouteStartProbe()
                    var ioProcID: AudioDeviceIOProcID?
                    let ioStatus = AudioDeviceCreateIOProcIDWithBlock(
                        &ioProcID,
                        aggregateDeviceID,
                        nil
                    ) { _, inputData, _, outputData, _ in
                        Self.capture(
                            inputData: inputData,
                            outputData: outputData,
                            control: control,
                            pipe: pipe,
                            outputChannelCount: Int(playbackFormat.mChannelsPerFrame),
                            startProbe: startProbe
                        )
                    }
                    try check(ioStatus, "Create route IO callback")

                    guard let ioProcID else {
                        throw AudioRouterError.coreAudio("Create route IO callback", kAudioHardwareUnspecifiedError)
                    }

                    do {
                        try check(AudioDeviceStart(aggregateDeviceID, ioProcID), "Start route IO")
                        guard startProbe.wait(seconds: 1.0) || control.hasReceivedBuffers() else {
                            throw AudioRoutingBackendError.unsupported("The route started, but the process tap did not deliver audio. Start playback in \(source.appName), refresh, then assign the output again.")
                        }
                        sessions[source.id] = RouteSession(
                            sourceID: source.id,
                            outputDeviceUID: outputDevice.uid,
                            tapID: tapID,
                            aggregateDeviceID: aggregateDeviceID,
                            ioProcID: ioProcID,
                            control: control,
                            outputRenderer: outputRenderer
                        )
                    } catch {
                        AudioDeviceDestroyIOProcID(aggregateDeviceID, ioProcID)
                        throw error
                    }
                } catch {
                    AudioHardwareDestroyAggregateDevice(aggregateDeviceID)
                    outputRenderer.stop()
                    throw error
                }
            } catch {
                AudioHardwareDestroyProcessTap(tapID)
                throw error
            }
            return
        }

        throw AudioRoutingBackendError.unsupported("Live per-app routes are unavailable on this macOS version.")
    }

    func stopRoute(sourceID: String) {
        guard let session = sessions.removeValue(forKey: sourceID) else { return }
        AudioDeviceStop(session.aggregateDeviceID, session.ioProcID)
        AudioDeviceDestroyIOProcID(session.aggregateDeviceID, session.ioProcID)
        AudioHardwareDestroyAggregateDevice(session.aggregateDeviceID)
        session.outputRenderer.stop()
        if #available(macOS 14.2, *) {
            AudioHardwareDestroyProcessTap(session.tapID)
        }
    }

    func stopAll() {
        for sourceID in Array(sessions.keys) {
            stopRoute(sourceID: sourceID)
        }
    }

    func setVolume(sourceID: String, volume: Double) {
        pendingVolumes[sourceID] = volume
        sessions[sourceID]?.control.setVolume(volume)
    }

    func setMuted(sourceID: String, muted: Bool) {
        pendingMutes[sourceID] = muted
        sessions[sourceID]?.control.setMuted(muted)
    }

    func currentLevel(sourceID: String) -> Double? {
        sessions[sourceID]?.control.level()
    }

    func isRouting(sourceID: String) -> Bool {
        sessions[sourceID] != nil
    }

    private func createAggregateDevice(
        sourceName: String,
        tapUID: String
    ) throws -> AudioObjectID {
        let aggregateUID = "com.local.AudioRouter.route.\(UUID().uuidString)"
        let tap: [String: Any] = [
            kAudioSubTapUIDKey: tapUID,
            kAudioSubTapDriftCompensationKey: 1,
            kAudioSubTapDriftCompensationQualityKey: kAudioAggregateDriftCompensationMediumQuality
        ]
        let description: [String: Any] = [
            kAudioAggregateDeviceUIDKey: aggregateUID,
            kAudioAggregateDeviceNameKey: "AudioRouter Route \(sourceName)",
            kAudioAggregateDeviceIsPrivateKey: 1,
            kAudioAggregateDeviceTapListKey: [tap],
            kAudioAggregateDeviceTapAutoStartKey: 0
        ]

        var aggregateDeviceID = AudioObjectID(kAudioObjectUnknown)
        try check(
            AudioHardwareCreateAggregateDevice(description as CFDictionary, &aggregateDeviceID),
            "Create transient route device"
        )
        return aggregateDeviceID
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

    private func streamFormat(_ objectID: AudioObjectID) throws -> AudioStreamBasicDescription {
        var address = propertyAddress(selector: kAudioTapPropertyFormat)
        var format = AudioStreamBasicDescription()
        var size = UInt32(MemoryLayout<AudioStreamBasicDescription>.size)
        try check(
            AudioObjectGetPropertyData(objectID, &address, 0, nil, &size, &format),
            "Read process tap format"
        )
        return format
    }

    private func propertyAddress(
        selector: AudioObjectPropertySelector,
        scope: AudioObjectPropertyScope = kAudioObjectPropertyScopeGlobal,
        element: AudioObjectPropertyElement = kAudioObjectPropertyElementMain
    ) -> AudioObjectPropertyAddress {
        AudioObjectPropertyAddress(mSelector: selector, mScope: scope, mElement: element)
    }

    private func canReadFloat32(_ format: AudioStreamBasicDescription) -> Bool {
        format.mFormatID == kAudioFormatLinearPCM
            && (format.mFormatFlags & kAudioFormatFlagIsFloat) != 0
            && format.mBitsPerChannel == 32
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

    private static func playbackFormat(from tapFormat: AudioStreamBasicDescription) -> AudioStreamBasicDescription {
        let channels = min(max(1, tapFormat.mChannelsPerFrame), 2)
        let bytesPerFrame = channels * UInt32(MemoryLayout<Float32>.size)
        return AudioStreamBasicDescription(
            mSampleRate: tapFormat.mSampleRate > 0 ? tapFormat.mSampleRate : 48_000,
            mFormatID: kAudioFormatLinearPCM,
            mFormatFlags: kAudioFormatFlagIsFloat | kAudioFormatFlagIsPacked,
            mBytesPerPacket: bytesPerFrame,
            mFramesPerPacket: 1,
            mBytesPerFrame: bytesPerFrame,
            mChannelsPerFrame: channels,
            mBitsPerChannel: 32,
            mReserved: 0
        )
    }

    private static func capture(
        inputData: UnsafePointer<AudioBufferList>,
        outputData: UnsafeMutablePointer<AudioBufferList>,
        control: RouteControl,
        pipe: PCMBufferPipe,
        outputChannelCount: Int,
        startProbe: RouteStartProbe
    ) {
        let outputBuffers = UnsafeMutableAudioBufferListPointer(outputData)
        zero(outputBuffers)
        let gain = control.gain()
        let result = pipe.writeInterleavedFloat32(
            from: inputData,
            outputChannelCount: outputChannelCount,
            gain: gain
        )
        if result.wroteFrames {
            startProbe.signal()
        }
        control.updateLevel(result.level)
    }

    private static func zero(_ outputBuffers: UnsafeMutableAudioBufferListPointer) {
        for buffer in outputBuffers {
            guard let data = buffer.mData else { continue }
            memset(data, 0, Int(buffer.mDataByteSize))
        }
    }
}
