import SwiftUI

public struct MainWindowView: View {
    @ObservedObject private var store: AudioRouterStore
    @State private var offeredInitialOnboarding = false

    public init(store: AudioRouterStore) {
        self.store = store
    }

    public var body: some View {
        NavigationSplitView {
            List(selection: $store.selectedSettingsSection) {
                ForEach(SettingsSection.allCases) { section in
                    Label(section.rawValue, systemImage: section.systemImage)
                        .tag(section)
                }
            }
            .listStyle(.sidebar)
            .navigationTitle("AudioRouter")
        } detail: {
            SettingsDetailView(section: store.selectedSettingsSection, store: store)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .preferredColorScheme(store.settings.effectiveColorScheme)
        .sheet(isPresented: $store.isOnboardingPresented) {
            GuidedOnboardingSheet(store: store)
                .frame(minWidth: 760, idealWidth: 860, minHeight: 540, idealHeight: 620)
                .preferredColorScheme(store.settings.effectiveColorScheme)
        }
        .onAppear {
            presentInitialOnboardingIfNeeded()
        }
        .alert("AudioRouter Update Available", isPresented: updatePromptBinding) {
            if store.updateManager.availableUpdate?.isDownloadable == true {
                Button("Install ZIP") {
                    store.installDownloadedUpdate()
                }
            } else {
                Button("View Commit") {
                    store.openLatestRelease()
                    store.dismissUpdatePrompt()
                }
            }
            Button("Later", role: .cancel) {
                store.dismissUpdatePrompt()
            }
        } message: {
            Text(updatePromptMessage)
        }
    }

    private func presentInitialOnboardingIfNeeded() {
        guard !offeredInitialOnboarding, !store.settings.hasCompletedOnboarding else { return }
        offeredInitialOnboarding = true
        store.showOnboarding()
    }

    private var updatePromptBinding: Binding<Bool> {
        Binding(
            get: { store.updateManager.shouldPromptToInstall },
            set: { isPresented in
                if !isPresented {
                    store.dismissUpdatePrompt()
                }
            }
        )
    }

    private var updatePromptMessage: String {
        if let update = store.updateManager.availableUpdate {
            if update.isDownloadable {
                return "AudioRouter \(update.version) has been downloaded. Open the ZIP and move AudioRouter.app to Applications to finish installing."
            }
            let commitLabel = update.commitSHA.map(UpdateManager.shortCommit) ?? update.version
            return "A newer AudioRouter commit \(commitLabel) is available on GitHub. Open the commit to review the update; packaged app ZIPs are still published from GitHub Releases."
        }
        return store.updateManager.message
    }
}

#if DEBUG
struct MainWindowView_Previews: PreviewProvider {
    @MainActor
    static var previews: some View {
        MainWindowView(store: PreviewSupport.demoStore())
            .frame(width: 1100, height: 760)
    }
}
#endif
