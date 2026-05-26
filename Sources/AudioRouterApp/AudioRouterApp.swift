import AppKit
import AudioRouterCore
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
        WindowGroup("AudioRouter", id: "main") {
            MainWindowView(store: store)
                .frame(minWidth: 760, idealWidth: 980, minHeight: 560, idealHeight: 700)
                .onAppear {
                    store.start()
                }
        }
        .commands {
            AudioRouterCommands(store: store)
        }

        MenuBarExtra {
            MenuBarPopoverView(store: store)
                .frame(width: 450, height: 760)
                .onAppear {
                    store.start()
                }
        } label: {
            Image(systemName: "speaker.wave.2.circle.fill")
                .symbolRenderingMode(.hierarchical)
                .accessibilityLabel("AudioRouter")
                .accessibilityHint("Opens the AudioRouter menu bar controls")
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView(store: store)
                .frame(width: 720, height: 560)
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
        DispatchQueue.main.async {
            NSApp.activate(ignoringOtherApps: true)
        }
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

            Button("Check for Updates") {
                store.checkForUpdates()
            }
            .keyboardShortcut("u", modifiers: [.command, .shift])
            Button("Download Latest Release") {
                store.openUpdateDownload()
            }
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

            Button("Previous Output Device") {
                store.switchToPreviousOutputDevice()
            }
            .keyboardShortcut(store.shortcutManager.shortcut(for: .previousOutputDevice).keyEquivalent,
                              modifiers: store.shortcutManager.shortcut(for: .previousOutputDevice).modifiers)

            Button("Mute Selected App") {
                store.toggleSelectedSourceMute()
            }
            .keyboardShortcut(store.shortcutManager.shortcut(for: .muteSelectedApp).keyEquivalent,
                              modifiers: store.shortcutManager.shortcut(for: .muteSelectedApp).modifiers)

            Button("Apply Setup 1") {
                store.applyPreset(at: 0)
            }
            .keyboardShortcut(store.shortcutManager.shortcut(for: .applyPreset1).keyEquivalent,
                              modifiers: store.shortcutManager.shortcut(for: .applyPreset1).modifiers)

            Button("Apply Setup 2") {
                store.applyPreset(at: 1)
            }
            .keyboardShortcut(store.shortcutManager.shortcut(for: .applyPreset2).keyEquivalent,
                              modifiers: store.shortcutManager.shortcut(for: .applyPreset2).modifiers)

            Button("Apply Setup 3") {
                store.applyPreset(at: 2)
            }
            .keyboardShortcut(store.shortcutManager.shortcut(for: .applyPreset3).keyEquivalent,
                              modifiers: store.shortcutManager.shortcut(for: .applyPreset3).modifiers)

            Button("Open Popover Shortcut Note") {
                store.showUnsupportedNote("SwiftUI MenuBarExtra does not expose a public API to open its popover from a global shortcut. A future AppKit status-item bridge can provide that behavior.")
            }
            .keyboardShortcut(store.shortcutManager.shortcut(for: .openPopover).keyEquivalent,
                              modifiers: store.shortcutManager.shortcut(for: .openPopover).modifiers)
        }
    }
}
