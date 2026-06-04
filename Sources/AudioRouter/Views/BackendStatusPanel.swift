import SwiftUI

struct BackendStatusPanel: View {
    @ObservedObject var store: AudioRouterStore
    var compact = false
    var showActions = true

    var body: some View {
        ConsolePanel(
            title: "Backend",
            systemImage: "cpu",
            trailing: store.routingBackendName,
            tint: ConsolePalette.teal
        ) {
            VStack(alignment: .leading, spacing: compact ? 10 : 12) {
                HStack(alignment: .center, spacing: 12) {
                    Text("Routing Engine")
                        .font(compact ? .subheadline.weight(.semibold) : .headline.weight(.semibold))
                    Spacer()
                    StatusLabel(
                        text: store.backendReadinessTitle,
                        status: store.backendReadinessState.visualStatus
                    )
                }

                Text(store.backendReadinessDetail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                if compact {
                    compactRows
                } else {
                    fullRows
                }

                if showActions {
                    HStack(spacing: 8) {
                        Button {
                            store.refresh()
                        } label: {
                            Label("Refresh", systemImage: "arrow.clockwise")
                        }
                        Button {
                            store.probeProcessTapPermission()
                        } label: {
                            Label("Probe Tap", systemImage: "waveform.badge.magnifyingglass")
                        }
                        .disabled(store.settings.demoMode)
                        Spacer(minLength: 0)
                    }
                    .controlSize(.small)
                }

                if let message = store.processTapProbeMessage, !compact {
                    Text(message)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private var compactRows: some View {
        VStack(spacing: 0) {
            ForEach(store.backendReadinessItems) { item in
                BackendReadinessLine(item: item)
            }
        }
        .background(ConsolePalette.inset.opacity(0.62), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(ConsolePalette.stroke, lineWidth: 1)
        }
    }

    private var fullRows: some View {
        VStack(spacing: 8) {
            ForEach(store.backendReadinessItems) { item in
                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    StatusLabel(text: item.state.badgeTitle, status: item.state.visualStatus)
                        .frame(width: 118, alignment: .leading)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.title)
                            .font(.subheadline.weight(.semibold))
                        Text(item.detail)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 0)
                }
            }
        }
    }
}

private struct BackendReadinessLine: View {
    let item: BackendReadinessItem

    var body: some View {
        HStack(spacing: 9) {
            ConsoleLED(color: item.state.visualStatus.foreground)
            Text(item.title)
                .font(.caption.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.85)
            Spacer(minLength: 10)
            Text(item.state.badgeTitle)
                .font(.caption2.weight(.bold))
                .foregroundStyle(item.state.visualStatus.foreground)
                .lineLimit(1)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(ConsolePalette.stroke)
                .frame(height: 1)
                .padding(.leading, 26)
        }
        .help(item.detail)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(item.title), \(item.state.badgeTitle)")
        .accessibilityHint(item.detail)
    }
}

extension BackendReadinessState {
    var visualStatus: RouteVisualStatus {
        switch self {
        case .working, .ready:
            return .working
        case .live:
            return .live
        case .demo:
            return .demo
        case .savedOnly:
            return .savedOnly
        case .requiresBackend:
            return .requiresBackend
        case .unsupported:
            return .unsupported
        case .deviceMissing:
            return .deviceMissing
        }
    }
}
