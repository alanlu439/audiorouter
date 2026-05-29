import SwiftUI

struct MixerView: View {
    @ObservedObject var store: AudioRouterStore

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Mixer")
                    .font(.largeTitle.weight(.bold))
                Spacer()
                StatusLabel(text: store.settings.demoMode ? "Demo Mode" : "Live Mode", status: store.settings.demoMode ? .simulated : .working)
            }

            DockCard {
                SectionHeader(title: "System Output", systemImage: "speaker.wave.2.fill")
                MeterView(level: store.systemOutputMeter, barCount: 18, height: 24, color: .green)
                if !store.settings.demoMode && !store.liveMeteringAvailable {
                    Text(store.meteringNote)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                if let output = store.currentOutput {
                    VolumeSlider(
                        title: "Output",
                        value: output.volume,
                        isEnabled: output.canSetVolume,
                        systemImage: "speaker.wave.2.fill",
                        accent: .teal,
                        showsStepButtons: true,
                        onChange: store.setSystemOutputVolume
                    )
                    Button {
                        store.setDeviceMuted(output, isMuted: !(output.isMuted ?? false))
                    } label: {
                        Label((output.isMuted ?? false) ? "Unmute System" : "Mute System", systemImage: (output.isMuted ?? false) ? "speaker.wave.2.fill" : "speaker.slash.fill")
                    }
                    .buttonStyle(.bordered)
                }
            }

            DockCard {
                SectionHeader(title: "Input Microphone", systemImage: "mic.fill")
                MeterView(level: store.inputMeter, barCount: 18, height: 24, color: .cyan)
                if let input = store.currentInput {
                    VolumeSlider(
                        title: "Input",
                        value: input.volume,
                        isEnabled: input.canSetVolume,
                        systemImage: "mic.fill",
                        accent: .cyan,
                        showsStepButtons: true,
                        onChange: store.setInputVolume
                    )
                }
            }

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 280), spacing: 14)], spacing: 14) {
                ForEach(store.audioSources) { source in
                    MixerSourceCard(source: source, store: store)
                }
            }
        }
    }
}

private struct MixerSourceCard: View {
    let source: AudioSource
    @ObservedObject var store: AudioRouterStore

    var body: some View {
        DockCard {
            HStack {
                AppSourceIcon(source: source)
                VStack(alignment: .leading, spacing: 2) {
                    Text(source.appName)
                        .font(.headline)
                    Text(store.routeOutputName(for: source))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                StatusLabel(text: store.routeStatus(for: source), status: store.statusStyle(for: source))
            }
            MeterView(level: store.sourceMeters[source.id] ?? 0, color: source.isProducingAudio ? .green : .cyan)
            if !store.settings.demoMode && !store.liveMeteringAvailable {
                Text("Meter unavailable")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
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
            HStack {
                Button {
                    store.setSourceMuted(source: source, isMuted: !source.isMuted)
                } label: {
                    Label(source.isMuted ? "Muted" : "Mute", systemImage: source.isMuted ? "speaker.slash.fill" : "speaker.wave.1.fill")
                }
                Button {
                    store.toggleSolo(source: source)
                } label: {
                    Label(store.soloSourceID == source.id ? "Solo On" : "Solo", systemImage: "person.wave.2.fill")
                }
            }
            .buttonStyle(.bordered)
            .disabled(!store.supportsPerAppMute)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(store.selectedSourceID == source.id ? Color.teal.opacity(0.85) : Color.clear, lineWidth: 2)
        }
        .onTapGesture {
            store.selectedSourceID = source.id
        }
    }
}
