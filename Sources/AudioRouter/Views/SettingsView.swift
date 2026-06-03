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

private struct ShortcutsSettingsView: View {
    @ObservedObject var store: AudioRouterStore
    @State private var editingKeys: [ShortcutAction: String] = [:]

    var body: some View {
        ConsoleFrame {
            VStack(alignment: .leading, spacing: 12) {
                ConsolePageHeader(
                    title: "Shortcuts",
                    subtitle: "Keyboard controls for selected apps, routes, outputs, and setups.",
                    systemImage: "keyboard",
                    tint: ConsolePalette.blue
                ) {
                    StatusLabel(text: "\(ShortcutAction.allCases.count) actions", status: .working)
                }

                ConsolePanel(
                    title: "Command Rack",
                    systemImage: "keyboard",
                    trailing: "\(ShortcutAction.allCases.count)",
                    tint: ConsolePalette.blue
                ) {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(ShortcutAction.allCases) { action in
                            shortcutRow(action)
                        }

                        HStack {
                            Spacer()
                            Button {
                                store.shortcutManager.reset()
                                editingKeys.removeAll()
                            } label: {
                                Label("Reset Shortcuts", systemImage: "arrow.counterclockwise")
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                            .accessibilityHint("Restores default local shortcuts")
                        }
                    }
                }
            }
        }
    }

