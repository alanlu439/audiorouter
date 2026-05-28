import SwiftUI

struct UpdateStatusView: View {
    @ObservedObject var store: AudioRouterStore
    var compact = false

    var body: some View {
        DockCard {
            HStack(spacing: 10) {
                Label("Updates", systemImage: updateIcon)
                    .font(compact ? .subheadline.weight(.semibold) : .headline)
                    .foregroundStyle(store.updateManager.hasUpdate ? .teal : .secondary)
                Spacer()
                Text("v\(store.updateManager.currentVersion)")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }

            Text(store.updateManager.message)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Toggle("Automatically check and fetch updates", isOn: automaticUpdatesBinding)
                .font(.caption.weight(.semibold))
                .toggleStyle(.switch)
                .accessibilityHint("Checks GitHub Releases at launch and fetches the newest AudioRouter ZIP when available")

            if let lastCheckedAt = store.updateManager.lastCheckedAt {
                Text("Last checked \(lastCheckedAt.formatted(date: .abbreviated, time: .shortened))")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 8) {
                Button {
                    store.checkForUpdates()
                } label: {
                    Label(store.updateManager.isChecking ? "Checking" : "Check", systemImage: "arrow.clockwise")
                }
                .disabled(store.updateManager.isChecking || store.updateManager.isDownloading)
                .accessibilityLabel(store.updateManager.isChecking ? "Checking for updates" : "Check for updates")
                .accessibilityHint("Checks the latest AudioRouter release on GitHub")

                if store.updateManager.isDownloading {
                    ProgressView()
                        .controlSize(.small)
                        .accessibilityLabel("Downloading update")
                    Text("Fetching ZIP")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                } else if store.updateManager.hasDownloadedUpdate {
                    Button {
                        store.installDownloadedUpdate()
                    } label: {
                        Label("Install", systemImage: "externaldrive.fill")
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.teal)
                    .accessibilityHint("Opens the downloaded AudioRouter ZIP")
                } else if store.updateManager.hasUpdate {
                    Button {
                        store.downloadAvailableUpdate()
                    } label: {
                        Label("Fetch ZIP", systemImage: "square.and.arrow.down")
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.teal)
                    .accessibilityHint("Downloads the newest AudioRouter ZIP")
                } else if !compact {
                    Button {
                        store.openLatestRelease()
                    } label: {
                        Label("Release Page", systemImage: "safari")
                    }
                    .accessibilityHint("Opens the AudioRouter releases page")
                }

                Spacer()
            }
            .controlSize(.small)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Updates. Current version \(store.updateManager.currentVersion). \(store.updateManager.message)")
    }

    private var automaticUpdatesBinding: Binding<Bool> {
        Binding(
            get: { store.settings.automaticallyCheckForUpdates },
            set: { store.setAutomaticallyCheckForUpdates($0) }
        )
    }

    private var updateIcon: String {
        if store.updateManager.hasDownloadedUpdate {
            return "externaldrive.fill"
        }
        if store.updateManager.isDownloading {
            return "arrow.down.circle.fill"
        }
        return store.updateManager.hasUpdate ? "arrow.down.circle.fill" : "checkmark.seal.fill"
    }
}
