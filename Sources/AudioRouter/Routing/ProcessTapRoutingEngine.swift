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

        init(volume: Double, muted: Bool) {
            self.storedVolume = Float(RouteAudioQualityPolicy.normalizedGain(volume))
            self.storedMuted = muted
        }

        func setVolume(_ volume: Double) {
            lock.lock()
            storedVolume = Float(RouteAudioQualityPolicy.normalizedGain(volume))
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
            lock.unlock()
        }

        func level() -> Double {
            lock.lock()
            let value = storedLevel
            lock.unlock()
            return value
        }
    }

    private struct RouteSession {
        let sourceID: String
        let outputDeviceUIDs: [String]
        let tapID: AudioObjectID
        let aggregateDeviceID: AudioObjectID
        let ioProcID: AudioDeviceIOProcID
        let control: RouteControl
        let processor: RouteAudioProcessor
        let pipes: [PCMBufferPipe]
        let outputRenderers: [RouteOutputRenderer]
        var sourceQuality: SourceAudioQuality
        var sourceQualityCheckedAt: Date
    }

    private struct BiquadFilter {
        private var b0 = 1.0
        private var b1 = 0.0
        private var b2 = 0.0
        private var a1 = 0.0
        private var a2 = 0.0
        private var z1 = 0.0
        private var z2 = 0.0

        init(centerFrequency: Double, sampleRate: Double, gain: Double) {
            update(centerFrequency: centerFrequency, sampleRate: sampleRate, gain: gain)
        }

        mutating func update(centerFrequency: Double, sampleRate: Double, gain: Double) {
            guard sampleRate > 0, abs(gain) >= 0.05 else {
                b0 = 1
                b1 = 0
                b2 = 0
                a1 = 0
                a2 = 0
                z1 = 0
                z2 = 0
                return
            }

            let nyquist = sampleRate * 0.5
            let frequency = min(max(20, centerFrequency), nyquist * 0.95)
            let q = 1.2
            let omega = 2 * Double.pi * frequency / sampleRate
            let alpha = sin(omega) / (2 * q)
            let amplitude = pow(10, gain / 40)
            let cosOmega = cos(omega)
            let unnormalizedB0 = 1 + alpha * amplitude
            let unnormalizedB1 = -2 * cosOmega
            let unnormalizedB2 = 1 - alpha * amplitude
            let unnormalizedA0 = 1 + alpha / amplitude
            let unnormalizedA1 = -2 * cosOmega
            let unnormalizedA2 = 1 - alpha / amplitude

            b0 = unnormalizedB0 / unnormalizedA0
            b1 = unnormalizedB1 / unnormalizedA0
            b2 = unnormalizedB2 / unnormalizedA0
            a1 = unnormalizedA1 / unnormalizedA0
            a2 = unnormalizedA2 / unnormalizedA0
        }

        mutating func process(_ input: Double) -> Double {
            let output = b0 * input + z1
            z1 = b1 * input - a1 * output + z2
            z2 = b2 * input - a2 * output
            return output.isFinite ? output : 0
        }
    }

    private final class GraphicEQProcessor {
        private static let centerFrequencies: [Double] = [
            31, 62, 125, 250, 500, 1_000, 2_000, 4_000, 8_000, 16_000
        ]

        private let sampleRate: Double
        private let channelCount: Int
        private var filtersByChannel: [[BiquadFilter]]
        private var activeFilterIndices: [Int]

        init(sampleRate: Double, channelCount: Int, bands: [Double]) {
            self.sampleRate = sampleRate
            self.channelCount = max(1, channelCount)
            let normalizedBands = Self.normalizedBands(bands)
            self.activeFilterIndices = normalizedBands.indices.filter { abs(normalizedBands[$0]) >= 0.05 }
            self.filtersByChannel = (0..<self.channelCount).map { _ in
                Self.centerFrequencies.enumerated().map { index, frequency in
                    BiquadFilter(
                        centerFrequency: frequency,
                        sampleRate: sampleRate,
                        gain: normalizedBands[index]
                    )
                }
            }
        }

        func updateBands(_ bands: [Double]) {
            let normalizedBands = Self.normalizedBands(bands)
            activeFilterIndices = normalizedBands.indices.filter { abs(normalizedBands[$0]) >= 0.05 }
            for channel in filtersByChannel.indices {
                for index in filtersByChannel[channel].indices {
                    filtersByChannel[channel][index].update(
                        centerFrequency: Self.centerFrequencies[index],
                        sampleRate: sampleRate,
                        gain: normalizedBands[index]
                    )
                }
            }
        }

        func process(sample: Float32, channel: Int) -> Float32 {
            guard !activeFilterIndices.isEmpty else { return sample }
            let filterChannel = min(max(0, channel), channelCount - 1)
            var value = Double(sample)
            for index in activeFilterIndices {
                value = filtersByChannel[filterChannel][index].process(value)
            }
            guard value.isFinite else { return 0 }
            return Float32(max(-4, min(4, value)))
        }

        private static func normalizedBands(_ bands: [Double]) -> [Double] {
            var normalized = Array(bands.prefix(centerFrequencies.count)).map { max(-12, min(12, $0)) }
            while normalized.count < centerFrequencies.count {
                normalized.append(0)
            }
            return normalized
        }
    }

    private final class RouteAudioProcessor {
        private let processorLock = NSLock()
        private var processingScratch: [Float32]
        private var equalizer: GraphicEQProcessor

        let channelCount: Int

        init(format: AudioStreamBasicDescription, eqBands: [Double]) {
            self.channelCount = max(1, Int(format.mChannelsPerFrame))
            self.processingScratch = Array(
                repeating: 0,
                count: RouteAudioQualityPolicy.processingChunkFrameCount * self.channelCount
            )
            self.equalizer = GraphicEQProcessor(
                sampleRate: format.mSampleRate,
                channelCount: self.channelCount,
                bands: eqBands
            )
        }

        func setEQBands(_ bands: [Double]) {
            processorLock.lock()
            equalizer.updateBands(bands)
            processorLock.unlock()
        }

        func writeInterleavedFloat32(
            from inputData: UnsafePointer<AudioBufferList>,
            gain: Float,
            consume: (UnsafeBufferPointer<Float32>) -> Void
        ) -> Double {
            let inputBuffers = UnsafeMutableAudioBufferListPointer(UnsafeMutablePointer(mutating: inputData))
            guard let frameCount = frameCount(for: inputBuffers), frameCount > 0 else {
                return 0
            }

            processorLock.lock()
            defer { processorLock.unlock() }

            var squareSum: Double = 0
            var sampleCount = 0
            var processedFrameCount = 0
            while processedFrameCount < frameCount {
                let chunkFrameCount = min(
                    RouteAudioQualityPolicy.processingChunkFrameCount,
                    frameCount - processedFrameCount
                )
                let chunkSampleCount = chunkFrameCount * channelCount

                for frame in 0..<chunkFrameCount {
                    for channel in 0..<channelCount {
                        let equalizedSample = equalizer.process(
                            sample: sampleAt(
                                frame: processedFrameCount + frame,
                                channel: channel,
                                inputBuffers: inputBuffers
                            ),
                            channel: channel
                        )
                        let sample = Self.peakLimited(equalizedSample * gain)
                        processingScratch[frame * channelCount + channel] = sample
                        squareSum += Double(sample) * Double(sample)
                    }
                }
                sampleCount += chunkSampleCount
                processingScratch.withUnsafeBufferPointer { scratch in
                    consume(UnsafeBufferPointer(start: scratch.baseAddress, count: chunkSampleCount))
                }
                processedFrameCount += chunkFrameCount
            }

            guard sampleCount > 0 else { return 0 }
            return min(1, sqrt(squareSum / Double(sampleCount)) * 3.2)
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

        private static func peakLimited(_ sample: Float32) -> Float32 {
            guard sample.isFinite else { return 0 }
            let magnitude = abs(sample)
            guard magnitude > 1 else { return sample }

            let overshoot = magnitude - 1
            let softened = 1 + overshoot / (1 + overshoot)
            return copysign(min(1.18, softened), sample)
        }
    }

    private final class PCMBufferPipe {
        private let bufferLock = NSLock()
        private var storage: [Float32]
        private var readIndex = 0
        private var writeIndex = 0
        private var availableSampleCount = 0

        init(format: AudioStreamBasicDescription, seconds: Double = 1.0) {
            let bytesPerSecond = max(4096, Int(format.mSampleRate) * max(1, Int(format.mBytesPerFrame)))
            let sampleCapacity = max(4_096, Int(Double(bytesPerSecond) * seconds) / MemoryLayout<Float32>.size)
            self.storage = Array(repeating: 0, count: sampleCapacity)
        }

        func read(into destination: UnsafeMutableRawPointer?, byteCount: Int) {
            guard let destination, byteCount > 0 else { return }
            let samples = destination.assumingMemoryBound(to: Float32.self)
            let requestedSampleCount = byteCount / MemoryLayout<Float32>.size
            bufferLock.lock()
            let copiedSampleCount = min(requestedSampleCount, availableSampleCount)
            if copiedSampleCount > 0 {
                storage.withUnsafeBufferPointer { source in
                    guard let sourceBase = source.baseAddress else { return }
                    let firstCopyCount = min(copiedSampleCount, storage.count - readIndex)
                    memcpy(
                        samples,
                        sourceBase.advanced(by: readIndex),
                        firstCopyCount * MemoryLayout<Float32>.size
                    )
                    let secondCopyCount = copiedSampleCount - firstCopyCount
                    if secondCopyCount > 0 {
                        memcpy(
                            samples.advanced(by: firstCopyCount),
                            sourceBase,
                            secondCopyCount * MemoryLayout<Float32>.size
                        )
                    }
                }
                readIndex = (readIndex + copiedSampleCount) % storage.count
                availableSampleCount -= copiedSampleCount
            }
            bufferLock.unlock()

            let copiedByteCount = copiedSampleCount * MemoryLayout<Float32>.size
            if copiedByteCount < byteCount {
                memset(destination.advanced(by: copiedByteCount), 0, byteCount - copiedByteCount)
            }
        }

        func write(samples: UnsafeBufferPointer<Float32>) {
            guard var sourceBase = samples.baseAddress, !samples.isEmpty else { return }
            var sourceCount = samples.count
            if sourceCount > storage.count {
                sourceBase = sourceBase.advanced(by: sourceCount - storage.count)
                sourceCount = storage.count
            }

            bufferLock.lock()
            let overflowCount = max(0, availableSampleCount + sourceCount - storage.count)
            if overflowCount > 0 {
                readIndex = (readIndex + overflowCount) % storage.count
                availableSampleCount -= overflowCount
            }

            storage.withUnsafeMutableBufferPointer { destination in
                guard let destinationBase = destination.baseAddress else { return }
                let firstCopyCount = min(sourceCount, storage.count - writeIndex)
                memcpy(
                    destinationBase.advanced(by: writeIndex),
                    sourceBase,
                    firstCopyCount * MemoryLayout<Float32>.size
                )
                let secondCopyCount = sourceCount - firstCopyCount
                if secondCopyCount > 0 {
                    memcpy(
                        destinationBase,
                        sourceBase.advanced(by: firstCopyCount),
                        secondCopyCount * MemoryLayout<Float32>.size
                    )
                }
            }
            writeIndex = (writeIndex + sourceCount) % storage.count
            availableSampleCount += sourceCount
            bufferLock.unlock()
        }

    }

    private final class RouteOutputRenderer {
        private let queue: AudioQueueRef
        private let pipe: PCMBufferPipe
        private let bufferByteSize: UInt32
        private let callbackQueue: DispatchQueue
        private let stopLock = NSLock()
        private var stopped = false

        init(format: AudioStreamBasicDescription, outputDeviceUID: String, pipe: PCMBufferPipe) throws {
            self.pipe = pipe
            self.bufferByteSize = RouteAudioQualityPolicy.outputBufferByteSize(for: format)
            self.callbackQueue = DispatchQueue(
                label: "com.local.AudioRouter.route-output.\(UUID().uuidString)",
                qos: .userInteractive,
                autoreleaseFrequency: .workItem
            )

            var mutableFormat = format
            var queueRef: AudioQueueRef?
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

            for _ in 0..<RouteAudioQualityPolicy.outputQueueBufferCount {
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

        private static func check(_ status: OSStatus, _ operation: String) throws {
            guard status == noErr else {
                throw AudioRouterError.coreAudio(operation, status)
            }
        }
    }

    private var sessions: [String: RouteSession] = [:]
    private var pendingVolumes: [String: Double] = [:]
    private var pendingMutes: [String: Bool] = [:]
    private var currentEQBands: [Double] = EQPreset.flat.bands

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
        try startRoute(source: source, outputDevices: [outputDevice])
    }

    func startRoute(source: AudioSource, outputDevices: [AudioDevice]) throws {
        guard isSupportedOnThisOS else {
            throw AudioRoutingBackendError.unsupported("Live per-app routes require macOS 14.2 or newer.")
        }
        guard !outputDevices.isEmpty else {
            throw AudioRoutingBackendError.unsupported("Add at least one connected output to this group.")
        }
        guard outputDevices.allSatisfy({ $0.kind == .output && $0.isAlive }) else {
            throw AudioRoutingBackendError.unsupported("The selected output device is not available.")
        }
        guard let processObjectID = source.audioObjectID else {
            throw AudioRoutingBackendError.unsupported("AudioRouter cannot see \(source.appName)'s Core Audio process yet. The route was saved and will retry automatically when the process appears.")
        }
        let outputDeviceUIDs = outputDevices.map(\.uid)
        if let session = sessions[source.id], session.outputDeviceUIDs == outputDeviceUIDs {
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
                let sourceQuality = SourceAudioQuality(from: tapFormat)
                let playbackFormat = RouteAudioQualityPolicy.playbackFormat(from: tapFormat, outputDevices: outputDevices)
                HALVirtualInputBridge.shared.prepare()
                let processor = RouteAudioProcessor(format: playbackFormat, eqBands: currentEQBands)
                let pipes = outputDevices.map { _ in
                    PCMBufferPipe(
                        format: playbackFormat,
                        seconds: RouteAudioQualityPolicy.routePipeBufferSeconds
                    )
                }
                let outputRenderers = try zip(outputDevices, pipes).map { outputDevice, pipe in
                    try RouteOutputRenderer(
                        format: playbackFormat,
                        outputDeviceUID: outputDevice.uid,
                        pipe: pipe
                    )
                }
                let aggregateDeviceID = try createAggregateDevice(
                    sourceName: source.appName,
                    tapUID: tapUID
                )

                do {
                    let control = RouteControl(
                        volume: pendingVolumes[source.id] ?? source.volume,
                        muted: pendingMutes[source.id] ?? source.isMuted
                    )
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
                            processor: processor,
                            pipes: pipes
                        )
                    }
                    try check(ioStatus, "Create route IO callback")

                    guard let ioProcID else {
                        throw AudioRouterError.coreAudio("Create route IO callback", kAudioHardwareUnspecifiedError)
                    }

                    do {
                        try check(AudioDeviceStart(aggregateDeviceID, ioProcID), "Start route IO")
                        sessions[source.id] = RouteSession(
                            sourceID: source.id,
                            outputDeviceUIDs: outputDeviceUIDs,
                            tapID: tapID,
                            aggregateDeviceID: aggregateDeviceID,
                            ioProcID: ioProcID,
                            control: control,
                            processor: processor,
                            pipes: pipes,
                            outputRenderers: outputRenderers,
                            sourceQuality: sourceQuality,
                            sourceQualityCheckedAt: Date()
                        )
                    } catch {
                        AudioDeviceDestroyIOProcID(aggregateDeviceID, ioProcID)
                        throw error
                    }
                } catch {
                    AudioHardwareDestroyAggregateDevice(aggregateDeviceID)
                    outputRenderers.forEach { $0.stop() }
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

    func probeSourceAudioQuality(source: AudioSource) throws -> SourceAudioQuality {
        guard isSupportedOnThisOS else {
            throw AudioRoutingBackendError.unsupported("Source quality probing requires macOS 14.2 or newer.")
        }
        guard let processObjectID = source.audioObjectID else {
            throw AudioRoutingBackendError.unsupported("AudioRouter cannot see \(source.appName)'s Core Audio process yet.")
        }

        if #available(macOS 14.2, *) {
            let tapDescription = CATapDescription(stereoMixdownOfProcesses: [AudioObjectID(processObjectID)])
            tapDescription.name = "AudioRouter \(source.appName) Quality Probe"
            tapDescription.isPrivate = true
            tapDescription.muteBehavior = .unmuted

            var tapID = AudioObjectID(kAudioObjectUnknown)
            try checkTapStatus(
                AudioHardwareCreateProcessTap(tapDescription, &tapID),
                operation: "Create source quality process tap"
            )
            defer {
                AudioHardwareDestroyProcessTap(tapID)
            }

            return SourceAudioQuality(from: try streamFormat(tapID))
        }

        throw AudioRoutingBackendError.unsupported("Source quality probing is unavailable on this macOS version.")
    }

    func stopRoute(sourceID: String) {
        guard let session = sessions.removeValue(forKey: sourceID) else { return }
        AudioDeviceStop(session.aggregateDeviceID, session.ioProcID)
        AudioDeviceDestroyIOProcID(session.aggregateDeviceID, session.ioProcID)
        AudioHardwareDestroyAggregateDevice(session.aggregateDeviceID)
        session.outputRenderers.forEach { $0.stop() }
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

    func setEQState(_ state: EQState) {
        currentEQBands = state.bands
        for session in sessions.values {
            session.processor.setEQBands(state.bands)
        }
    }

    func currentLevel(sourceID: String) -> Double? {
        sessions[sourceID]?.control.level()
    }

    func sourceAudioQuality(sourceID: String) -> SourceAudioQuality? {
        guard var session = sessions[sourceID] else {
            return nil
        }

        let now = Date()
        guard now.timeIntervalSince(session.sourceQualityCheckedAt) >= RouteAudioQualityPolicy.liveSourceQualityRefreshInterval else {
            return session.sourceQuality
        }

        if let format = try? streamFormat(session.tapID) {
            session.sourceQuality = SourceAudioQuality(from: format)
        }
        session.sourceQualityCheckedAt = now
        sessions[sourceID] = session
        return session.sourceQuality
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
            kAudioSubTapDriftCompensationQualityKey: kAudioAggregateDriftCompensationHighQuality
        ]
        let description: [String: Any] = [
            kAudioAggregateDeviceUIDKey: aggregateUID,
            kAudioAggregateDeviceNameKey: "AudioRouter Route \(sourceName)",
            kAudioAggregateDeviceIsPrivateKey: 1,
            kAudioAggregateDeviceTapListKey: [tap],
            kAudioAggregateDeviceTapAutoStartKey: 1
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

    private static func capture(
        inputData: UnsafePointer<AudioBufferList>,
        outputData: UnsafeMutablePointer<AudioBufferList>,
        control: RouteControl,
        processor: RouteAudioProcessor,
        pipes: [PCMBufferPipe]
    ) {
        let outputBuffers = UnsafeMutableAudioBufferListPointer(outputData)
        zero(outputBuffers)
        let gain = control.gain()
        HALVirtualInputBridge.shared.writeInterleavedFloat32(from: inputData, gain: gain)
        let level = processor.writeInterleavedFloat32(from: inputData, gain: gain) { samples in
            for pipe in pipes {
                pipe.write(samples: samples)
            }
        }
        control.updateLevel(level)
    }

    private static func zero(_ outputBuffers: UnsafeMutableAudioBufferListPointer) {
        for buffer in outputBuffers {
            guard let data = buffer.mData else { continue }
            memset(data, 0, Int(buffer.mDataByteSize))
        }
    }
}

private extension SourceAudioQuality {
    init(from format: AudioStreamBasicDescription) {
        let channelCount = max(1, Int(format.mChannelsPerFrame))
        let derivedBitDepth: Int
        if format.mBitsPerChannel > 0 {
            derivedBitDepth = Int(format.mBitsPerChannel)
        } else if format.mBytesPerFrame > 0 {
            derivedBitDepth = max(0, Int(format.mBytesPerFrame) * 8 / channelCount)
        } else {
            derivedBitDepth = 0
        }

        self.init(
            sampleRate: format.mSampleRate,
            bitDepth: derivedBitDepth,
            channelCount: channelCount,
            isFloatPCM: format.mFormatID == kAudioFormatLinearPCM
                && (format.mFormatFlags & kAudioFormatFlagIsFloat) != 0
        )
    }
}
