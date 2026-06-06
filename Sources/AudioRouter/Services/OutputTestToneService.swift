import AudioToolbox
import CoreAudio
import Darwin
import Foundation

public final class OutputTestToneService {
    private final class ToneSession {
        let queue: AudioQueueRef
        let duration: TimeInterval
        var buffers: [AudioQueueBufferRef] = []

        init(queue: AudioQueueRef, duration: TimeInterval) {
            self.queue = queue
            self.duration = duration
        }

        deinit {
            AudioQueueStop(queue, true)
            AudioQueueDispose(queue, true)
        }
    }

    private var activeSessions: [String: ToneSession] = [:]

    public init() {}

    public func playTestTone(
        deviceUID: String,
        frequency: Double = 880,
        duration: TimeInterval = 0.72,
        volume: Double = 0.18
    ) throws {
        stopTestTone(deviceUID: deviceUID)

        let format = Self.testToneFormat
        var mutableFormat = format
        var queueRef: AudioQueueRef?
        let callback: AudioQueueOutputCallback = { _, _, _ in }
        try Self.check(
            AudioQueueNewOutput(&mutableFormat, callback, nil, nil, nil, 0, &queueRef),
            operation: "Create test tone output"
        )
        guard let queueRef else {
            throw AudioRouterError.coreAudio("Create test tone output", kAudioHardwareUnspecifiedError)
        }

        do {
            var currentDeviceUID = deviceUID as CFString
            try Self.check(
                withUnsafePointer(to: &currentDeviceUID) { pointer in
                    AudioQueueSetProperty(
                        queueRef,
                        kAudioQueueProperty_CurrentDevice,
                        pointer,
                        UInt32(MemoryLayout<CFString>.size)
                    )
                },
                operation: "Select test tone output"
            )

            let session = ToneSession(queue: queueRef, duration: duration)
            try enqueueToneBuffers(
                into: queueRef,
                session: session,
                format: format,
                frequency: frequency,
                duration: duration,
                volume: volume
            )
            try Self.check(AudioQueueStart(queueRef, nil), operation: "Start test tone")
            activeSessions[deviceUID] = session

            Task { @MainActor [weak self] in
                try? await Task.sleep(nanoseconds: UInt64((duration + 0.18) * 1_000_000_000))
                self?.stopTestTone(deviceUID: deviceUID)
            }
        } catch {
            AudioQueueDispose(queueRef, true)
            throw error
        }
    }

    public func stopAll() {
        activeSessions.removeAll()
    }

    private func stopTestTone(deviceUID: String) {
        activeSessions.removeValue(forKey: deviceUID)
    }

    private func enqueueToneBuffers(
        into queue: AudioQueueRef,
        session: ToneSession,
        format: AudioStreamBasicDescription,
        frequency: Double,
        duration: TimeInterval,
        volume: Double
    ) throws {
        let sampleRate = format.mSampleRate
        let channelCount = Int(format.mChannelsPerFrame)
        let framesPerBuffer = Int(sampleRate * 0.08)
        let totalFrames = max(framesPerBuffer, Int(sampleRate * duration))
        let bytesPerFrame = Int(format.mBytesPerFrame)
        let amplitude = Float32(max(0, min(1, volume)))
        let fadeFrames = max(1, Int(sampleRate * 0.025))
        var producedFrames = 0

        while producedFrames < totalFrames {
            let frames = min(framesPerBuffer, totalFrames - producedFrames)
            let byteSize = UInt32(frames * bytesPerFrame)
            var buffer: AudioQueueBufferRef?
            try Self.check(
                AudioQueueAllocateBuffer(queue, byteSize, &buffer),
                operation: "Allocate test tone buffer"
            )
            guard let buffer else {
                throw AudioRouterError.coreAudio("Allocate test tone buffer", kAudioHardwareUnspecifiedError)
            }

            let samples = buffer.pointee.mAudioData.assumingMemoryBound(to: Float32.self)
            for frame in 0..<frames {
                let absoluteFrame = producedFrames + frame
                let phase = (Double(absoluteFrame) / sampleRate) * frequency * 2 * Double.pi
                let fadeIn = min(1, Double(absoluteFrame) / Double(fadeFrames))
                let fadeOut = min(1, Double(totalFrames - absoluteFrame) / Double(fadeFrames))
                let envelope = Float32(min(fadeIn, fadeOut))
                let sample = sin(phase) * Double(amplitude * envelope)
                for channel in 0..<channelCount {
                    samples[frame * channelCount + channel] = Float32(sample)
                }
            }

            buffer.pointee.mAudioDataByteSize = byteSize
            try Self.check(AudioQueueEnqueueBuffer(queue, buffer, 0, nil), operation: "Enqueue test tone")
            session.buffers.append(buffer)
            producedFrames += frames
        }
    }

    private static var testToneFormat: AudioStreamBasicDescription {
        let channelCount: UInt32 = 2
        let bytesPerSample = UInt32(MemoryLayout<Float32>.size)
        return AudioStreamBasicDescription(
            mSampleRate: 48_000,
            mFormatID: kAudioFormatLinearPCM,
            mFormatFlags: kAudioFormatFlagIsFloat | kAudioFormatFlagIsPacked | kAudioFormatFlagsNativeEndian,
            mBytesPerPacket: channelCount * bytesPerSample,
            mFramesPerPacket: 1,
            mBytesPerFrame: channelCount * bytesPerSample,
            mChannelsPerFrame: channelCount,
            mBitsPerChannel: 32,
            mReserved: 0
        )
    }

    private static func check(_ status: OSStatus, operation: String) throws {
        guard status == noErr else {
            throw AudioRouterError.coreAudio(operation, status)
        }
    }
}
