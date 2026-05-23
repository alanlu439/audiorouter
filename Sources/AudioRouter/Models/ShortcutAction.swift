import SwiftUI

public enum ShortcutAction: String, Codable, CaseIterable, Identifiable {
    case muteSystem
    case increaseVolume
    case decreaseVolume
    case nextOutputDevice
    case openPopover

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .muteSystem: return "Mute / unmute"
        case .increaseVolume: return "Increase volume"
        case .decreaseVolume: return "Decrease volume"
        case .nextOutputDevice: return "Next output"
        case .openPopover: return "Open popover"
        }
    }
}

public struct ShortcutBinding: Codable {
    public var action: ShortcutAction
    public var key: String
    public var modifiers: EventModifiers

    public init(action: ShortcutAction, key: String, modifiers: EventModifiers) {
        self.action = action
        self.key = key
        self.modifiers = modifiers
    }

    public var keyEquivalent: KeyEquivalent {
        KeyEquivalent(Character(key.lowercased()))
    }

    public var displayValue: String {
        let prefix = [
            modifiers.contains(.command) ? "⌘" : "",
            modifiers.contains(.option) ? "⌥" : "",
            modifiers.contains(.shift) ? "⇧" : "",
            modifiers.contains(.control) ? "⌃" : ""
        ].joined()
        return "\(prefix)\(key.uppercased())"
    }

    enum CodingKeys: String, CodingKey {
        case action
        case key
        case rawModifiers
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        action = try container.decode(ShortcutAction.self, forKey: .action)
        key = try container.decode(String.self, forKey: .key)
        modifiers = EventModifiers(rawValue: try container.decode(Int.self, forKey: .rawModifiers))
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(action, forKey: .action)
        try container.encode(key, forKey: .key)
        try container.encode(Int(modifiers.rawValue), forKey: .rawModifiers)
    }
}
