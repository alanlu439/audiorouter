import SwiftUI

struct AppAudioListView: View {
    @ObservedObject var store: AudioRouterStore
    var maxRows: Int?

    var body: some View {
        DockCard {
            SectionHeader(
                title: "Apps",
                systemImage: "square.grid.2x2",
                trailing: "\(store.appSessions.count)"
            )

            if store.appSessions.isEmpty {
                Text("No active audio apps detected yet.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                VStack(spacing: 10) {
                    ForEach(Array(rows)) { session in
                        AppAudioRowView(session: session, store: store)
                        if session.id != rows.last?.id {
                            Divider()
                        }
                    }
                }
            }
        }
    }

    private var rows: ArraySlice<AudioAppSession> {
        store.appSessions.prefix(maxRows ?? store.appSessions.count)
    }
}

struct AppAudioRowView: View {
    let session: AudioAppSession
    @ObservedObject var store: AudioRouterStore

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(spacing: 10) {
                AppSessionIcon(session: session)
                VStack(alignment: .leading, spacing: 2) {
                    Text(session.displayName)
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)
                    HStack(spacing: 6) {
                        StatusBadge(text: session.activityLabel, isActive: session.isProducingAudio)
                        Text(session.lastActivity.shortRelativeDescription)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                Button {
                    store.setAppMuted(session: session, isMuted: !session.isMuted)
                } label: {
                    Image(systemName: session.isMuted ? "speaker.slash.fill" : "speaker.wave.1.fill")
                }
                .buttonStyle(.borderless)
                .help("Stored app mute. Driver-backed audio is required for real per-app mute.")
            }

            HStack(spacing: 10) {
                Image(systemName: "slider.horizontal.3")
                    .foregroundStyle(.secondary)
                    .frame(width: 18)
                Slider(
                    value: Binding(
                        get: { session.volume },
                        set: { store.setAppVolume(session: session, volume: $0) }
                    ),
                    in: 0...1.5
                )
                Text("\((session.volume * 100).rounded().formatted(.number.precision(.fractionLength(0))))%")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .frame(width: 46, alignment: .trailing)
            }

            Picker("Output", selection: outputSelection) {
                Text("Follow System").tag("")
                ForEach(store.outputDevices) { device in
                    Text(device.name).tag(device.uid)
                }
            }
            .pickerStyle(.menu)
            .help("Stored output preference. Independent per-app routing requires a virtual driver or audio plug-in.")
        }
    }

    private var outputSelection: Binding<String> {
        Binding(
            get: { session.assignedOutputUID ?? "" },
            set: { value in
                store.assignAppOutput(session: session, uid: value.isEmpty ? nil : value)
            }
        )
    }
}
