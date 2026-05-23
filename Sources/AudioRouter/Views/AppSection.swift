import Foundation

enum AppSection: String, CaseIterable, Identifiable {
    case routes = "Home"
    case devices = "Devices"
    case processes = "Applications"
    case permissions = "Permission"
    case diagnostics = "Diagnostics"

    var id: String { rawValue }

    var systemImage: String {
        switch self {
        case .routes:
            return "arrow.triangle.branch"
        case .devices:
            return "speaker.wave.2"
        case .processes:
            return "app.connected.to.app.below.fill"
        case .permissions:
            return "lock.shield"
        case .diagnostics:
            return "waveform.path.ecg"
        }
    }
}
