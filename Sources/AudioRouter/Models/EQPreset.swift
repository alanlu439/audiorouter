import Foundation

public enum EQPreset: String, Codable, CaseIterable, Identifiable {
    case flat = "Flat"
    case bassBoost = "Bass Boost"
    case vocal = "Vocal"
    case podcast = "Podcast"
    case movie = "Movie"
    case music = "Music"
    case custom = "Custom"

    public var id: String { rawValue }

    public var bands: [Double] {
        switch self {
        case .flat:
            return Array(repeating: 0, count: 10)
        case .bassBoost:
            return [6, 5, 4, 2, 0, -1, -1, 0, 1, 2]
        case .vocal:
            return [-2, -1, 0, 2, 4, 5, 4, 2, 0, -1]
        case .podcast:
            return [-3, -2, 0, 3, 5, 4, 2, 0, -2, -3]
        case .movie:
            return [3, 2, 1, 0, 1, 2, 3, 4, 4, 3]
        case .music:
            return [2, 1, 0, 1, 2, 1, 0, 1, 2, 2]
        case .custom:
            return Array(repeating: 0, count: 10)
        }
    }

    public static let bandLabels = ["31", "62", "125", "250", "500", "1k", "2k", "4k", "8k", "16k"]
}

public struct EQState: Codable, Equatable {
    public var selectedPreset: EQPreset
    public var bands: [Double]
    public var customBands: [Double]

    private enum CodingKeys: String, CodingKey {
        case selectedPreset
        case bands
        case customBands
    }

    public init(
        selectedPreset: EQPreset = .flat,
        bands: [Double] = EQPreset.flat.bands,
        customBands: [Double] = EQPreset.flat.bands
    ) {
        self.selectedPreset = selectedPreset
        self.bands = bands
        self.customBands = customBands
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        selectedPreset = try container.decodeIfPresent(EQPreset.self, forKey: .selectedPreset) ?? .flat
        bands = try container.decodeIfPresent([Double].self, forKey: .bands) ?? selectedPreset.bands
        customBands = try container.decodeIfPresent([Double].self, forKey: .customBands)
            ?? (selectedPreset == .custom ? bands : EQPreset.flat.bands)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(selectedPreset, forKey: .selectedPreset)
        try container.encode(bands, forKey: .bands)
        try container.encode(customBands, forKey: .customBands)
    }
}
