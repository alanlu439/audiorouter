import SwiftUI

public struct MenuBarPopoverView: View {
    @ObservedObject private var store: AudioRouterStore
    @Environment(\.openWindow) private var openWindow

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
                    if !store.settings.hasCompletedOnboarding {
                        compactOnboardingPrompt
                    }
                    BackendStatusPanel(store: store, compact: true, showActions: false)

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
                    MiniMixerView(store: store, maxRows: 3)
                    AppAudioListView(store: store, maxRows: 4)
                    UpdateStatusView(store: store, compact: true)
                    EQView(eqManager: store.eqManager, compact: true)
                    PresetsView(store: store, compact: true)
                }
                .padding(16)
            }
        }
        .preferredColorScheme(store.settings.effectiveColorScheme)
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
            StatusLabel(text: store.backendReadinessTitle, status: store.backendReadinessState.visualStatus)
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

    private var compactOnboardingPrompt: some View {
        DockCard {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "sparkles.rectangle.stack.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.teal)
                    .frame(width: 28, height: 28)
                    .background(.teal.opacity(0.14), in: RoundedRectangle(cornerRadius: 8, style: .continuous))

                VStack(alignment: .leading, spacing: 4) {
                    Text("Finish Guided Setup")
                        .font(.subheadline.weight(.semibold))
                    Text("Walk through devices, apps, permission, and your first route.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 8)

                Button {
                    openWindow(id: "main")
                    store.showOnboarding()
                } label: {
                    Label("Open", systemImage: "arrow.up.right.square")
                }
                .controlSize(.small)
            }
        }
    }
}
