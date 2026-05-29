import SwiftUI

struct MiniMixerView: View {
    @ObservedObject var store: AudioRouterStore
    var maxRows = 4

    private var visibleSources: [AudioSource] {
        Array(store.audioSources.prefix(maxRows))
    }

    var body: some View {
        DockCard {
            SectionHeader(title: "Mini Mixer", systemImage: "slider.horizontal.3", trailing: store.currentOutput?.name)

            if let output = store.currentOutput {
                MiniSystemRow(output: output, store: store)
            }

            if visibleSources.isEmpty {
                Text("Open a route app or add one from the dashboard.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                VStack(spacing: 9) {
                    ForEach(visibleSources) { source in
                        MiniSourceRow(source: source, store: store)
                    }
                }
            }
        }
    }
}

private struct MiniSystemRow: View {
    let output: AudioDevice
    @ObservedObject var store: AudioRouterStore

    var body: some View {
        VStack(spacing: 7) {
            HStack(spacing: 8) {
                Image(systemName: "speaker.wave.2.fill")
                    .foregroundStyle(.teal)
                    .frame(width: 20)
                Text("System")
                    .font(.caption.weight(.semibold))
                MeterView(level: store.systemOutputMeter, barCount: 10, height: 12, color: .teal)
                    .frame(maxWidth: 90)
                Spacer()
                Button {
                    store.setDeviceMuted(output, isMuted: !(output.isMuted ?? false))
                } label: {
                    Image(systemName: (output.isMuted ?? false) ? "speaker.slash.fill" : "speaker.wave.1.fill")
                }
                .buttonStyle(.borderless)
                .disabled(!output.canSetMute)
                .accessibilityLabel((output.isMuted ?? false) ? "Unmute system output" : "Mute system output")
                .accessibilityHint(output.canSetMute ? "Toggles mute for \(output.name)" : "Mute is not supported by this output")
            }

            HStack(spacing: 8) {
                InlineVolumeSlider(
                    value: output.volume,
                    isEnabled: output.canSetVolume,
                    systemImage: "speaker.wave.2.fill",
                    accent: .teal,
                    accessibilityLabel: "System output volume",
                    accessibilityHint: output.canSetVolume ? "Adjusts \(output.name)" : "Volume is not supported by this output",
                    onChange: store.setSystemOutputVolume
                )
            }
        }
        .padding(9)
        .background(.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
    }
}

private struct MiniSourceRow: View {
    let source: AudioSource
    @ObservedObject var store: AudioRouterStore

    var body: some View {
        VStack(spacing: 7) {
            HStack(spacing: 8) {
                AppSourceIcon(source: source)
                    .frame(width: 24, height: 24)

                VStack(alignment: .leading, spacing: 1) {
                    Text(source.appName)
                        .font(.caption.weight(.semibold))
                        .lineLimit(1)
                    Text(store.routeOutputName(for: source))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                StatusLabel(text: store.routeStatus(for: source), status: store.statusStyle(for: source))

                Button {
                    store.setSourceMuted(source: source, isMuted: !source.isMuted)
                } label: {
                    Image(systemName: source.isMuted ? "speaker.slash.fill" : "speaker.wave.1.fill")
                }
                .buttonStyle(.borderless)
                .disabled(!store.supportsPerAppMute)
                .accessibilityLabel(source.isMuted ? "Unmute \(source.appName)" : "Mute \(source.appName)")
                .accessibilityHint(store.supportsPerAppMute ? "Toggles mute for this app route" : "Per-app mute requires an audio backend")
            }

            HStack(spacing: 8) {
                MeterView(level: store.sourceMeters[source.id] ?? 0, barCount: 8, height: 12, color: source.isProducingAudio ? .green : .cyan)
                    .frame(width: 78)
                InlineVolumeSlider(
                    value: source.volume,
                    isEnabled: store.supportsPerAppVolume,
                    systemImage: "speaker.wave.2.fill",
                    range: 0...1.5,
                    accent: .green,
                    accessibilityLabel: "\(source.appName) volume",
                    accessibilityHint: store.supportsPerAppVolume ? "Adjusts this app route volume" : "Per-app volume requires an audio backend",
                    onChange: { store.setSourceVolume(source: source, volume: $0) }
                )
            }
        }
        .padding(9)
        .background(.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
        .help(store.routeDiagnostic(for: source) ?? "Route is ready.")
        .accessibilityElement(children: .contain)
        .accessibilityLabel("\(source.appName), output \(store.routeOutputName(for: source)), \(store.routeStatus(for: source))")
    }
}
