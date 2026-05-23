import CoreAudio
import Foundation

final class CoreAudioRouteEngine {
    private var sessions: [UUID: ActiveRouteSession] = [:]

    var activeRouteIDs: Set<UUID> {
        Set(sessions.keys)
    }

    var routeLevels: [UUID: Float] {
        sessions.mapValues { session in
            guard let pointer = session.levelPointer else { return 0 }
            return max(0, min(pointer.pointee, 1))
        }
    }

    func start(route: RouteRule, process: AudioProcessInfo, device: AudioDeviceInfo) throws {
        guard #available(macOS 14.2, *) else {
            throw AudioRoutingError.unsupportedSystem
        }
        guard sessions[route.id] == nil else {
            throw AudioRoutingError.routeAlreadyRunning
        }

        var session = ActiveRouteSession(routeID: route.id)

        do {
            let levelPointer = UnsafeMutablePointer<Float>.allocate(capacity: 1)
            levelPointer.initialize(to: 0)
            session.levelPointer = levelPointer
            let volumePointer = UnsafeMutablePointer<Float>.allocate(capacity: 1)
            volumePointer.initialize(to: clampedVolume(route.volume))
            session.volumePointer = volumePointer

            let tapDescription: CATapDescription
            if process.processObjectID != 0 {
                tapDescription = CATapDescription(stereoMixdownOfProcesses: [process.processObjectID])
            } else if #available(macOS 26.0, *), let bundleID = process.bundleID ?? route.bundleID {
                tapDescription = CATapDescription()
                tapDescription.bundleIDs = [bundleID]
                tapDescription.isProcessRestoreEnabled = true
            } else {
                throw AudioRoutingError.missingProcess
            }

            tapDescription.name = "AudioRouter \(process.displayName)"
            tapDescription.isPrivate = true
            tapDescription.isMixdown = true
            tapDescription.isMono = false
            tapDescription.isExclusive = false
            tapDescription.muteBehavior = CATapMuteBehavior(rawValue: 2)!

            var tapID = AudioObjectID(kAudioObjectUnknown)
            try check(AudioHardwareCreateProcessTap(tapDescription, &tapID), "Create process tap")
            session.tapID = tapID

            let tapUID = try stringProperty(tapID, selector: kAudioTapPropertyUID)
            let aggregateUID = "com.local.AudioRouter.route.\(route.id.uuidString)"
            var aggregateID = AudioObjectID(kAudioObjectUnknown)
            let aggregateDescription: [String: Any] = [
                kAudioAggregateDeviceNameKey: "AudioRouter \(process.displayName)",
                kAudioAggregateDeviceUIDKey: aggregateUID,
                kAudioAggregateDeviceIsPrivateKey: 1,
                kAudioAggregateDeviceMainSubDeviceKey: device.uid,
                kAudioAggregateDeviceClockDeviceKey: device.uid,
                kAudioAggregateDeviceSubDeviceListKey: [
                    [
                        kAudioSubDeviceUIDKey: device.uid,
                        kAudioSubDeviceDriftCompensationKey: 1
                    ]
                ],
                kAudioAggregateDeviceTapListKey: [
                    [
                        kAudioSubTapUIDKey: tapUID,
                        kAudioSubTapDriftCompensationKey: 1
                    ]
                ]
            ]

            try check(
                AudioHardwareCreateAggregateDevice(aggregateDescription as CFDictionary, &aggregateID),
                "Create aggregate route device"
            )
            session.aggregateID = aggregateID

            var ioProcID: AudioDeviceIOProcID?
            let ioBlock: AudioDeviceIOBlock = { _, inputData, _, outputData, _ in
                AudioBufferCopier.copyInput(
                    inputData,
                    to: outputData,
                    levelPointer: levelPointer,
                    volumePointer: volumePointer
                )
            }
            try check(
                AudioDeviceCreateIOProcIDWithBlock(&ioProcID, aggregateID, nil, ioBlock),
                "Create route IO proc"
            )
            session.ioProcID = ioProcID

