#if DEBUG
import SwiftUI

@MainActor
enum PreviewSupport {
    static func demoStore() -> AudioRouterStore {
        let store = AudioRouterStore()
        store.settings.demoMode = true
        store.refresh()
        return store
    }
}
#endif
