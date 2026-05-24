import SwiftUI

public struct MenuBarPopoverView: View {
    @ObservedObject private var store: AudioRouterStore

    public init(store: AudioRouterStore) {
        self.store = store
    }

    public var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color.black.opacity(0.30), Color.teal.opacity(0.08), Color.clear],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    header

                    if let note = store.unsupportedNote {
                        SupportNote(note: note) {
                            store.dismissUnsupportedNote()
                        }
                    }

                    if let error = store.lastError {
                        SupportNote(note: error) {
                            store.dismissUnsupportedNote()
                        }
                    }

                    SystemAudioCard(store: store)
                    AppAudioListView(store: store, maxRows: 4)
                    EQView(eqManager: store.eqManager, compact: true)
                    PresetsView(store: store, compact: true)
                }
                .padding(16)
            }
        }
        .preferredColorScheme(store.settings.theme.colorScheme)
    }

    private var header: some View {
        HStack(spacing: 12) {
            AudioRouterLogo(size: 42)
            VStack(alignment: .leading, spacing: 3) {
                Text("AudioRouter")
                    .font(.title3.weight(.bold))
                Text(store.currentOutput?.name ?? "No output selected")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer()
            StatusLabel(text: store.settings.demoMode ? "Demo" : "Live", status: store.settings.demoMode ? .demo : .live)
            Button {
                store.refresh()
            } label: {
                Image(systemName: "arrow.clockwise")
            }
            .help("Refresh devices and app sessions")
            SettingsLink {
                Image(systemName: "gearshape")
            }
            .help("Open Settings")
        }
    }
}
