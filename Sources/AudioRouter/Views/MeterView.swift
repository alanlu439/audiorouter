import SwiftUI

struct MeterView: View {
    let level: Double
    var barCount: Int = 10
    var height: CGFloat = 18
    var color: Color = .green

    var body: some View {
        HStack(spacing: 3) {
            ForEach(0..<barCount, id: \.self) { index in
                Capsule()
                    .fill(indexLevel(index) <= level ? color : Color.secondary.opacity(0.16))
                    .frame(width: 5, height: heightForBar(index))
                    .animation(.easeOut(duration: 0.14), value: level)
            }
        }
        .frame(height: height)
        .accessibilityLabel("Audio level")
    }

    private func indexLevel(_ index: Int) -> Double {
        Double(index + 1) / Double(barCount)
    }

    private func heightForBar(_ index: Int) -> CGFloat {
        let progress = CGFloat(index + 1) / CGFloat(barCount)
        return max(5, height * (0.35 + progress * 0.65))
    }
}

struct StatusLabel: View {
    let text: String
    var status: RouteVisualStatus = .working

    var body: some View {
        Label(text, systemImage: status.systemImage)
            .font(.caption2.weight(.bold))
            .foregroundStyle(status.foreground)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(status.background, in: Capsule())
    }
}

enum RouteVisualStatus {
    case working
    case simulated
    case requiresDriver
    case unsupported
    case deviceMissing

    var systemImage: String {
        switch self {
        case .working: return "checkmark.circle.fill"
        case .simulated: return "sparkles"
        case .requiresDriver: return "exclamationmark.triangle.fill"
        case .unsupported: return "nosign"
        case .deviceMissing: return "questionmark.circle.fill"
        }
    }

    var foreground: Color {
        switch self {
        case .working: return .green
        case .simulated: return .cyan
        case .requiresDriver: return .orange
        case .unsupported, .deviceMissing: return .red
        }
    }

    var background: Color {
        foreground.opacity(0.12)
    }
}
