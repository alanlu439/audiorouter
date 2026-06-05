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
    @State private var selectedAdvancedSection: AdvancedSection = .system

    var body: some View {
        ConsoleFrame {
            VStack(alignment: .leading, spacing: 18) {
                ConsolePageHeader(
                    title: "Advanced",
                    subtitle: "Choose one system area at a time. Backend status stays visible above the controls.",
                    systemImage: "gearshape.2.fill",
                    tint: ConsolePalette.teal
                ) {
                    AdvancedHeaderStatus(store: store)
                }

                BackendStatusPanel(store: store, compact: true)

                AdvancedSectionPicker(selection: $selectedAdvancedSection)

                selectedSectionContent
            }
        }
    }

    @ViewBuilder
    private var selectedSectionContent: some View {
        switch selectedAdvancedSection {
        case .system:
            ConsolePanel(title: "System Controls", systemImage: "slider.horizontal.3", tint: ConsolePalette.teal) {
                VStack(alignment: .leading, spacing: 12) {
                    AdvancedSectionIntro(
                        title: "App behavior",
                        detail: "These settings change how AudioRouter starts, appears, and switches between Live and Demo modes."
                    )
                    VStack(alignment: .leading, spacing: 10) {
                        ToggleRow(
                            title: "Launch at login",
                            detail: "Start AudioRouter automatically",
                            systemImage: "power",
                            isOn: launchAtLoginBinding
                        )
                        ToggleRow(
                            title: "Show in Dock",
                            detail: "Keep a Dock icon while running",
                            systemImage: "dock.rectangle",
                            isOn: showInDockBinding
                        )
                        ToggleRow(
                            title: "Demo Mode",
                            detail: "Use sample apps, devices, and meters",
                            systemImage: "play.rectangle",
                            isOn: demoModeBinding
                        )
                        ToggleRow(
                            title: "Protect playback",
                            detail: "Debounce AirPods and Bluetooth changes before refreshing routes",
                            systemImage: "earbuds",
                            isOn: protectPlaybackBinding
                        )
                        ToggleRow(
                            title: "Publish mixer inputs",
                            detail: "Expose route apps as selectable macOS input devices when taps are available",
                            systemImage: "music.mic",
                            isOn: appInputPublishingBinding
                        )
                        HALDriverStatusView()
                        AppInputPublishingStatusView(store: store)
                        DarkAppearanceRow()
                    }
                }
            }

        case .permissions:
            ConsolePanel(title: "Permissions", systemImage: "checkmark.shield", tint: ConsolePalette.green) {
                VStack(alignment: .leading, spacing: 12) {
                    AdvancedSectionIntro(
                        title: "Audio access",
                        detail: "Use these controls when meters, process taps, or setup prompts need macOS permission help."
                    )
                    VStack(alignment: .leading, spacing: 10) {
                        AdvancedActionRow(
                            title: "Guided Setup",
                            detail: "Open the route setup flow",
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
                            detail: "Open System Settings",
                            systemImage: "switch.2"
                        ) {
                            store.openSystemAudioPermissionSettings()
                        }
                    }
                }
            }

        case .updates:
            UpdateStatusView(store: store, compact: false)

        case .diagnostics:
            ConsolePanel(title: "Diagnostics", systemImage: "stethoscope", tint: ConsolePalette.blue) {
                VStack(alignment: .leading, spacing: 12) {
                    AdvancedSectionIntro(
                        title: "Troubleshooting",
                        detail: "Keep these visible only when you are checking devices or public API limitation notes."
                    )
                    VStack(alignment: .leading, spacing: 10) {
                        ToggleRow(
                            title: "Unsupported notes",
                            detail: "Show public API limitation labels",
                            systemImage: "exclamationmark.bubble",
                            isOn: unsupportedNotesBinding
                        )
                        AdvancedActionRow(
                            title: showDebug ? "Hide Device List" : "Show Device List",
                            detail: "\(store.outputDevices.count) outputs, \(store.inputDevices.count) inputs",
                            systemImage: "list.bullet.rectangle"
                        ) {
                            showDebug.toggle()
                        }
                        if showDebug {
                            ScrollView(.horizontal) {
                                Text(store.debugDeviceList.isEmpty ? "No devices loaded." : store.debugDeviceList)
                                    .font(.caption.monospaced())
                                    .textSelection(.enabled)
                                .padding(10)
                            }
                            .frame(maxHeight: 130)
                            .background(ConsolePalette.inset.opacity(0.86), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                        }
                    }
                }
            }

        case .reset:
            ConsolePanel(title: "Reset", systemImage: "exclamationmark.triangle", tint: ConsolePalette.red) {
                VStack(alignment: .leading, spacing: 12) {
                    AdvancedSectionIntro(
                        title: "Start over",
                        detail: "This is intentionally separated from daily controls so it is harder to trigger by accident."
                    )
                    HStack(spacing: 16) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Reset AudioRouter")
                                .font(.subheadline.weight(.semibold))
                            Text("Restore preferences, routes, profiles, and visual settings to defaults.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        Spacer()
                        Button(role: .destructive) {
                            store.resetAllSettings()
                        } label: {
                            Label("Reset", systemImage: "arrow.counterclockwise")
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .accessibilityHint("Restores AudioRouter preferences to defaults")
                    }
                }
            }
        }
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

    private var protectPlaybackBinding: Binding<Bool> {
        Binding(
            get: { store.settings.protectPlaybackDuringDeviceChanges },
            set: { value in
                store.settings.protectPlaybackDuringDeviceChanges = value
            }
        )
    }

    private var appInputPublishingBinding: Binding<Bool> {
        Binding(
            get: { store.settings.publishAppInputsAsSystemDevices },
            set: { value in
                store.settings.publishAppInputsAsSystemDevices = value
                store.refresh(silent: true)
            }
        )
    }

}

private enum AdvancedSection: String, CaseIterable, Identifiable {
    case system = "System"
    case permissions = "Access"
    case updates = "Updates"
    case diagnostics = "Diagnostics"
    case reset = "Reset"

    var id: String { rawValue }

    var systemImage: String {
        switch self {
        case .system: return "slider.horizontal.3"
        case .permissions: return "checkmark.shield"
        case .updates: return "arrow.down.circle"
        case .diagnostics: return "stethoscope"
        case .reset: return "exclamationmark.triangle"
        }
    }

    var tint: Color {
        switch self {
        case .system: return ConsolePalette.teal
        case .permissions: return ConsolePalette.green
        case .updates: return ConsolePalette.blue
        case .diagnostics: return ConsolePalette.blue
        case .reset: return ConsolePalette.red
        }
    }
}

private struct AdvancedSectionPicker: View {
    @Binding var selection: AdvancedSection

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Advanced Area")
                .font(.caption.weight(.bold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)

            HStack(spacing: 10) {
                ForEach(AdvancedSection.allCases) { section in
                    Button {
                        selection = section
                    } label: {
                        HStack(spacing: 7) {
                            Image(systemName: section.systemImage)
                                .font(.system(size: 12, weight: .bold))
                            Text(section.rawValue)
                                .font(.caption.weight(.bold))
                                .lineLimit(1)
                        }
                        .foregroundStyle(selection == section ? section.tint : .secondary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 9)
                        .frame(maxWidth: .infinity)
                        .background(
                            (selection == section ? section.tint.opacity(0.14) : ConsolePalette.inset.opacity(0.78)),
                            in: RoundedRectangle(cornerRadius: 9, style: .continuous)
                        )
                        .overlay {
                            RoundedRectangle(cornerRadius: 9, style: .continuous)
                                .stroke(selection == section ? section.tint.opacity(0.38) : ConsolePalette.stroke, lineWidth: 1)
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(section.rawValue)
                    .accessibilityValue(selection == section ? "Selected" : "Not selected")
                }
            }
        }
        .padding(14)
        .background(ConsolePalette.header.opacity(0.7), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(ConsolePalette.stroke, lineWidth: 1)
        }
    }
}

private struct AdvancedSectionIntro: View {
    let title: String
    let detail: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.headline.weight(.semibold))
            Text(detail)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 2)
    }
}

