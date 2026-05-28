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
        .alert("AudioRouter Update Ready", isPresented: updatePromptBinding) {
            Button("Install ZIP") {
                store.installDownloadedUpdate()
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
            return "AudioRouter \(update.version) has been downloaded. Open the ZIP and move AudioRouter.app to Applications to finish installing."
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
