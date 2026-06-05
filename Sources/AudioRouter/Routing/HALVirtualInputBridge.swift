import CoreAudio
import Darwin
import Foundation

final class HALVirtualInputBridge {
    static let shared = HALVirtualInputBridge()

    private let lock = NSLock()
    private var mapping: UnsafeMutableRawPointer?
    private var samples: UnsafeMutablePointer<Float32>?

    private let sharedMemoryPath = "/tmp/AudioRouterHALInputV1.buffer"
    private let magic: UInt32 = 0x41524931
    private let version: UInt32 = 1
    private let channelCount = 2
    private let sampleRate: UInt32 = 48_000
    private let frameCapacity = 96_000
    private let headerByteSize = 32
    private let writeFrameOffset = 24

    private var byteSize: Int {
        headerByteSize + frameCapacity * channelCount * MemoryLayout<Float32>.stride
    }

    private init() {}

    deinit {
        if let mapping {
            munmap(mapping, byteSize)
        }
    }

    func prepare() {
        lock.lock()
        defer { lock.unlock() }
        guard mapping == nil else { return }

        if !FileManager.default.fileExists(atPath: sharedMemoryPath) {
            FileManager.default.createFile(atPath: sharedMemoryPath, contents: nil)
        }

        let fd = Darwin.open(sharedMemoryPath, O_RDWR)
        guard fd >= 0 else { return }
        defer { close(fd) }

        guard ftruncate(fd, off_t(byteSize)) == 0 else { return }
        let mappedResult = mmap(nil, byteSize, PROT_READ | PROT_WRITE, MAP_SHARED, fd, 0)
        guard let mapped = mappedResult,
              mapped != UnsafeMutableRawPointer(bitPattern: -1) else { return }

        mapping = mapped
        samples = mapped.advanced(by: headerByteSize).assumingMemoryBound(to: Float32.self)
        initializeHeaderIfNeeded(mapped)
    }

    func writeInterleavedFloat32(
        from inputData: UnsafePointer<AudioBufferList>,
        gain: Float
    ) {
        guard let mapping, let samples else { return }
        let inputBuffers = UnsafeMutableAudioBufferListPointer(UnsafeMutablePointer(mutating: inputData))
        guard let frameCount = frameCount(for: inputBuffers), frameCount > 0 else { return }

        var writeFrame = mapping.load(fromByteOffset: writeFrameOffset, as: UInt64.self)
        let clampedGain = max(0, min(4, gain))
        for frame in 0..<frameCount {
            let outputFrame = Int(writeFrame % UInt64(frameCapacity)) * channelCount
            samples[outputFrame] = Self.peakLimited(sampleAt(frame: frame, channel: 0, inputBuffers: inputBuffers) * clampedGain)
            samples[outputFrame + 1] = Self.peakLimited(sampleAt(frame: frame, channel: 1, inputBuffers: inputBuffers) * clampedGain)
            writeFrame += 1
        }
        mapping.storeBytes(of: writeFrame, toByteOffset: writeFrameOffset, as: UInt64.self)
    }

    private func initializeHeaderIfNeeded(_ mapping: UnsafeMutableRawPointer) {
        let storedMagic = mapping.load(fromByteOffset: 0, as: UInt32.self)
        let storedVersion = mapping.load(fromByteOffset: 4, as: UInt32.self)
        let storedChannels = mapping.load(fromByteOffset: 8, as: UInt32.self)
        let storedCapacity = mapping.load(fromByteOffset: 16, as: UInt32.self)
        guard storedMagic == magic,
              storedVersion == version,
              storedChannels == UInt32(channelCount),
              storedCapacity == UInt32(frameCapacity) else {
            memset(mapping, 0, byteSize)
            mapping.storeBytes(of: magic, toByteOffset: 0, as: UInt32.self)
            mapping.storeBytes(of: version, toByteOffset: 4, as: UInt32.self)
            mapping.storeBytes(of: UInt32(channelCount), toByteOffset: 8, as: UInt32.self)
            mapping.storeBytes(of: sampleRate, toByteOffset: 12, as: UInt32.self)
            mapping.storeBytes(of: UInt32(frameCapacity), toByteOffset: 16, as: UInt32.self)
            mapping.storeBytes(of: UInt32(0), toByteOffset: 20, as: UInt32.self)
            mapping.storeBytes(of: UInt64(0), toByteOffset: writeFrameOffset, as: UInt64.self)
            return
        }
    }

    private func frameCount(for inputBuffers: UnsafeMutableAudioBufferListPointer) -> Int? {
        guard !inputBuffers.isEmpty else { return nil }
        if inputBuffers.count == 1 {
            let buffer = inputBuffers[0]
            let channels = max(1, Int(buffer.mNumberChannels))
            return Int(buffer.mDataByteSize) / (MemoryLayout<Float32>.stride * channels)
        }
        return inputBuffers.compactMap { buffer in
            buffer.mData == nil ? nil : Int(buffer.mDataByteSize) / MemoryLayout<Float32>.stride
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
            let inputChannels = max(1, Int(buffer.mNumberChannels))
            let samples = data.assumingMemoryBound(to: Float32.self)
            return samples[frame * inputChannels + min(channel, inputChannels - 1)]
        }

        let buffer = inputBuffers[min(channel, inputBuffers.count - 1)]
        guard let data = buffer.mData else { return 0 }
        let inputChannels = max(1, Int(buffer.mNumberChannels))
        let samples = data.assumingMemoryBound(to: Float32.self)
        if inputChannels == 1 {
            return samples[frame]
        }
        return samples[frame * inputChannels + min(channel, inputChannels - 1)]
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
