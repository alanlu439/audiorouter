import SwiftUI

struct MeterView: View {
    let level: Double
    var barCount: Int = 10
    var height: CGFloat = 18
    var color: Color = .green
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: 3) {
            ForEach(0..<barCount, id: \.self) { index in
                Capsule()
                    .fill(color.opacity(indexLevel(index) <= level ? 0.95 : 0.20))
                    .overlay {
                        Capsule()
                            .stroke(Color.white.opacity(indexLevel(index) <= level ? 0.10 : 0.05), lineWidth: 0.5)
                    }
                    .frame(width: 5, height: heightForBar(index))
                    .shadow(color: color.opacity(indexLevel(index) <= level ? 0.35 : 0), radius: 3)
            }
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 4)
        .frame(height: height + 8)
        .background(Color.black.opacity(0.22), in: Capsule())
        .overlay {
            Capsule()
                .stroke(Color.white.opacity(0.10), lineWidth: 1)
        }
        .animation(reduceMotion ? nil : .easeOut(duration: 0.18), value: level)
        .accessibilityLabel("Audio level")
        .accessibilityValue(level.clampedUnit.roundedPercentDescription)
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
        HStack(spacing: 5) {
            Image(systemName: status.systemImage)
                .font(.caption2.weight(.bold))
                .accessibilityHidden(true)
            Text(text)
                .font(.caption2.weight(.bold))
                .lineLimit(1)
                .minimumScaleFactor(0.78)
        }
            .font(.caption2.weight(.bold))
            .foregroundStyle(status.foreground)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(status.background, in: Capsule())
            .fixedSize(horizontal: true, vertical: false)
            .accessibilityLabel("\(text) status")
    }
}

enum RouteVisualStatus {
    case working
    case live
    case demo
    case savedOnly
    case simulated
    case requiresBackend
    case unsupported
    case deviceMissing

    var systemImage: String {
        switch self {
        case .working: return "checkmark.circle.fill"
        case .live: return "waveform.circle.fill"
        case .demo: return "play.circle.fill"
        case .savedOnly: return "tray.and.arrow.down.fill"
        case .simulated: return "sparkles"
        case .requiresBackend: return "exclamationmark.triangle.fill"
        case .unsupported: return "nosign"
        case .deviceMissing: return "questionmark.circle.fill"
        }
    }

    var foreground: Color {
        switch self {
        case .working: return .green
        case .live: return .mint
        case .demo: return .cyan
        case .savedOnly: return .yellow
        case .simulated: return .cyan
        case .requiresBackend: return .orange
        case .unsupported, .deviceMissing: return .red
        }
    }

    var background: Color {
        foreground.opacity(0.12)
    }
}
