import AppKit
import AudioRouter
import SwiftUI

@main
struct AudioRouterApplication: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var store: AudioRouterStore

    init() {
        let store = AudioRouterStore()
        _store = StateObject(wrappedValue: store)
        AppDelegate.terminationHandler = {
            store.stopAllRoutes()
        }
    }

    var body: some Scene {
        WindowGroup("AudioRouter", id: "main") {
            ContentView(store: store)
                .frame(minWidth: 680, idealWidth: 1040, minHeight: 520, idealHeight: 720)
                .onAppear {
                    store.refresh()
                }
        }
        .commands {
            CommandGroup(after: .appInfo) {
                Button("Refresh Audio State") {
                    store.refresh()
                }
                .keyboardShortcut("r", modifiers: [.command])

                Button("Stop All Routes") {
                    store.stopAllRoutes()
                }
                .keyboardShortcut(".", modifiers: [.command])
            }
        }

        MenuBarExtra("AudioRouter", systemImage: "speaker.wave.2.fill") {
            MenuBarContentView(store: store)
        }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    static var terminationHandler: (() -> Void)?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        DispatchQueue.main.async {
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        Self.terminationHandler?()
    }
}