            try check(AudioDeviceStart(aggregateID, ioProcID), "Start route device")
            sessions[route.id] = session
        } catch {
            cleanup(session)
            throw error
        }
    }

    func setVolume(routeID: UUID, volume: Double) {
        sessions[routeID]?.volumePointer?.pointee = clampedVolume(volume)
    }

    func stop(routeID: UUID) {
        guard let session = sessions.removeValue(forKey: routeID) else { return }
        cleanup(session)
    }

    func stopAll() {
        let currentSessions = sessions.values
        sessions.removeAll()
        currentSessions.forEach(cleanup)
    }

    deinit {
        stopAll()
    }

    private func cleanup(_ session: ActiveRouteSession) {
        if let aggregateID = session.aggregateID, let ioProcID = session.ioProcID {
            AudioDeviceStop(aggregateID, ioProcID)
            AudioDeviceDestroyIOProcID(aggregateID, ioProcID)
        }
        if let aggregateID = session.aggregateID {
            AudioHardwareDestroyAggregateDevice(aggregateID)
        }
        if let tapID = session.tapID {
            if #available(macOS 14.2, *) {
                AudioHardwareDestroyProcessTap(tapID)
            }
        }
        if let levelPointer = session.levelPointer {
            levelPointer.deinitialize(count: 1)
            levelPointer.deallocate()
        }
        if let volumePointer = session.volumePointer {
            volumePointer.deinitialize(count: 1)
            volumePointer.deallocate()
        }
    }

    private func clampedVolume(_ volume: Double) -> Float {
        Float(max(0, min(volume, 1.5)))
    }

    private func stringProperty(
        _ objectID: AudioObjectID,
        selector: AudioObjectPropertySelector
    ) throws -> String {
        var address = AudioObjectPropertyAddress(
            mSelector: selector,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var value: CFString = "" as CFString
        var size = UInt32(MemoryLayout<CFString>.size)
        let status = withUnsafeMutablePointer(to: &value) { pointer in
            AudioObjectGetPropertyData(objectID, &address, 0, nil, &size, pointer)
        }
        try check(status, "Read tap UID")
        return value as String
    }

    private func check(_ status: OSStatus, _ operation: String) throws {
        guard status == noErr else {
            throw AudioRoutingError.coreAudio(operation, status)
        }
    }
}

private struct ActiveRouteSession {
    let routeID: UUID
    var tapID: AudioObjectID?
    var aggregateID: AudioObjectID?
    var ioProcID: AudioDeviceIOProcID?
    var levelPointer: UnsafeMutablePointer<Float>?
    var volumePointer: UnsafeMutablePointer<Float>?
}

private enum AudioBufferCopier {
    static func copyInput(
        _ inputData: UnsafePointer<AudioBufferList>?,
        to outputData: UnsafeMutablePointer<AudioBufferList>?,
        levelPointer: UnsafeMutablePointer<Float>?,
        volumePointer: UnsafeMutablePointer<Float>?
    ) {
        guard let inputData, let outputData else {
            levelPointer?.pointee = 0
            return
        }

        let inputs = UnsafeMutableAudioBufferListPointer(UnsafeMutablePointer(mutating: inputData))
        let outputs = UnsafeMutableAudioBufferListPointer(outputData)
        let volume = volumePointer?.pointee ?? 1
        let peak: Float

        if let mappedPeak = copyInterleavedInputToPlanarOutputs(inputs: inputs, outputs: outputs, volume: volume) {
            peak = mappedPeak
        } else if let mappedPeak = copyPlanarInputsToInterleavedOutput(inputs: inputs, outputs: outputs, volume: volume) {
            peak = mappedPeak
        } else {
            peak = copyMatchingBuffers(inputs: inputs, outputs: outputs, volume: volume)
        }

        levelPointer?.pointee = peak
    }

    private static func copyMatchingBuffers(
        inputs: UnsafeMutableAudioBufferListPointer,
        outputs: UnsafeMutableAudioBufferListPointer,
        volume: Float
    ) -> Float {
        let pairCount = min(inputs.count, outputs.count)
        var peak: Float = 0

        for index in 0..<pairCount {
            guard let source = inputs[index].mData, let destination = outputs[index].mData else {
                continue
            }
            let byteCount = min(Int(inputs[index].mDataByteSize), Int(outputs[index].mDataByteSize))
            guard byteCount > 0 else { continue }
            copy(source, to: destination, byteCount: byteCount, volume: volume)
            peak = max(peak, peakLevel(from: source, byteCount: byteCount, volume: volume))
        }

        return peak
    }

