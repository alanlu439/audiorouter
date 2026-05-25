import Foundation

public struct RouteHealthItem: Identifiable, Hashable {
    public let id: String
    public let title: String
    public let detail: String
    public let state: BackendReadinessState

    public init(id: String, title: String, detail: String, state: BackendReadinessState) {
        self.id = id
        self.title = title
        self.detail = detail
        self.state = state
    }
}

public enum SuggestedSetupKind: String, CaseIterable, Identifiable {
    case deskSpeakers = "Desk Speakers"
    case airPodsCall = "AirPods Call"
    case musicToBluetooth = "Music to Bluetooth"
    case focusMode = "Focus Mode"

    public var id: String { rawValue }

    public var systemImage: String {
        switch self {
        case .deskSpeakers: return "speaker.wave.2.fill"
        case .airPodsCall: return "headphones"
        case .musicToBluetooth: return "music.note.list"
        case .focusMode: return "moon.fill"
        }
    }

    public var description: String {
        switch self {
        case .deskSpeakers:
            return "Built-in speaker setup for normal desk work."
        case .airPodsCall:
            return "Bluetooth headset setup for calls and meetings."
        case .musicToBluetooth:
            return "Routes music apps toward the first Bluetooth output."
        case .focusMode:
            return "Muted app setup for quiet focus sessions."
        }
    }
}
