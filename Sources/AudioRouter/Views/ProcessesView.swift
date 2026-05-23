import SwiftUI

struct ProcessesView: View {
    @ObservedObject var store: AudioRouterStore
    @State private var searchText = ""

    var body: some View {
        List(filteredApplications) { application in
            ProcessRow(application: application)
        }
        .navigationTitle("Applications")
        .searchable(text: $searchText, placement: .toolbar, prompt: "Search applications")
        .safeAreaInset(edge: .top, spacing: 0) {
            DashboardHeader(
                title: "Applications",
                subtitle: "Apple Music, Spotify, and Chrome are available for app-only speaker routing.",
                primaryMetric: "\(store.applications.filter(\.isRunningOutput).count)",
                primaryLabel: "Playing",
                secondaryMetric: "\(store.applications.filter(\.isRunning).count)",
                secondaryLabel: "Running",
                tertiaryMetric: "\(store.applications.count)",
                tertiaryLabel: "Allowed"
            )
            .padding(20)
            .background(.bar)
        }
        .overlay {
            if filteredApplications.isEmpty {
                ContentUnavailableView(
                    store.applications.isEmpty ? "No applications" : "No matches",
                    systemImage: "app.connected.to.app.below.fill",
                    description: Text(store.applications.isEmpty ? "Refresh to scan installed apps." : "Clear the search field.")
                )
            }
        }
    }

    private var filteredApplications: [AppSoundSource] {
        guard !searchText.isEmpty else { return store.applications }
        return store.applications.filter { application in
            application.displayName.localizedCaseInsensitiveContains(searchText)
                || (application.bundleID?.localizedCaseInsensitiveContains(searchText) ?? false)
        }
    }
}

private struct ProcessRow: View {
    let application: AppSoundSource

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: application.isRunningOutput ? "waveform" : "app")
                .font(.title3)
                .foregroundStyle(application.isRunningOutput ? .primary : .secondary)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 4) {
                Text(application.displayName)
                    .font(.headline)
                    .lineLimit(1)

                Text(application.bundleID ?? application.appURL?.path ?? "Application")
                    .foregroundStyle(.secondary)
                    .font(.callout)
                    .lineLimit(1)
            }

            Spacer()

            StatusPill(
                title: application.isRunningOutput ? "Playing" : (application.isRunning ? "Running" : "Available"),
                systemImage: application.isRunningOutput ? "speaker.wave.2.fill" : "app.badge"
            )
        }
        .padding(.vertical, 7)
    }
}
