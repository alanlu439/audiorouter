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
        AppDelegate.configure(with: store)
    }

    var body: some Scene {
        MenuBarExtra("AudioRouter", systemImage: "speaker.wave.2.circle.fill") {
            MenuBarPopoverView(store: store)
                .frame(width: 430, height: 680)
                .onAppear {
                    store.start()
                }
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView(store: store)
                .frame(width: 720, height: 560)
        }

        Window("AudioRouter", id: "main") {
            MainWindowView(store: store)
                .frame(minWidth: 760, idealWidth: 980, minHeight: 560, idealHeight: 700)
                .onAppear {
                    store.start()
                }
        }
        .commands {
            AudioRouterCommands(store: store)
        }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private static weak var store: AudioRouterStore?

    static func configure(with store: AudioRouterStore) {
        Self.store = store
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        Self.store?.applyActivationPolicy()
        Self.store?.start()
    }

    func applicationWillTerminate(_ notification: Notification) {
        Self.store?.stop()
    }
}

struct AudioRouterCommands: Commands {
    @ObservedObject var store: AudioRouterStore

    var body: some Commands {
        CommandGroup(after: .appInfo) {
            Button("Refresh Audio Devices") {
                store.refresh()
            }
            .keyboardShortcut("r", modifiers: [.command])
        }

        CommandMenu("AudioRouter") {
            Button("Mute or Unmute") {
                store.toggleSystemMute()
            }
            .keyboardShortcut(store.shortcutManager.shortcut(for: .muteSystem).keyEquivalent,
                              modifiers: store.shortcutManager.shortcut(for: .muteSystem).modifiers)

            Button("Increase Volume") {
                store.changeSystemVolume(by: 0.05)
            }
            .keyboardShortcut(store.shortcutManager.shortcut(for: .increaseVolume).keyEquivalent,
                              modifiers: store.shortcutManager.shortcut(for: .increaseVolume).modifiers)

            Button("Decrease Volume") {
                store.changeSystemVolume(by: -0.05)
            }
            .keyboardShortcut(store.shortcutManager.shortcut(for: .decreaseVolume).keyEquivalent,
                              modifiers: store.shortcutManager.shortcut(for: .decreaseVolume).modifiers)

            Button("Next Output Device") {
                store.switchToNextOutputDevice()
            }
            .keyboardShortcut(store.shortcutManager.shortcut(for: .nextOutputDevice).keyEquivalent,
                              modifiers: store.shortcutManager.shortcut(for: .nextOutputDevice).modifiers)

            Button("Open Popover Shortcut Note") {
                store.showUnsupportedNote("SwiftUI MenuBarExtra does not expose a public API to open its popover from a global shortcut. A future AppKit status-item bridge can provide that behavior.")
            }
            .keyboardShortcut(store.shortcutManager.shortcut(for: .openPopover).keyEquivalent,
                              modifiers: store.shortcutManager.shortcut(for: .openPopover).modifiers)
        }
    }
}
