import AppKit
import AudioRouterCore
import SwiftUI

@main
struct AudioRouterApplication: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var store: AudioRouterStore
    private let mainWindowCoordinator: MainWindowCoordinator

    init() {
        let store = AudioRouterStore()
        let mainWindowCoordinator = MainWindowCoordinator()
        _store = StateObject(wrappedValue: store)
        self.mainWindowCoordinator = mainWindowCoordinator
        AppDelegate.configure(with: store, mainWindowCoordinator: mainWindowCoordinator)
    }

    var body: some Scene {
        Window("AudioRouter", id: "main") {
            MainWindowSceneContent(store: store, coordinator: mainWindowCoordinator)
                .frame(minWidth: 760, idealWidth: 980, minHeight: 560, idealHeight: 700)
        }
        .windowToolbarStyle(.unifiedCompact(showsTitle: true))
        .commands {
            AudioRouterCommands(store: store, mainWindowCoordinator: mainWindowCoordinator)
        }

        MenuBarExtra {
            MenuBarPopoverView(store: store)
                .frame(width: 420, height: 560)
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
                .frame(minWidth: 680, idealWidth: 760, minHeight: 560, idealHeight: 680)
        }
        .windowToolbarStyle(.unifiedCompact(showsTitle: true))
    }
}

@MainActor
final class MainWindowCoordinator {
    private var mainWindow: NSWindow?

    func register(window: NSWindow) {
        window.isReleasedWhenClosed = false
        mainWindow = window
    }

    @discardableResult
    func showMainWindow() -> Bool {
        guard let mainWindow else { return false }
        NSApp.unhide(nil)
        NSApp.activate(ignoringOtherApps: true)
        if mainWindow.isMiniaturized {
            mainWindow.deminiaturize(nil)
        }
        mainWindow.orderFrontRegardless()
        mainWindow.makeKey()
        return mainWindow.isVisible
    }
}

private struct MainWindowSceneContent: View {
    @ObservedObject var store: AudioRouterStore
    let coordinator: MainWindowCoordinator

    var body: some View {
        MainWindowView(store: store)
            .background(MainWindowRegistrationView(coordinator: coordinator))
            .onAppear {
                store.start()
            }
    }
}

private struct MainWindowRegistrationView: NSViewRepresentable {
    let coordinator: MainWindowCoordinator

    func makeNSView(context: Context) -> MainWindowRegistrationNSView {
        MainWindowRegistrationNSView(coordinator: coordinator)
    }

    func updateNSView(_ nsView: MainWindowRegistrationNSView, context: Context) {
        nsView.registerWindow()
    }
}

private final class MainWindowRegistrationNSView: NSView {
    private let coordinator: MainWindowCoordinator

    init(coordinator: MainWindowCoordinator) {
        self.coordinator = coordinator
        super.init(frame: .zero)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        registerWindow()
    }

    func registerWindow() {
        guard let window else { return }
        coordinator.register(window: window)
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private static weak var store: AudioRouterStore?
    private static weak var mainWindowCoordinator: MainWindowCoordinator?
    private var confirmedQuit = false

    static func configure(with store: AudioRouterStore, mainWindowCoordinator: MainWindowCoordinator) {
        Self.store = store
        Self.mainWindowCoordinator = mainWindowCoordinator
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        Self.store?.applyActivationPolicy()
        Self.store?.start()
        installReopenEventHandler()
        DispatchQueue.main.async {
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    func applicationShouldHandleReopen(
        _ sender: NSApplication,
        hasVisibleWindows flag: Bool
    ) -> Bool {
        guard let mainWindowCoordinator = Self.mainWindowCoordinator else {
            return true
        }
        return !mainWindowCoordinator.showMainWindow()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    @objc private func handleReopenApplicationEvent(
        _ event: NSAppleEventDescriptor,
        withReplyEvent replyEvent: NSAppleEventDescriptor
    ) {
        _ = Self.mainWindowCoordinator?.showMainWindow()
    }

    private func installReopenEventHandler() {
        NSAppleEventManager.shared().setEventHandler(
            self,
            andSelector: #selector(handleReopenApplicationEvent(_:withReplyEvent:)),
            forEventClass: AEEventClass(kCoreEventClass),
            andEventID: AEEventID(kAEReopenApplication)
        )
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
        NSAppleEventManager.shared().removeEventHandler(
            forEventClass: AEEventClass(kCoreEventClass),
            andEventID: AEEventID(kAEReopenApplication)
        )
        Self.store?.stop()
    }
}

struct AudioRouterCommands: Commands {
    @ObservedObject var store: AudioRouterStore
    let mainWindowCoordinator: MainWindowCoordinator

    var body: some Commands {
        CommandGroup(replacing: .newItem) {}
        CommandGroup(replacing: .saveItem) {}
        CommandGroup(replacing: .printItem) {}

        CommandGroup(before: .windowArrangement) {
            Button("Show AudioRouter") {
                mainWindowCoordinator.showMainWindow()
            }
            .keyboardShortcut("0", modifiers: [.command])

            Divider()
        }

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
