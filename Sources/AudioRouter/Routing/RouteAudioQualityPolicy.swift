import CoreAudio
import Foundation

public enum RouteAudioQualityPolicy {
    public static let maximumGain: Double = 1.5
    public static let unityGainSnapTolerance: Double = 0.01
    public static let liveSourceQualityRefreshInterval: TimeInterval = 1.0
    public static let maximumRenderedChannels = 8
    public static let routePipeBufferSeconds: Double = 2.0
    public static let outputQueueBufferCount = 5

    private static let commonHardwareSampleRates: [Double] = [
        44_100, 48_000, 88_200, 96_000, 176_400, 192_000
    ]

    public static func playbackFormat(
        from tapFormat: AudioStreamBasicDescription,
        outputDevices: [AudioDevice]
    ) -> AudioStreamBasicDescription {
        let channels = UInt32(renderedChannelCount(tapFormat: tapFormat, outputDevices: outputDevices))
        let bytesPerFrame = channels * UInt32(MemoryLayout<Float32>.size)
        return AudioStreamBasicDescription(
            mSampleRate: preferredSampleRate(tapFormat: tapFormat, outputDevices: outputDevices),
            mFormatID: kAudioFormatLinearPCM,
            mFormatFlags: kAudioFormatFlagIsFloat | kAudioFormatFlagIsPacked | kAudioFormatFlagsNativeEndian,
            mBytesPerPacket: bytesPerFrame,
            mFramesPerPacket: 1,
            mBytesPerFrame: bytesPerFrame,
            mChannelsPerFrame: channels,
            mBitsPerChannel: 32,
            mReserved: 0
        )
    }

    public static func renderedChannelCount(
        tapFormat: AudioStreamBasicDescription,
        outputDevices: [AudioDevice]
    ) -> Int {
        let tapChannels = max(1, Int(tapFormat.mChannelsPerFrame))
        let outputChannels = max(1, outputDevices.map(\.channelCount).min() ?? tapChannels)
        return max(1, min(tapChannels, outputChannels, maximumRenderedChannels))
    }

    public static func preferredSampleRate(
        tapFormat: AudioStreamBasicDescription,
        outputDevices: [AudioDevice]
    ) -> Double {
        let tapRate = tapFormat.mSampleRate > 0 ? tapFormat.mSampleRate : nil
        if let tapRate {
            return tapRate
        }

        return outputDevices.compactMap(\.sampleRate).first(where: { $0 > 0 }) ?? 48_000
    }

    public static func outputSupports(sampleRate: Double, device: AudioDevice) -> Bool {
        guard let ranges = device.availableSampleRateRanges, !ranges.isEmpty else {
            return true
        }
        return ranges.contains { $0.contains(sampleRate) }
    }

    public static func normalizedGain(_ volume: Double) -> Double {
        let clamped = max(0, min(maximumGain, volume))
        return abs(clamped - 1) <= unityGainSnapTolerance ? 1 : clamped
    }

    public static func allOutputsSupport(sampleRate: Double, outputDevices: [AudioDevice]) -> Bool {
        outputDevices.allSatisfy { outputSupports(sampleRate: sampleRate, device: $0) }
    }

    private static func nearestSharedSampleRate(to targetRate: Double, outputDevices: [AudioDevice]) -> Double? {
        var candidates = Set<Double>()
        for rate in commonHardwareSampleRates {
            if allOutputsSupport(sampleRate: rate, outputDevices: outputDevices) {
                candidates.insert(rate)
            }
        }
        for device in outputDevices {
            if let sampleRate = device.sampleRate, sampleRate > 0,
               allOutputsSupport(sampleRate: sampleRate, outputDevices: outputDevices) {
                candidates.insert(sampleRate)
            }
            for range in device.availableSampleRateRanges ?? [] {
                let nearest = range.nearestValue(to: targetRate)
                if allOutputsSupport(sampleRate: nearest, outputDevices: outputDevices) {
                    candidates.insert(nearest)
                }
            }
        }

        return candidates.sorted { lhs, rhs in
            let lhsDistance = abs(lhs - targetRate)
            let rhsDistance = abs(rhs - targetRate)
            if abs(lhsDistance - rhsDistance) > 0.001 {
                return lhsDistance < rhsDistance
            }
            if lhs <= targetRate && rhs > targetRate {
                return true
            }
            if rhs <= targetRate && lhs > targetRate {
                return false
            }
            return lhs > rhs
        }.first
    }
}