    private func shortcutRow(_ action: ShortcutAction) -> some View {
        let binding = store.shortcutManager.shortcut(for: action)
        return HStack {
            Image(systemName: action.systemImage)
                .foregroundStyle(ConsolePalette.blue)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text(action.title)
                    .font(.subheadline.weight(.semibold))
                Text(action == .openPopover ? "Open AudioRouter from the app command path." : "Click modifiers and key to edit visually.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Toggle("Command", isOn: modifierBinding(action, .command))
                .labelsHidden()
                .accessibilityLabel("\(action.title) command modifier")
            Toggle("Option", isOn: modifierBinding(action, .option))
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
                .font(.caption.monospaced().weight(.bold))
                .foregroundStyle(ConsolePalette.amber)
                .frame(width: 64, alignment: .trailing)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(ConsolePalette.inset.opacity(0.78), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color.white.opacity(0.07), lineWidth: 1)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("\(action.title), current shortcut \(binding.displayValue)")
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
        ConsoleFrame {
            VStack(alignment: .leading, spacing: 14) {
                ConsolePageHeader(
                    title: "Advanced",
                    subtitle: "System behavior, permissions, updates, and diagnostics.",
                    systemImage: "gearshape.2.fill",
                    tint: ConsolePalette.teal
                ) {
                    HStack(spacing: 8) {
                        StatusLabel(
                            text: store.settings.demoMode ? "Demo" : "Live",
                            status: store.settings.demoMode ? .demo : .working
                        )
                        StatusLabel(
                            text: store.backendReadinessTitle,
                            status: store.backendReadinessState.visualStatus
                        )
                    }
                }

                LazyVGrid(columns: advancedColumns, alignment: .leading, spacing: 14) {
                    BackendStatusPanel(store: store, compact: true)

                    ConsolePanel(title: "App", systemImage: "macwindow", tint: ConsolePalette.teal) {
                        VStack(alignment: .leading, spacing: 9) {
                            ToggleRow(
                                title: "Launch at login",
                                systemImage: "power",
                                isOn: launchAtLoginBinding
                            )
                            ToggleRow(
                                title: "Show in Dock",
                                systemImage: "dock.rectangle",
                                isOn: showInDockBinding
                            )
                            DarkAppearanceRow()
                            ToggleRow(
                                title: "Demo Mode",
                                systemImage: "play.rectangle",
                                isOn: demoModeBinding
                            )
                        }
                    }

                    ConsolePanel(title: "Permissions", systemImage: "checkmark.shield", tint: ConsolePalette.green) {
                        VStack(alignment: .leading, spacing: 8) {
                            AdvancedActionRow(
                                title: "Guided Setup",
                                detail: "Open route setup",
                                systemImage: "sparkles.rectangle.stack"
                            ) {
                                store.showOnboarding()
                            }
                            AdvancedActionRow(
                                title: "Audio Permission",
                                detail: permissionStatusText,
                                systemImage: "waveform.badge.magnifyingglass"
                            ) {
                                store.probeProcessTapPermission()
                            }
                            AdvancedActionRow(
                                title: "Privacy Settings",
                                detail: "System Audio Recording",
                                systemImage: "switch.2"
                            ) {
                                store.openSystemAudioPermissionSettings()
                            }
                        }
                    }

                    UpdateStatusView(store: store, compact: true)

                    ConsolePanel(title: "Diagnostics", systemImage: "stethoscope", tint: ConsolePalette.blue) {
                        VStack(alignment: .leading, spacing: 9) {
                            ToggleRow(
                                title: "Unsupported notes",
                                systemImage: "exclamationmark.bubble",
                                isOn: unsupportedNotesBinding
                            )
                            Button {
                                showDebug.toggle()
                            } label: {
                                Label(showDebug ? "Hide Device List" : "Show Device List", systemImage: "list.bullet.rectangle")
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                            .accessibilityHint("Shows the raw Core Audio device list")
                            if showDebug {
                                ScrollView(.horizontal) {
                                    Text(store.debugDeviceList.isEmpty ? "No devices loaded." : store.debugDeviceList)
                                        .font(.caption.monospaced())
                                        .textSelection(.enabled)
                                        .padding(10)
                                }
                                .frame(maxHeight: 150)
                                .background(ConsolePalette.inset.opacity(0.86), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                            }
                        }
                    }

                    ConsolePanel(title: "Reset", systemImage: "exclamationmark.triangle", tint: ConsolePalette.red) {
                        Button(role: .destructive) {
                            store.resetAllSettings()
                        } label: {
                            Label("Reset All Settings", systemImage: "arrow.counterclockwise")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .accessibilityHint("Restores AudioRouter preferences to defaults")
                    }
                }
            }
        }
    }

    private var advancedColumns: [GridItem] {
        [
            GridItem(.adaptive(minimum: 300, maximum: 460), spacing: 14, alignment: .top)
        ]
    }

    private var permissionStatusText: String {
        store.processTapProbeMessage ?? "Check access"
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

private struct ToggleRow: View {
    let title: String
    let systemImage: String
    let isOn: Binding<Bool>

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: systemImage)
                .foregroundStyle(ConsolePalette.teal)
                .frame(width: 22)
            Text(title)
                .font(.subheadline.weight(.semibold))
            Spacer()
            Toggle(title, isOn: isOn)
                .labelsHidden()
                .toggleStyle(.switch)
        }
        .padding(.vertical, 2)
        .padding(.horizontal, 10)
        .frame(minHeight: 34)
        .background(ConsolePalette.inset.opacity(0.72), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color.white.opacity(0.06), lineWidth: 1)
        }
        .accessibilityElement(children: .contain)
    }
}

private struct AdvancedActionRow: View {
    let title: String
    let detail: String
    let systemImage: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: systemImage)
                    .foregroundStyle(ConsolePalette.teal)
                    .frame(width: 22)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                    Text(detail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.tertiary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(ConsolePalette.inset.opacity(0.72), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color.white.opacity(0.06), lineWidth: 1)
        }
        .accessibilityLabel(title)
        .accessibilityHint(detail)
    }
}

private struct DarkAppearanceRow: View {
    var body: some View {
        HStack {
            Label("Appearance", systemImage: "moon.fill")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(ConsolePalette.teal)
            Spacer()
            Text("Dark")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(ConsolePalette.inset, in: Capsule())
        }
        .padding(.horizontal, 10)
        .frame(minHeight: 34)
        .background(ConsolePalette.inset.opacity(0.72), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color.white.opacity(0.06), lineWidth: 1)
        }
        .help("AudioRouter uses a fixed dark appearance for console readability.")
    }
}
