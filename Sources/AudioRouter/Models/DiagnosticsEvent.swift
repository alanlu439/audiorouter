import Foundation

struct DiagnosticsEvent: Identifiable, Hashable {
    let id = UUID()
    let timestamp: Date
    let level: DiagnosticsLevel
    let message: String
}

enum DiagnosticsLevel: String, Hashable {
    case info = "Info"
    case warning = "Warning"
    case error = "Error"

    var systemImage: String {
        switch self {
        case .info:
            return "info.circle"
        case .warning:
            return "exclamationmark.triangle"
        case .error:
            return "xmark.octagon"
        }
    }
}
