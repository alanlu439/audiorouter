import SwiftUI

public struct SettingsView: View {
    @ObservedObject private var store: AudioRouterStore

    public init(store: AudioRouterStore) {
        self.store = store
    }

    public var body: some View {
        NavigationSplitView {
            List(selection: $store.selectedSettingsSection) {
                ForEach(SettingsSection.allCases) { section in
                    Label(section.rawValue, systemImage: section.systemImage)
                        .tag(section)
                }
            }
            .listStyle(.sidebar)
        } detail: {
            SettingsDetailView(section: store.selectedSettingsSection, store: store)
                .padding(20)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .preferredColorScheme(store.settings.theme.colorScheme)
    }
}

struct SettingsDetailView: View {
    let section: SettingsSection
    @ObservedObject var store: AudioRouterStore

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                switch section {
                case .general:
                    GeneralSettingsView(store: store)
                case .devices:
                    DevicesView(store: store)
                case .shortcuts:
                    ShortcutsSettingsView(store: store)
                case .presets:
                    PresetsView(store: store)
                case .advanced:
                    AdvancedSettingsView(store: store)
                }
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
    }
}

private struct GeneralSettingsView: View {
    @ObservedObject var store: AudioRouterStore

    var body: some View {
        DockCard {
            SectionHeader(title: "General", systemImage: "gearshape")
            Toggle("Launch at login", isOn: launchAtLoginBinding)
            Toggle("Show app in Dock", isOn: showInDockBinding)
            Picker("Theme", selection: themeBinding) {
                ForEach(AudioRouterTheme.allCases) { theme in
                    Text(theme.rawValue).tag(theme)
                }
            }
            .pickerStyle(.segmented)
        }
    }

    private var launchAtLoginBinding: Binding<Bool> {
        Binding(
            get: { store.settings.launchAtLogin },
            set: { store.setLaunchAtLogin($0) }
        )
    }

    private var showInDockBinding: Binding<Bool> {
        Binding(
            get: { store.settings.showInDock },
            set: { store.settings.showInDock = $0 }
        )
    }

    private var themeBinding: Binding<AudioRouterTheme> {
        Binding(
            get: { store.settings.theme },
            set: { store.settings.theme = $0 }
        )
    }
}

private struct ShortcutsSettingsView: View {
    @ObservedObject var store: AudioRouterStore
    @State private var editingKeys: [ShortcutAction: String] = [:]

    var body: some View {
        DockCard {
            SectionHeader(title: "Shortcuts", systemImage: "keyboard")
            ForEach(ShortcutAction.allCases) { action in
                let binding = store.shortcutManager.shortcut(for: action)
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(action.title)
                            .font(.subheadline.weight(.semibold))
                        Text(action == .openPopover ? "Local command records the request. Global popover opening is TODO." : "Local app command")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Toggle("⌘", isOn: modifierBinding(action, .command))
                        .labelsHidden()
                    Toggle("⌥", isOn: modifierBinding(action, .option))
                        .labelsHidden()
                    TextField("Key", text: keyBinding(action, defaultValue: binding.key))
                        .frame(width: 38)
                        .textFieldStyle(.roundedBorder)
                    Text(binding.displayValue)
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                        .frame(width: 56, alignment: .trailing)
                }
            }
            Button("Reset Shortcuts") {
                store.shortcutManager.reset()
                editingKeys.removeAll()
            }
        }
    }

    private func keyBinding(_ action: ShortcutAction, defaultValue: String) -> Binding<String> {
        Binding(
            get: { editingKeys[action] ?? defaultValue },
            set: { value in
                editingKeys[action] = value
                let current = store.shortcutManager.shortcut(for: action)
                store.shortcutManager.update(action: action, key: value, modifiers: current.modifiers)
            }
        )
    }

    private func modifierBinding(_ action: ShortcutAction, _ modifier: EventModifiers) -> Binding<Bool> {
        Binding(
            get: { store.shortcutManager.shortcut(for: action).modifiers.contains(modifier) },
            set: { enabled in
                var current = store.shortcutManager.shortcut(for: action)
                if enabled {
                    current.modifiers.insert(modifier)
                } else {
                    current.modifiers.remove(modifier)
                }
                store.shortcutManager.update(action: action, key: current.key, modifiers: current.modifiers)
            }
        )
    }
}

private struct AdvancedSettingsView: View {
    @ObservedObject var store: AudioRouterStore
    @State private var showDebug = false

    var body: some View {
        DockCard {
            SectionHeader(title: "Advanced", systemImage: "slider.horizontal.3")
            Toggle("Show unsupported feature notes", isOn: unsupportedNotesBinding)
            Button {
                showDebug.toggle()
            } label: {
                Label("Debug Audio Device List", systemImage: "list.bullet.rectangle")
            }
            if showDebug {
                ScrollView(.horizontal) {
                    Text(store.debugDeviceList.isEmpty ? "No devices loaded." : store.debugDeviceList)
                        .font(.caption.monospaced())
                        .textSelection(.enabled)
                        .padding(10)
                }
                .frame(maxHeight: 180)
                .background(.black.opacity(0.12), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
            Divider()
            Button(role: .destructive) {
                store.resetAllSettings()
            } label: {
                Label("Reset All Settings", systemImage: "arrow.counterclockwise")
            }
        }
    }

    private var unsupportedNotesBinding: Binding<Bool> {
        Binding(
            get: { store.settings.showUnsupportedNotes },
            set: { store.settings.showUnsupportedNotes = $0 }
        )
    }
}
