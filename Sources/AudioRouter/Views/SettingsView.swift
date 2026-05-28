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
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .navigationTitle("AudioRouter Settings")
        .preferredColorScheme(store.settings.effectiveColorScheme)
    }
}

struct SettingsDetailView: View {
    let section: SettingsSection
    @ObservedObject var store: AudioRouterStore

    var body: some View {
        GeometryReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    switch section {
                    case .dashboard:
                        RoutingDashboardView(store: store)
                    case .mixer:
                        MixerView(store: store)
                    case .devices:
                        DevicesView(store: store)
                    case .eq:
                        EQView(eqManager: store.eqManager)
                    case .setups:
                        PresetsView(store: store)
                    case .shortcuts:
                        ShortcutsSettingsView(store: store)
                    case .advanced:
                        AdvancedSettingsView(store: store)
                    }
                }
                .padding(14)
                .frame(
                    minWidth: proxy.size.width,
                    minHeight: proxy.size.height,
                    alignment: .topLeading
                )
            }
            .scrollIndicators(.visible)
            .background(Color(red: 0.035, green: 0.037, blue: 0.042))
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
            DarkAppearanceRow()
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
                    Image(systemName: action.systemImage)
                        .foregroundStyle(.teal)
                        .frame(width: 24)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(action.title)
                            .font(.subheadline.weight(.semibold))
                        Text(action == .openPopover ? "Open AudioRouter from the app command path." : "Click modifiers and key to edit visually.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Toggle("⌘", isOn: modifierBinding(action, .command))
                        .labelsHidden()
                        .accessibilityLabel("\(action.title) command modifier")
                    Toggle("⌥", isOn: modifierBinding(action, .option))
                        .labelsHidden()
                        .accessibilityLabel("\(action.title) option modifier")
                    Picker("Key", selection: keyBinding(action, defaultValue: binding.key)) {
                        ForEach(visualKeys, id: \.self) { key in
                            Text(key.uppercased()).tag(key)
                        }
                    }
                    .labelsHidden()
                    .frame(width: 64)
                    .accessibilityLabel("\(action.title) key")
                    .accessibilityValue(binding.key.uppercased())
                    Text(binding.displayValue)
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                        .frame(width: 56, alignment: .trailing)
                }
                .accessibilityElement(children: .contain)
                .accessibilityLabel("\(action.title), current shortcut \(binding.displayValue)")
            }
            Button("Reset Shortcuts") {
                store.shortcutManager.reset()
                editingKeys.removeAll()
            }
            .accessibilityHint("Restores default local shortcuts")
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

    private var visualKeys: [String] {
        ["a", "m", "s", "=", "-", "[", "]", "1", "2", "3", "r", "p"]
    }
}

private struct AdvancedSettingsView: View {
    @ObservedObject var store: AudioRouterStore
    @State private var showDebug = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            BackendStatusPanel(store: store)

            DockCard {
                SectionHeader(title: "Advanced", systemImage: "slider.horizontal.3")
                Toggle("Launch at login", isOn: launchAtLoginBinding)
                Toggle("Show app in Dock", isOn: showInDockBinding)
                DarkAppearanceRow()
                Divider()
                Toggle("Demo Mode", isOn: demoModeBinding)
                Toggle("Show unsupported feature notes", isOn: unsupportedNotesBinding)
                Toggle("Automatically check for updates", isOn: automaticUpdatesBinding)
                    .accessibilityHint("Checks GitHub Releases when AudioRouter starts, no more than every six hours")
                Text("True per-app routing and EQ work only when AudioRouter can capture an app stream and render it to a selected output. Routes that cannot start are saved and retried instead of being shown as live.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                }

            DockCard {
                SectionHeader(title: "Onboarding & Permissions", systemImage: "checkmark.shield")
                Text("macOS security prompts cannot be auto-approved by any normal app. AudioRouter can open the relevant settings and start a safe probe so you can approve System Audio Recording when macOS asks.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 8) {
                    Button {
                        store.showOnboarding()
                    } label: {
                        Label("Open Guided Setup", systemImage: "sparkles.rectangle.stack")
                    }
                    Button {
                        store.probeProcessTapPermission()
                    } label: {
                        Label("Check Audio Permission", systemImage: "waveform.badge.magnifyingglass")
                    }
                    Button {
                        store.openSystemAudioPermissionSettings()
                    } label: {
                        Label("Open Privacy Settings", systemImage: "switch.2")
                    }
                }
                .controlSize(.small)
                if let message = store.processTapProbeMessage {
                    Text(message)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            UpdateStatusView(store: store)

            DockCard {
                SectionHeader(title: "Diagnostics", systemImage: "list.bullet.rectangle")
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
    }

    private var unsupportedNotesBinding: Binding<Bool> {
        Binding(
            get: { store.settings.showUnsupportedNotes },
            set: { store.settings.showUnsupportedNotes = $0 }
        )
    }

    private var automaticUpdatesBinding: Binding<Bool> {
        Binding(
            get: { store.settings.automaticallyCheckForUpdates },
            set: { store.setAutomaticallyCheckForUpdates($0) }
        )
    }

    private var demoModeBinding: Binding<Bool> {
        Binding(
            get: { store.settings.demoMode },
            set: { value in
                store.settings.demoMode = value
                store.refresh()
            }
        )
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

}

private struct DarkAppearanceRow: View {
    var body: some View {
        HStack {
            Label("Appearance", systemImage: "moon.fill")
                .font(.subheadline.weight(.semibold))
            Spacer()
            Text("Dark")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(.secondary.opacity(0.12), in: Capsule())
        }
        .help("AudioRouter uses a fixed dark appearance for console readability.")
    }
}
