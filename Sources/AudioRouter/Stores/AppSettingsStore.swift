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
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
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
        didSet { defaults.set(theme.rawValue, forKey: Keys.theme) }
    }
    @Published public var showUnsupportedNotes: Bool {
        didSet { saveBool(showUnsupportedNotes, for: Keys.showUnsupportedNotes) }
    }
    @Published public var demoMode: Bool {
        didSet { saveBool(demoMode, for: Keys.demoMode) }
    }

    private let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        launchAtLogin = defaults.bool(forKey: Keys.launchAtLogin)
        showInDock = defaults.object(forKey: Keys.showInDock) as? Bool ?? true
        theme = defaults.string(forKey: Keys.theme).flatMap(AudioRouterTheme.init(rawValue:)) ?? .system
        showUnsupportedNotes = defaults.object(forKey: Keys.showUnsupportedNotes) as? Bool ?? true
        demoMode = defaults.bool(forKey: Keys.demoMode)
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
        NSApp.setActivationPolicy(showInDock ? .regular : .accessory)
    }

    public func reset() {
        launchAtLogin = false
        showInDock = true
        theme = .system
        showUnsupportedNotes = true
        demoMode = false
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
    }
}
