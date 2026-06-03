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

    private var isSelected: Bool {
        store.selectedSourceID == source.id
    }

    var body: some View {
        let route = store.route(for: source)
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                AppSourceIcon(source: source)
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(source.appName)
                            .font(.subheadline.weight(.semibold))
                            .lineLimit(1)
                        SourceQualityPill(
                            label: store.sourceAudioQualityLabel(for: source),
                            isLive: store.sourceAudioQualityIsLive(for: source)
                        )
                        .help(store.sourceAudioQualityHelp(for: source))
                    }
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
                .accessibilityLabel(source.isMuted ? "Unmute \(source.appName)" : "Mute \(source.appName)")
                .accessibilityHint(store.supportsPerAppMute ? "Toggles mute for this app route" : "Per-app mute requires an audio backend")
            }

            HStack(spacing: 10) {
                InlineVolumeSlider(
                    value: source.volume,
                    isEnabled: store.supportsPerAppVolume,
                    systemImage: "speaker.wave.2.fill",
                    range: 0...1.5,
                    accent: .green,
                    accessibilityLabel: "\(source.appName) volume",
                    accessibilityHint: store.supportsPerAppVolume ? "Adjusts this app route volume" : "Per-app gain requires an audio backend",
                    onChange: { store.setSourceVolume(source: source, volume: $0) }
                )
                .help(store.supportsPerAppVolume ? "Set source volume" : "Per-app gain requires an audio backend.")
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
                .accessibilityLabel("\(source.appName) output")
                .accessibilityValue(store.routeOutputName(for: source))
                .accessibilityHint("Chooses where this app should play")
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
        .padding(8)
        .background(isSelected ? Color.teal.opacity(0.10) : Color.clear, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(isSelected ? Color.teal.opacity(0.65) : Color.clear, lineWidth: 1.2)
        }
        .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .onTapGesture {
            store.selectedSourceID = source.id
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("\(source.appName), \(source.activityLabel), output \(store.routeOutputName(for: source)), \(store.routeStatus(for: source))")
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