private struct ToggleRow: View {
    let title: String
    var detail: String? = nil
    let systemImage: String
    let isOn: Binding<Bool>

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: systemImage)
                .foregroundStyle(ConsolePalette.teal)
                .font(.system(size: 14, weight: .semibold))
                .frame(width: 32, height: 32)
                .background(ConsolePalette.teal.opacity(0.10), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                if let detail {
                    Text(detail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            Spacer()
            Toggle(title, isOn: isOn)
                .labelsHidden()
                .toggleStyle(.switch)
        }
        .padding(.vertical, 11)
        .padding(.horizontal, 12)
        .frame(minHeight: 56)
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
                    .font(.system(size: 14, weight: .semibold))
                    .frame(width: 32, height: 32)
                    .background(ConsolePalette.teal.opacity(0.10), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
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
        .padding(.horizontal, 12)
        .padding(.vertical, 11)
        .frame(minHeight: 56)
        .background(ConsolePalette.inset.opacity(0.72), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color.white.opacity(0.06), lineWidth: 1)
        }
        .accessibilityLabel(title)
        .accessibilityHint(detail)
    }
}

private struct HALDriverStatusView: View {
    @State private var driverInstalled = false

    private static let driverPath = "/Library/Audio/Plug-Ins/HAL/AudioRouterHAL.driver"
    private let installCommand = "./script/install_hal_driver.sh"

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Image(systemName: driverInstalled ? "checkmark.seal.fill" : "externaldrive.badge.plus")
                    .foregroundStyle(driverInstalled ? ConsolePalette.green : ConsolePalette.amber)
                    .font(.system(size: 14, weight: .semibold))
                    .frame(width: 32, height: 32)
                    .background((driverInstalled ? ConsolePalette.green : ConsolePalette.amber).opacity(0.10), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                VStack(alignment: .leading, spacing: 2) {
                    Text(driverInstalled ? "HAL driver installed" : "HAL driver not installed")
                        .font(.subheadline.weight(.semibold))
                    Text(driverInstalled ? "Mixer apps should list AudioRouter Virtual Input after they reopen." : "Install the driver to make AudioRouter appear as a true macOS input device.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
                Button {
                    driverInstalled = FileManager.default.fileExists(atPath: Self.driverPath)
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }

            if !driverInstalled {
                Text("Run `\(installCommand)` from the project folder. macOS will ask for an administrator password and restart Core Audio once.")
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(ConsolePalette.panel.opacity(0.65), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 11)
        .background(ConsolePalette.inset.opacity(0.72), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color.white.opacity(0.06), lineWidth: 1)
        }
        .onAppear {
            driverInstalled = FileManager.default.fileExists(atPath: Self.driverPath)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(driverInstalled ? "HAL driver installed" : "HAL driver not installed")
    }
}

private struct AppInputPublishingStatusView: View {
    @ObservedObject var store: AudioRouterStore

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Image(systemName: statusImage)
                    .foregroundStyle(statusTint)
                    .font(.system(size: 14, weight: .semibold))
                    .frame(width: 32, height: 32)
                    .background(statusTint.opacity(0.10), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                VStack(alignment: .leading, spacing: 2) {
                    Text(statusTitle)
                        .font(.subheadline.weight(.semibold))
                    Text(statusDetail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
                Button {
                    store.refresh(silent: true)
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }

            if !store.publishedAppInputDevices.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(store.publishedAppInputDevices) { device in
                        HStack(spacing: 8) {
                            Image(systemName: "music.mic")
                                .foregroundStyle(ConsolePalette.teal)
                            Text(device.name)
                                .font(.caption.weight(.semibold))
                                .lineLimit(1)
                            Spacer()
                            Text("\(device.channelCount) ch")
                                .font(.caption2.monospacedDigit().weight(.bold))
                                .foregroundStyle(ConsolePalette.teal)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(ConsolePalette.teal.opacity(0.12), in: Capsule())
                        }
                    }
                }
                .padding(10)
                .background(ConsolePalette.panel.opacity(0.65), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 11)
        .background(ConsolePalette.inset.opacity(0.72), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color.white.opacity(0.06), lineWidth: 1)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(statusTitle)
        .accessibilityHint(statusDetail)
    }

    private var statusImage: String {
        store.publishedAppInputDevices.isEmpty ? "exclamationmark.triangle.fill" : "checkmark.circle.fill"
    }

    private var statusTint: Color {
        store.publishedAppInputDevices.isEmpty ? ConsolePalette.amber : ConsolePalette.green
    }

    private var statusTitle: String {
        store.publishedAppInputDevices.isEmpty ? "No mixer inputs visible yet" : "Published mixer inputs"
    }

    private var statusDetail: String {
        if store.publishedAppInputDevices.isEmpty {
            return store.processTapProbeMessage
                ?? "Open the app you want, let it produce audio once, then refresh. macOS only exposes app inputs when a process tap can be created."
        }
        let names = store.publishedAppInputDevices.map(\.sourceName).joined(separator: ", ")
        return "Select these inputs in mixer software while AudioRouter is running: \(names)."
    }
}

private struct DarkAppearanceRow: View {
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "moon.fill")
                .foregroundStyle(ConsolePalette.teal)
                .font(.system(size: 14, weight: .semibold))
                .frame(width: 32, height: 32)
                .background(ConsolePalette.teal.opacity(0.10), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                Text("Appearance")
                    .font(.subheadline.weight(.semibold))
                Text("Fixed dark console theme")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer()
            Text("Dark")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(ConsolePalette.inset, in: Capsule())
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 11)
        .frame(minHeight: 56)
        .background(ConsolePalette.inset.opacity(0.72), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color.white.opacity(0.06), lineWidth: 1)
        }
        .help("AudioRouter uses a fixed dark appearance for console readability.")
    }
}

private struct AdvancedHeaderStatus: View {
    @ObservedObject var store: AudioRouterStore

    var body: some View {
        HStack(spacing: 8) {
            CompactModeBadge(
                text: store.settings.demoMode ? "Demo" : "Live",
                tint: store.settings.demoMode ? ConsolePalette.amber : ConsolePalette.green
            )
            CompactModeBadge(
                text: store.backendReadinessTitle,
                tint: store.backendReadinessState.visualStatus.foreground
            )
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Mode \(store.settings.demoMode ? "Demo" : "Live"), backend \(store.backendReadinessTitle)")
    }
}

private struct CompactModeBadge: View {
    let text: String
    let tint: Color

    var body: some View {
        HStack(spacing: 5) {
            ConsoleLED(color: tint)
            Text(text)
                .font(.caption.weight(.bold))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .foregroundStyle(tint)
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(tint.opacity(0.12), in: Capsule())
        .overlay {
            Capsule()
                .stroke(tint.opacity(0.28), lineWidth: 1)
        }
    }
}
