import SwiftUI

struct UpdateStatusView: View {
    @ObservedObject var store: AudioRouterStore
    var compact = false

    var body: some View {
        DockCard {
            HStack(spacing: 10) {
                Label("Updates", systemImage: store.updateManager.hasUpdate ? "arrow.down.circle.fill" : "checkmark.seal.fill")
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

            HStack(spacing: 8) {
                Button {
                    store.checkForUpdates()
                } label: {
                    Label(store.updateManager.isChecking ? "Checking" : "Check", systemImage: "arrow.clockwise")
                }
                .disabled(store.updateManager.isChecking)
                .accessibilityLabel(store.updateManager.isChecking ? "Checking for updates" : "Check for updates")
                .accessibilityHint("Checks the latest AudioRouter release on GitHub")

                if store.updateManager.hasUpdate {
                    Button {
                        store.openUpdateDownload()
                    } label: {
                        Label("Download", systemImage: "square.and.arrow.down")
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.teal)
                    .accessibilityHint("Opens the newest AudioRouter download in your browser")
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
}
