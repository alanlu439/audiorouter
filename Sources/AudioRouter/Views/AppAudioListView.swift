import SwiftUI

struct AppAudioListView: View {
    @ObservedObject var store: AudioRouterStore
    var maxRows: Int?

    var body: some View {
        DockCard {
            SectionHeader(
                title: "App Routing",
                systemImage: "point.3.connected.trianglepath.dotted",
                trailing: "\(store.audioSources.count)"
            )

            Text("Source App -> Output Device")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            HStack(spacing: 8) {
                StatusLabel(text: store.backendReadinessTitle, status: store.backendReadinessState.visualStatus)
                Text(store.backendReadinessDetail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            if store.audioSources.isEmpty {
                Text("No active audio apps detected yet.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                VStack(spacing: 10) {
                    ForEach(Array(rows)) { source in
                        AppAudioRowView(source: source, store: store)
                        if source.id != rows.last?.id {
                            Divider()
                        }
                    }
                }
            }
        }
    }

    private var rows: ArraySlice<AudioSource> {
        store.audioSources.prefix(maxRows ?? store.audioSources.count)
    }
}

struct AppAudioRowView: View {
    let source: AudioSource
    @ObservedObject var store: AudioRouterStore

    var body: some View {
        let route = store.route(for: source)
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                AppSourceIcon(source: source)
                VStack(alignment: .leading, spacing: 2) {
                    Text(source.appName)
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)
                    HStack(spacing: 6) {
                        StatusBadge(text: source.activityLabel, isActive: source.isProducingAudio)
                        StatusLabel(text: store.routeStatus(for: source), status: store.statusStyle(for: source))
                        Text(source.lastActiveTime.shortRelativeDescription)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                Image(systemName: "arrow.right")
                    .foregroundStyle(.secondary)
                Text(store.routeOutputName(for: source))
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)
                    .frame(maxWidth: 140, alignment: .trailing)
                Button {
                    store.setSourceMuted(source: source, isMuted: !source.isMuted)
                } label: {
                    Image(systemName: source.isMuted ? "speaker.slash.fill" : "speaker.wave.1.fill")
                }
                .buttonStyle(.borderless)
                .disabled(!store.supportsPerAppMute)
                .help(store.supportsPerAppMute ? "Mute this audio source" : "Per-app mute requires an audio backend.")
            }

            HStack(spacing: 10) {
                Image(systemName: "slider.horizontal.3")
                    .foregroundStyle(.secondary)
                    .frame(width: 18)
                Slider(
                    value: Binding(
                        get: { source.volume },
                        set: { store.setSourceVolume(source: source, volume: $0) }
                    ),
                    in: 0...1.5
                )
                .disabled(!store.supportsPerAppVolume)
                .help(store.supportsPerAppVolume ? "Set source volume" : "Per-app gain requires an audio backend.")
                Text("\((source.volume * 100).rounded().formatted(.number.precision(.fractionLength(0))))%")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .frame(width: 46, alignment: .trailing)
            }

            HStack(spacing: 10) {
                Text("Output")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(width: 52, alignment: .leading)
                Picker("Output", selection: outputSelection) {
                    Text("Follow System Output").tag("")
                    ForEach(store.outputDevices) { device in
                        Text(device.name).tag(device.uid)
                    }
                    if !store.outputGroups.isEmpty {
                        Divider()
                        ForEach(store.outputGroups) { group in
                            Text("\(group.name) (Group)").tag(group.routeTargetID)
                        }
                    }
                }
                .pickerStyle(.menu)
                Spacer()
                let status = store.routeStatus(for: source)
                if route.routeMode == .customOutput && status != "Live" {
                    Text(status)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(store.routeStatusIsWarning(for: source) ? .orange : .secondary)
                }
            }
            if let diagnostic = store.routeDiagnostic(for: source) {
                Text(diagnostic)
                    .font(.caption2)
                    .foregroundStyle(store.routeStatusIsWarning(for: source) ? .orange : .secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var outputSelection: Binding<String> {
        Binding(
            get: { source.followsSystemOutput ? "" : (source.assignedOutputDeviceID ?? "") },
            set: { value in
                store.assignSourceOutput(source: source, uid: value.isEmpty ? nil : value)
            }
        )
    }
}
