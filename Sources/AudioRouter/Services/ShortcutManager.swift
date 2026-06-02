import SwiftUI

public final class ShortcutManager: ObservableObject {
    @Published public private(set) var shortcuts: [ShortcutBinding]
    private let defaults: UserDefaults
    private let key = "AudioRouter.Shortcuts"

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let data = defaults.data(forKey: key),
           let decoded = try? JSONDecoder().decode([ShortcutBinding].self, from: data),
           !decoded.isEmpty {
            let migrated = Self.migratedShortcutDefaults(decoded)
            shortcuts = migrated
            if migrated != decoded {
                if let data = try? JSONEncoder().encode(migrated) {
                    defaults.set(data, forKey: key)
                }
            }
        } else {
            shortcuts = Self.defaultShortcuts
        }
    }

    public func shortcut(for action: ShortcutAction) -> ShortcutBinding {
        shortcuts.first { $0.action == action }
            ?? Self.defaultShortcuts.first { $0.action == action }
            ?? ShortcutBinding(action: action, key: "m", modifiers: [.command, .option])
    }

    public func update(action: ShortcutAction, key: String, modifiers: EventModifiers) {
        let cleanKey = String(key.prefix(1)).isEmpty ? " " : String(key.prefix(1))
        let binding = ShortcutBinding(action: action, key: cleanKey, modifiers: modifiers)
        if let index = shortcuts.firstIndex(where: { $0.action == action }) {
            shortcuts[index] = binding
        } else {
            shortcuts.append(binding)
        }
        save()
    }

    public func reset() {
        shortcuts = Self.defaultShortcuts
        save()
    }

    private func save() {
        if let data = try? JSONEncoder().encode(shortcuts) {
            defaults.set(data, forKey: key)
        }
    }

    public static let defaultShortcuts: [ShortcutBinding] = [
        ShortcutBinding(action: .muteSystem, key: "m", modifiers: [.command, .option]),
        ShortcutBinding(action: .increaseVolume, key: "=", modifiers: [.command]),
        ShortcutBinding(action: .decreaseVolume, key: "-", modifiers: [.command]),
        ShortcutBinding(action: .nextOutputDevice, key: "]", modifiers: [.command, .option]),
        ShortcutBinding(action: .previousOutputDevice, key: "[", modifiers: [.command, .option]),
        ShortcutBinding(action: .muteSelectedApp, key: "s", modifiers: [.command, .option]),
        ShortcutBinding(action: .applyPreset1, key: "1", modifiers: [.command, .option]),
        ShortcutBinding(action: .applyPreset2, key: "2", modifiers: [.command, .option]),
        ShortcutBinding(action: .applyPreset3, key: "3", modifiers: [.command, .option]),
        ShortcutBinding(action: .openPopover, key: "a", modifiers: [.command, .option])
    ]

    private static func migratedShortcutDefaults(_ bindings: [ShortcutBinding]) -> [ShortcutBinding] {
        bindings.map { binding in
            switch binding.action {
            case .increaseVolume where binding.key == "=" && binding.modifiers == [.command, .option]:
                return ShortcutBinding(action: .increaseVolume, key: "=", modifiers: [.command])
            case .decreaseVolume where binding.key == "-" && binding.modifiers == [.command, .option]:
                return ShortcutBinding(action: .decreaseVolume, key: "-", modifiers: [.command])
            default:
                return binding
            }
        }
    }
}