    private static func copyInterleavedInputToPlanarOutputs(
        inputs: UnsafeMutableAudioBufferListPointer,
        outputs: UnsafeMutableAudioBufferListPointer,
        volume: Float
    ) -> Float? {
        guard inputs.count == 1,
              outputs.count > 1,
              let source = inputs[0].mData,
              Int(inputs[0].mNumberChannels) >= outputs.count else {
            return nil
        }

        let sourceChannelCount = max(1, Int(inputs[0].mNumberChannels))
        let sourceFrameCount = Int(inputs[0].mDataByteSize) / MemoryLayout<Float>.stride / sourceChannelCount
        guard sourceFrameCount > 0 else { return 0 }

        let sourceSamples = source.assumingMemoryBound(to: Float.self)
        var peak: Float = 0

        for outputIndex in 0..<outputs.count {
            guard let destination = outputs[outputIndex].mData else { continue }

            let destinationSamples = destination.assumingMemoryBound(to: Float.self)
            let destinationFrameCount = Int(outputs[outputIndex].mDataByteSize) / MemoryLayout<Float>.stride / max(1, Int(outputs[outputIndex].mNumberChannels))
            let frameCount = min(sourceFrameCount, destinationFrameCount)
            guard frameCount > 0 else { continue }

            for frame in 0..<frameCount {
                let scaled = sourceSamples[(frame * sourceChannelCount) + outputIndex] * volume
                let clipped = max(-1, min(scaled, 1))
                destinationSamples[frame] = clipped
                if clipped.isFinite {
                    peak = max(peak, abs(clipped))
                }
            }
        }

        return min(peak, 1)
    }

    private static func copyPlanarInputsToInterleavedOutput(
        inputs: UnsafeMutableAudioBufferListPointer,
        outputs: UnsafeMutableAudioBufferListPointer,
        volume: Float
    ) -> Float? {
        guard inputs.count > 1,
              outputs.count == 1,
              let destination = outputs[0].mData,
              Int(outputs[0].mNumberChannels) >= inputs.count else {
            return nil
        }

        let destinationChannelCount = max(1, Int(outputs[0].mNumberChannels))
        let destinationFrameCount = Int(outputs[0].mDataByteSize) / MemoryLayout<Float>.stride / destinationChannelCount
        guard destinationFrameCount > 0 else { return 0 }

        let destinationSamples = destination.assumingMemoryBound(to: Float.self)
        var peak: Float = 0

        for inputIndex in 0..<inputs.count {
            guard let source = inputs[inputIndex].mData else { continue }

            let sourceSamples = source.assumingMemoryBound(to: Float.self)
            let sourceFrameCount = Int(inputs[inputIndex].mDataByteSize) / MemoryLayout<Float>.stride / max(1, Int(inputs[inputIndex].mNumberChannels))
            let frameCount = min(sourceFrameCount, destinationFrameCount)
            guard frameCount > 0 else { continue }

            for frame in 0..<frameCount {
                let scaled = sourceSamples[frame] * volume
                let clipped = max(-1, min(scaled, 1))
                destinationSamples[(frame * destinationChannelCount) + inputIndex] = clipped
                if clipped.isFinite {
                    peak = max(peak, abs(clipped))
                }
            }
        }

        return min(peak, 1)
    }

    private static func copy(
        _ source: UnsafeMutableRawPointer,
        to destination: UnsafeMutableRawPointer,
        byteCount: Int,
        volume: Float
    ) {
        guard volume != 1 else {
            memcpy(destination, source, byteCount)
            return
        }

        let sampleCount = byteCount / MemoryLayout<Float>.stride
        guard sampleCount > 0 else {
            memcpy(destination, source, byteCount)
            return
        }

        let sourceSamples = source.assumingMemoryBound(to: Float.self)
        let destinationSamples = destination.assumingMemoryBound(to: Float.self)
        for index in 0..<sampleCount {
            destinationSamples[index] = max(-1, min(sourceSamples[index] * volume, 1))
        }

        let copiedByteCount = sampleCount * MemoryLayout<Float>.stride
        if copiedByteCount < byteCount {
            memcpy(destination.advanced(by: copiedByteCount), source.advanced(by: copiedByteCount), byteCount - copiedByteCount)
        }
    }

    private static func peakLevel(from data: UnsafeMutableRawPointer, byteCount: Int, volume: Float) -> Float {
        let sampleCount = byteCount / MemoryLayout<Float>.stride
        guard sampleCount > 0 else { return 0 }

        let samples = data.assumingMemoryBound(to: Float.self)
        let stride = max(1, sampleCount / 1024)
        var peak: Float = 0
        var index = 0

        while index < sampleCount {
            let value = abs(samples[index] * volume)
            if value.isFinite {
                peak = max(peak, value)
            }
            index += stride
        }

        return min(peak, 1)
    }
}
