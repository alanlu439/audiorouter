import Foundation

public enum EQPreset: String, Codable, CaseIterable, Identifiable {
    case flat = "Flat"
    case bassBoost = "Bass Boost"
    case vocal = "Vocal"
    case podcast = "Podcast"
    case movie = "Movie"
    case music = "Music"

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
        }
    }

    public static let bandLabels = ["31", "62", "125", "250", "500", "1k", "2k", "4k", "8k", "16k"]
}

public struct EQState: Codable, Equatable {
    public var selectedPreset: EQPreset
    public var bands: [Double]

    public init(selectedPreset: EQPreset = .flat, bands: [Double] = EQPreset.flat.bands) {
        self.selectedPreset = selectedPreset
        self.bands = bands
    }
}
