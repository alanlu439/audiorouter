import Foundation

public struct SourceAudioQuality: Codable, Hashable {
    public let sampleRate: Double
    public let bitDepth: Int
    public let channelCount: Int
    public let isFloatPCM: Bool

    public init(
        sampleRate: Double,
        bitDepth: Int,
        channelCount: Int,
        isFloatPCM: Bool
    ) {
        self.sampleRate = sampleRate
        self.bitDepth = bitDepth
        self.channelCount = max(1, channelCount)
        self.isFloatPCM = isFloatPCM
    }

    public var compactDisplayLabel: String {
        "\(compactSampleRateLabel) · \(compactBitDepthLabel) · \(channelCount)ch"
    }

    public var accessibilityDescription: String {
        "\(sampleRateLabel), \(isFloatPCM ? "floating point" : "integer") \(bitDepth)-bit, \(channelCount) channel\(channelCount == 1 ? "" : "s")"
    }

    private var sampleRateLabel: String {
        guard sampleRate > 0 else { return "Rate N/A" }
        let kilohertz = sampleRate / 1_000
        if abs(kilohertz.rounded() - kilohertz) < 0.01 {
            return "\(Int(kilohertz.rounded())) kHz"
        }
        return String(format: "%.1f kHz", kilohertz)
    }

    private var compactSampleRateLabel: String {
        guard sampleRate > 0 else { return "N/A" }
        let kilohertz = sampleRate / 1_000
        if abs(kilohertz.rounded() - kilohertz) < 0.01 {
            return "\(Int(kilohertz.rounded()))k"
        }
        return String(format: "%.1fk", kilohertz)
    }

    private var bitDepthLabel: String {
        guard bitDepth > 0 else { return "Depth N/A" }
        return isFloatPCM ? "\(bitDepth)-bit float" : "\(bitDepth)-bit"
    }

    private var compactBitDepthLabel: String {
        guard bitDepth > 0 else { return "N/A" }
        return isFloatPCM ? "\(bitDepth)f" : "\(bitDepth)b"
    }
}
