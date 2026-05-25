import SwiftUI

struct BackendStatusPanel: View {
    @ObservedObject var store: AudioRouterStore
    var compact = false
    var showActions = true

    var body: some View {
        DockCard {
            HStack(alignment: .center, spacing: 12) {
                Label("Backend", systemImage: "cpu")
                    .font(.headline)
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
                HStack(spacing: 10) {
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
                    Spacer()
                    Text(store.routingBackendName)
                        .font(.caption2.monospaced())
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }
            }

            if let message = store.processTapProbeMessage, !compact {
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var compactRows: some View {
        HStack(spacing: 8) {
            ForEach(store.backendReadinessItems) { item in
                StatusLabel(text: item.title, status: item.state.visualStatus)
                    .help(item.detail)
            }
            Spacer(minLength: 0)
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
