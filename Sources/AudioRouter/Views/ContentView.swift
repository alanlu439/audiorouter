import SwiftUI

public struct ContentView: View {
    @ObservedObject var store: AudioRouterStore

    public init(store: AudioRouterStore) {
        self.store = store
    }

    public var body: some View {
        NavigationSplitView {
            SidebarView(store: store)
        } detail: {
            DetailRouterView(store: store)
        }
        .toolbar {
            ToolbarItemGroup {
                Button {
                    store.refresh()
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }

                Button(role: .destructive) {
                    store.stopAllRoutes()
                } label: {
                    Label("Stop All", systemImage: "stop.circle")
                }
            }
        }
    }
}

private struct DetailRouterView: View {
    @ObservedObject var store: AudioRouterStore

    var body: some View {
        switch store.selectedSection ?? .routes {
        case .devices:
            DevicesView(store: store)
        case .processes:
            ProcessesView(store: store)
        case .routes:
            RoutesView(store: store)
        case .permissions:
            PermissionView()
        case .diagnostics:
            DiagnosticsView(store: store)
        }
    }
}
