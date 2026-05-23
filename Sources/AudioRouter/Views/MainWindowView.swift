import SwiftUI

public struct MainWindowView: View {
    @ObservedObject private var store: AudioRouterStore

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
                .padding(20)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .preferredColorScheme(store.settings.theme.colorScheme)
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
