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

                readinessList(showDetails: !compact)

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

    private func readinessList(showDetails: Bool) -> some View {
        VStack(spacing: 0) {
            ForEach(store.backendReadinessItems) { item in
                BackendReadinessLine(item: item, showDetail: showDetails)
            }
        }
        .background(ConsolePalette.inset.opacity(0.62), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(ConsolePalette.stroke, lineWidth: 1)
        }
    }

}

private struct BackendReadinessLine: View {
    let item: BackendReadinessItem
    var showDetail: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: showDetail ? 4 : 0) {
            HStack(spacing: 10) {
                Image(systemName: item.state.visualStatus.systemImage)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(item.state.visualStatus.foreground)
                    .frame(width: 18, height: 18)
                    .accessibilityHidden(true)

                Text(item.title)
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
                    .allowsTightening(true)
                    .layoutPriority(1)

                Spacer(minLength: 12)

                Text(item.state.badgeTitle)
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(item.state.visualStatus.foreground)
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
            }

            if showDetail {
                Text(item.detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.leading, 28)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, showDetail ? 10 : 8)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(ConsolePalette.stroke)
                .frame(height: 1)
                .padding(.leading, 30)
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
