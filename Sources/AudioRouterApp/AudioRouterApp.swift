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
                .frame(width: 430, height: 620)
                .onAppear {
                    store.start()
                }
        } label: {
            Image(systemName: "point.3.connected.trianglepath.dotted")
                .symbolRenderingMode(.hierarchical)
                .accessibilityLabel("AudioRouter")
                .accessibilityHint("Opens AudioRouter routing controls")
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
    private var confirmedQuit = false

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

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        guard !confirmedQuit else { return .terminateNow }

        let alert = NSAlert()
        alert.messageText = "Quit AudioRouter?"
        alert.informativeText = "Quitting will stop AudioRouter's routing controls, active meters, and update checks until you open the app again."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Quit AudioRouter")
        alert.addButton(withTitle: "Cancel")

        NSApp.activate(ignoringOtherApps: true)
        if alert.runModal() == .alertFirstButtonReturn {
            confirmedQuit = true
            return .terminateNow
        }

        return .terminateCancel
    }

    func applicationWillTerminate(_ notification: Notification) {
        Self.store?.stop()
    }
}

struct AudioRouterCommands: Commands {
    @ObservedObject var store: AudioRouterStore

    var body: some Commands {
        CommandGroup(replacing: .newItem) {}
        CommandGroup(replacing: .saveItem) {}
        CommandGroup(replacing: .printItem) {}

        CommandGroup(after: .appInfo) {
            Button("Check for Updates...") {
                store.checkForUpdates()
            }
            .keyboardShortcut("u", modifiers: [.command, .shift])
        }

        CommandMenu("Routing") {
            Button("Refresh Devices") {
                store.refresh()
            }
            .keyboardShortcut("r", modifiers: [.command])

            Divider()

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
        }

        CommandMenu("Volume") {
            Button("Mute System Output") {
                store.toggleSystemMute()
            }
            .keyboardShortcut(store.shortcutManager.shortcut(for: .muteSystem).keyEquivalent,
                              modifiers: store.shortcutManager.shortcut(for: .muteSystem).modifiers)

            Button("Mute Selected App") {
                store.toggleSelectedSourceMute()
            }
            .keyboardShortcut(store.shortcutManager.shortcut(for: .muteSelectedApp).keyEquivalent,
                              modifiers: store.shortcutManager.shortcut(for: .muteSelectedApp).modifiers)

            Divider()

            Button("Increase \(store.selectedVolumeCommandTitle) Volume") {
                store.changeSelectedVolume(by: 0.01)
            }
            .keyboardShortcut(store.shortcutManager.shortcut(for: .increaseVolume).keyEquivalent,
                              modifiers: store.shortcutManager.shortcut(for: .increaseVolume).modifiers)

            Button("Decrease \(store.selectedVolumeCommandTitle) Volume") {
                store.changeSelectedVolume(by: -0.01)
            }
            .keyboardShortcut(store.shortcutManager.shortcut(for: .decreaseVolume).keyEquivalent,
                              modifiers: store.shortcutManager.shortcut(for: .decreaseVolume).modifiers)
        }

        CommandMenu("Setups") {
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
        }
    }
}
