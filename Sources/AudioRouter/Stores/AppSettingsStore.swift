import AppKit
import ServiceManagement
import SwiftUI

public enum AudioRouterTheme: String, Codable, CaseIterable, Identifiable {
    case system = "System"
    case light = "Light"
    case dark = "Dark"

    public var id: String { rawValue }

    public var colorScheme: ColorScheme? {
        switch self {
        case .system:
            return nil
        case .light:
            return .light
        case .dark:
            return .dark
        }
    }

    public var appKitAppearanceName: NSAppearance.Name? {
        switch self {
        case .system:
            return nil
        case .light:
            return .aqua
        case .dark:
            return .darkAqua
        }
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
        didSet {
            defaults.set(theme.rawValue, forKey: Keys.theme)
            applyAppearance()
        }
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
    @Published public var keepMediaPlayingDuringDeviceChanges: Bool {
        didSet { saveBool(keepMediaPlayingDuringDeviceChanges, for: Keys.keepMediaPlayingDuringDeviceChanges) }
    }
    @Published public var publishAppInputsAsSystemDevices: Bool {
        didSet { saveBool(publishAppInputsAsSystemDevices, for: Keys.publishAppInputsAsSystemDevices) }
    }
    @Published public var hasCompletedOnboarding: Bool {
        didSet { saveBool(hasCompletedOnboarding, for: Keys.hasCompletedOnboarding) }
    }

    private let defaults: UserDefaults

    public var effectiveColorScheme: ColorScheme? {
        theme.colorScheme
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
        keepMediaPlayingDuringDeviceChanges = Self.storedBool(
            defaults: defaults,
            key: Keys.keepMediaPlayingDuringDeviceChanges,
            fallbackKey: Keys.resumeMediaAfterDeviceChanges,
            defaultValue: true
        )
        publishAppInputsAsSystemDevices = defaults.object(forKey: Keys.publishAppInputsAsSystemDevices) as? Bool ?? true
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
        NSApp?.appearance = theme.appKitAppearanceName.flatMap { NSAppearance(named: $0) }
    }

    public func reset() {
        launchAtLogin = false
        showInDock = true
        theme = .system
        showUnsupportedNotes = true
        demoMode = false
        automaticallyCheckForUpdates = true
        protectPlaybackDuringDeviceChanges = true
        keepMediaPlayingDuringDeviceChanges = true
        publishAppInputsAsSystemDevices = true
        hasCompletedOnboarding = false
        applyActivationPolicy()
    }

    private func saveBool(_ value: Bool, for key: String) {
        defaults.set(value, forKey: key)
    }

    private static func storedBool(
        defaults: UserDefaults,
        key: String,
        fallbackKey: String? = nil,
        defaultValue: Bool
    ) -> Bool {
        if let value = defaults.object(forKey: key) as? Bool {
            return value
        }
        if let fallbackKey, let value = defaults.object(forKey: fallbackKey) as? Bool {
            return value
        }
        return defaultValue
    }

    enum Keys {
        static let launchAtLogin = "AudioRouter.launchAtLogin"
        static let showInDock = "AudioRouter.showInDock"
        static let theme = "AudioRouter.theme"
        static let showUnsupportedNotes = "AudioRouter.showUnsupportedNotes"
        static let demoMode = "AudioRouter.demoMode"
        static let automaticallyCheckForUpdates = "AudioRouter.automaticallyCheckForUpdates"
        static let protectPlaybackDuringDeviceChanges = "AudioRouter.protectPlaybackDuringDeviceChanges"
        static let keepMediaPlayingDuringDeviceChanges = "AudioRouter.keepMediaPlayingDuringDeviceChanges"
        static let resumeMediaAfterDeviceChanges = "AudioRouter.resumeMediaAfterDeviceChanges"
        static let publishAppInputsAsSystemDevices = "AudioRouter.publishAppInputsAsSystemDevices"
        static let hasCompletedOnboarding = "AudioRouter.hasCompletedOnboarding"
    }
}
