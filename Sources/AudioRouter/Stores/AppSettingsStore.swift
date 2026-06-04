import AppKit
import ServiceManagement
import SwiftUI

public enum AudioRouterTheme: String, Codable, CaseIterable, Identifiable {
    case system = "System"
    case light = "Light"
    case dark = "Dark"

    public var id: String { rawValue }

    public var colorScheme: ColorScheme? {
        .dark
    }
}

public final class AppSettingsStore: ObservableObject {
    @Published public var launchAtLogin: Bool {
        didSet { saveBool(launchAtLogin, for: Keys.launchAtLogin) }
    }
    @Published public var showInDock: Bool {
        didSet {
            saveBool(showInDock, for: Keys.showInDock)
            applyActivationPolicy()
        }
    }
    @Published public var theme: AudioRouterTheme {
        didSet { defaults.set(theme.rawValue, forKey: Keys.theme) }
    }
    @Published public var showUnsupportedNotes: Bool {
        didSet { saveBool(showUnsupportedNotes, for: Keys.showUnsupportedNotes) }
    }
    @Published public var demoMode: Bool {
        didSet { saveBool(demoMode, for: Keys.demoMode) }
    }
    @Published public var automaticallyCheckForUpdates: Bool {
        didSet { saveBool(automaticallyCheckForUpdates, for: Keys.automaticallyCheckForUpdates) }
    }
    @Published public var protectPlaybackDuringDeviceChanges: Bool {
        didSet { saveBool(protectPlaybackDuringDeviceChanges, for: Keys.protectPlaybackDuringDeviceChanges) }
    }
    @Published public var hasCompletedOnboarding: Bool {
        didSet { saveBool(hasCompletedOnboarding, for: Keys.hasCompletedOnboarding) }
    }

    private let defaults: UserDefaults

    public var effectiveColorScheme: ColorScheme {
        .dark
    }

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        launchAtLogin = defaults.bool(forKey: Keys.launchAtLogin)
        showInDock = defaults.object(forKey: Keys.showInDock) as? Bool ?? true
        theme = defaults.string(forKey: Keys.theme).flatMap(AudioRouterTheme.init(rawValue:)) ?? .dark
        showUnsupportedNotes = defaults.object(forKey: Keys.showUnsupportedNotes) as? Bool ?? true
        demoMode = defaults.bool(forKey: Keys.demoMode)
        automaticallyCheckForUpdates = defaults.object(forKey: Keys.automaticallyCheckForUpdates) as? Bool ?? true
        protectPlaybackDuringDeviceChanges = defaults.object(forKey: Keys.protectPlaybackDuringDeviceChanges) as? Bool ?? true
        hasCompletedOnboarding = defaults.bool(forKey: Keys.hasCompletedOnboarding)
    }

    public func setLaunchAtLogin(_ enabled: Bool) throws {
        launchAtLogin = enabled
        if #available(macOS 13.0, *) {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        }
    }

    public func applyActivationPolicy() {
        applyAppearance()
        NSApp?.setActivationPolicy(showInDock ? .regular : .accessory)
    }

    public func applyAppearance() {
        NSApp?.appearance = NSAppearance(named: .darkAqua)
    }

    public func reset() {
        launchAtLogin = false
        showInDock = true
        theme = .dark
        showUnsupportedNotes = true
        demoMode = false
        automaticallyCheckForUpdates = true
        protectPlaybackDuringDeviceChanges = true
        hasCompletedOnboarding = false
        applyActivationPolicy()
    }

    private func saveBool(_ value: Bool, for key: String) {
        defaults.set(value, forKey: key)
    }

    enum Keys {
        static let launchAtLogin = "AudioRouter.launchAtLogin"
        static let showInDock = "AudioRouter.showInDock"
        static let theme = "AudioRouter.theme"
        static let showUnsupportedNotes = "AudioRouter.showUnsupportedNotes"
        static let demoMode = "AudioRouter.demoMode"
        static let automaticallyCheckForUpdates = "AudioRouter.automaticallyCheckForUpdates"
        static let protectPlaybackDuringDeviceChanges = "AudioRouter.protectPlaybackDuringDeviceChanges"
        static let hasCompletedOnboarding = "AudioRouter.hasCompletedOnboarding"
    }
}
