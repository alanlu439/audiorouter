import Foundation

public enum BackendReadinessState: String, Hashable {
    case working
    case live
    case ready
    case demo
    case savedOnly
    case requiresBackend
    case unsupported
    case deviceMissing

    public var badgeTitle: String {
        switch self {
        case .working: return "Working"
        case .live: return "Live"
        case .ready: return "Ready"
        case .demo: return "Demo"
        case .savedOnly: return "Saved Only"
        case .requiresBackend: return "Requires Backend"
        case .unsupported: return "Unsupported"
        case .deviceMissing: return "Device Missing"
        }
    }
}

public struct BackendReadinessItem: Identifiable, Hashable {
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
