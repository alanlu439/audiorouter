import SwiftUI

public struct MenuBarPopoverView: View {
    @ObservedObject private var store: AudioRouterStore
    @Environment(\.openWindow) private var openWindow
    @State private var selectedSourceID = ""
    @State private var selectedOutputID = ""

    public init(store: AudioRouterStore) {
        self.store = store
    }

    public var body: some View {
        ZStack {
            MenuBarPalette.background
                .ignoresSafeArea()

            VStack(spacing: 0) {
                header
                    .padding(.horizontal, 14)
                    .padding(.top, 14)
                    .padding(.bottom, 10)

                Divider()
                    .opacity(0.22)

                VStack(spacing: 10) {
                    if !store.settings.hasCompletedOnboarding {
                        setupPrompt
                    }

                    if let error = store.lastError {
                        SupportNote(note: error) {
                            store.dismissUnsupportedNote()
                        }
                    }

                    selectedRoutePanel
                    compactRoutesPanel
                }
                .padding(14)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)

                footer
                    .padding(.horizontal, 14)
                    .padding(.bottom, 12)
            }
        }
        .preferredColorScheme(store.settings.effectiveColorScheme)
        .onAppear {
            syncSelectionIfNeeded()
        }
        .onChange(of: store.audioSources) { _, _ in
            syncSelectionIfNeeded()
        }
        .onChange(of: store.outputDevices) { _, _ in
            syncOutputIfNeeded()
        }
        .onChange(of: store.outputGroups) { _, _ in
            syncOutputIfNeeded()
        }
        .onChange(of: selectedSourceID) { _, _ in
            guard !selectedSourceID.isEmpty else { return }
            store.selectedSourceID = selectedSourceID
            syncOutputFromSelectedSource()
        }
    }

    private var header: some View {
        HStack(spacing: 10) {
            AudioRouterLogo(size: 32)

            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 6) {
                    Text("AudioRouter")
                        .font(.system(size: 16, weight: .bold))
                    StatusLabel(
                        text: store.settings.demoMode ? "Demo" : "Live",
                        status: store.settings.demoMode ? .demo : .working
                    )
                }
                Text(store.activeUserProfile.displayName)
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            Button {
                store.refresh()
                syncSelectionIfNeeded()
            } label: {
                Image(systemName: "arrow.clockwise")
                    .frame(width: 24, height: 24)
            }
            .buttonStyle(.plain)
            .background(MenuBarPalette.buttonBackground, in: RoundedRectangle(cornerRadius: 7, style: .continuous))
            .help("Refresh route apps and outputs")
            .accessibilityLabel("Refresh AudioRouter routes")

            Button {
                store.selectedSettingsSection = .dashboard
                openWindow(id: "main")
            } label: {
                Image(systemName: "square.grid.2x2")
                    .frame(width: 24, height: 24)
            }
            .buttonStyle(.plain)
            .background(MenuBarPalette.buttonBackground, in: RoundedRectangle(cornerRadius: 7, style: .continuous))
            .help("Open full routing board")
            .accessibilityLabel("Open full AudioRouter routing board")
        }
    }

    private var setupPrompt: some View {
        MenuBarPanel(tint: .teal) {
            HStack(alignment: .center, spacing: 10) {
                Image(systemName: "point.3.connected.trianglepath.dotted")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.teal)
                    .frame(width: 28, height: 28)
                    .background(.teal.opacity(0.12), in: RoundedRectangle(cornerRadius: 8, style: .continuous))

                VStack(alignment: .leading, spacing: 2) {
                    Text("Quick setup")
                        .font(.subheadline.weight(.semibold))
                    Text("Choose apps and speakers in the full board.")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                Button {
                    openWindow(id: "main")
                    store.showOnboarding()
                } label: {
                    Label("Open", systemImage: "arrow.up.right.square")
                }
                .controlSize(.small)
            }
        }
    }

    private var selectedRoutePanel: some View {
        MenuBarPanel(tint: .orange) {
            if store.audioSources.isEmpty {
                emptyRouteState
            } else if let source = selectedSource {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(alignment: .center, spacing: 10) {
                        AppSourceIcon(source: source)
                            .frame(width: 34, height: 34)

                        VStack(alignment: .leading, spacing: 3) {
                            HStack(spacing: 6) {
                                Picker("Source App", selection: $selectedSourceID) {
                                    ForEach(store.audioSources) { source in
                                        Text(source.appName).tag(source.id)
                                    }
                                }
                                .labelsHidden()
                                .pickerStyle(.menu)
                                .controlSize(.small)
                                .frame(maxWidth: 190, alignment: .leading)

                                SourceQualityPill(
                                    label: store.sourceAudioQualityLabel(for: source),
                                    isLive: store.sourceAudioQualityIsLive(for: source)
                                )
                                .help(store.sourceAudioQualityHelp(for: source))
                            }

                            Text(routeSummary(for: source))
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }

                        Spacer(minLength: 4)

                        MenuRouteStatusPill(source: source, store: store)
                    }

                    routeTargetStrip(for: source)

                    selectedRouteControls(for: source)

                    if let note = selectedRouteNote {
                        Text(note)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
    }

    private var compactRoutesPanel: some View {
        MenuBarPanel(tint: .teal) {
            VStack(alignment: .leading, spacing: 9) {
                HStack {
                    Label("Routes", systemImage: "arrow.triangle.branch")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("\(store.audioSources.count)")
                        .font(.caption2.monospacedDigit().weight(.bold))
                        .foregroundStyle(.secondary)
                }

                if store.audioSources.isEmpty {
                    Text("No route apps available.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    ScrollView {
                        LazyVStack(spacing: 6) {
                            ForEach(store.audioSources) { source in
                                MenuCompactRouteRow(
                                    source: source,
                                    isSelected: source.id == selectedSourceID,
                                    store: store
                                ) {
                                    selectedSourceID = source.id
                                    store.selectedSourceID = source.id
                                    syncOutputFromSelectedSource()
                                }
                            }
                        }
                    }
                    .scrollIndicators(.hidden)
                    .frame(maxHeight: 176)
                }
            }
        }
    }

    private var footer: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 1) {
                Text("AUDIOROUTER")
                    .font(.system(size: 11, weight: .heavy, design: .rounded))
                    .tracking(1.6)
                Text("by Alan")
                    .font(.system(size: 9, weight: .semibold))
            }
            .foregroundStyle(.white.opacity(0.5))
            .accessibilityHidden(true)

            Spacer()

            Button {
                store.selectedSettingsSection = .dashboard
                openWindow(id: "main")
            } label: {
                Label("Add Apps", systemImage: "app.badge.plus")
            }
            .buttonStyle(.bordered)
            .controlSize(.small)

            Button {
                store.selectedSettingsSection = .advanced
                openWindow(id: "main")
            } label: {
                Image(systemName: "gearshape")
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .help("Open AudioRouter settings")
            .accessibilityLabel("Open AudioRouter settings")
        }
    }

    private var emptyRouteState: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("No route apps available", systemImage: "app.badge")
                .font(.subheadline.weight(.semibold))
            Text("Open Spotify, Apple Music, Chrome, or add apps from the full routing board.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(MenuBarPalette.inset, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private func routeTargetStrip(for source: AudioSource) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack {
                Text("Output")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.secondary)
                Spacer()
                Button {
                    chooseOutput("")
                } label: {
                    Label("Follow System", systemImage: "arrow.triangle.branch")
                }
                .buttonStyle(.plain)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(selectedOutputID.isEmpty ? .teal : .secondary)
            }

            ScrollView(.horizontal) {
                HStack(spacing: 7) {
                    ForEach(routeTargets) { target in
                        MenuTargetChip(
                            target: target,
                            isSelected: selectedOutputID == target.id,
                            action: { chooseOutput(target.id) }
                        )
                    }
                }
                .padding(.vertical, 1)
            }
            .scrollIndicators(.hidden)
            .accessibilityLabel("\(source.appName) output choices")
        }
    }

    private func selectedRouteControls(for source: AudioSource) -> some View {
        HStack(spacing: 8) {
            Button {
                store.setSourceMuted(source: source, isMuted: !source.isMuted)
            } label: {
                Image(systemName: source.isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                    .frame(width: 24, height: 24)
            }
            .buttonStyle(.plain)
            .foregroundStyle(source.isMuted ? .red : .green)
            .background(MenuBarPalette.buttonBackground, in: RoundedRectangle(cornerRadius: 7, style: .continuous))
            .disabled(!store.supportsPerAppMute)
            .help(store.supportsPerAppMute ? "Mute \(source.appName)" : "Per-app mute requires an audio backend")
            .accessibilityLabel(source.isMuted ? "Unmute \(source.appName)" : "Mute \(source.appName)")

            InlineVolumeSlider(
                value: source.volume,
                isEnabled: store.supportsPerAppVolume,
                systemImage: "slider.horizontal.3",
                range: 0...1.5,
                step: 0.01,
                accent: .orange,
                showsStepButtons: true,
                nudgeStep: 0.01,
                accessibilityLabel: "\(source.appName) gain",
                accessibilityHint: store.supportsPerAppVolume ? "Adjust route volume" : "Per-app gain requires an audio backend",
                onChange: { store.setSourceVolume(source: source, volume: $0) }
            )
            .frame(minWidth: 190, maxWidth: .infinity)

            Button {
                store.retrySourceRoute(source)
            } label: {
                Image(systemName: "arrow.clockwise")
                    .frame(width: 24, height: 24)
            }
            .buttonStyle(.plain)
            .background(MenuBarPalette.buttonBackground, in: RoundedRectangle(cornerRadius: 7, style: .continuous))
            .disabled(!canRetry(source))
            .help("Retry \(source.appName) route")
            .accessibilityLabel("Retry \(source.appName) route")

            Button {
                store.testRoute(for: source)
            } label: {
                Image(systemName: "speaker.wave.2.fill")
                    .frame(width: 24, height: 24)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.orange)
            .background(MenuBarPalette.buttonBackground, in: RoundedRectangle(cornerRadius: 7, style: .continuous))
            .help("Test \(source.appName) route")
            .accessibilityLabel("Test \(source.appName) route")
        }
    }

    private var selectedSource: AudioSource? {
        store.audioSources.first { $0.id == selectedSourceID } ?? store.audioSources.first
    }

    private var routeTargets: [MenuRouteTarget] {
        var targets: [MenuRouteTarget] = [
            MenuRouteTarget(
                id: "",
                title: "Follow System",
                subtitle: store.currentOutput?.name ?? "System output",
                systemImage: "arrow.triangle.branch",
                tint: .teal
            )
        ]

        targets += store.outputDevices.map { device in
            MenuRouteTarget(
                id: device.uid,
                title: device.name,
                subtitle: device.isDefault ? "System output" : device.transport.rawValue,
                systemImage: device.transport == .builtIn ? "speaker.wave.2.fill" : "headphones",
                tint: device.isDefault ? .teal : .blue
            )
        }

        targets += store.outputGroups.map { group in
            MenuRouteTarget(
                id: group.routeTargetID,
                title: group.name,
                subtitle: "\(store.outputDevices(for: group).count) speakers",
                systemImage: "speaker.3.fill",
                tint: .orange
            )
        }

        return targets
    }

    private var selectedRouteNote: String? {
        guard let source = selectedSource else { return nil }
        if let diagnostic = store.routeDiagnostic(for: source), !diagnostic.isEmpty {
            return diagnostic
        }
        if selectedOutputID.isEmpty {
            return "\(source.appName) follows the current system output."
        }
        return "\(source.appName) is assigned to \(destinationName(for: selectedOutputID))."
    }

    private func routeSummary(for source: AudioSource) -> String {
        "\(source.appName) -> \(store.routeOutputName(for: source))"
    }

    private func chooseOutput(_ outputID: String) {
        selectedOutputID = outputID
        applySelectedRoute()
    }

    private func applySelectedRoute() {
        guard let source = selectedSource else { return }
        store.prepareAndAssignSourceOutput(source: source, uid: selectedOutputID.isEmpty ? nil : selectedOutputID)
    }

    private func canRetry(_ source: AudioSource) -> Bool {
        let route = store.route(for: source)
        return route.routeMode == .customOutput && route.status != .active
    }

    private func destinationName(for id: String) -> String {
        guard !id.isEmpty else { return "Follow System" }
        if let device = store.outputDevices.first(where: { $0.uid == id }) {
            return device.name
        }
        if let group = store.outputGroups.first(where: { $0.routeTargetID == id }) {
            return group.name
        }
        return "Missing Output"
    }

    private func syncSelectionIfNeeded() {
        if selectedSourceID.isEmpty || !store.audioSources.contains(where: { $0.id == selectedSourceID }) {
            selectedSourceID = store.selectedSourceID ?? store.audioSources.first?.id ?? ""
        }
        if !selectedSourceID.isEmpty {
            store.selectedSourceID = selectedSourceID
        }
        syncOutputIfNeeded()
    }

    private func syncOutputIfNeeded() {
        if selectedOutputID.isEmpty {
            syncOutputFromSelectedSource()
            return
        }
        let outputExists = store.outputDevices.contains { $0.uid == selectedOutputID }
            || store.outputGroups.contains { $0.routeTargetID == selectedOutputID }
        if !outputExists {
            syncOutputFromSelectedSource()
        }
    }

    private func syncOutputFromSelectedSource() {
        guard let source = selectedSource else {
            selectedOutputID = ""
            return
        }
        let route = store.route(for: source)
        selectedOutputID = route.routeMode == .customOutput ? (route.outputDeviceID ?? "") : ""
    }
}

private struct MenuBarPanel<Content: View>: View {
    let tint: Color
    let content: Content

    init(tint: Color, @ViewBuilder content: () -> Content) {
        self.tint = tint
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            content
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background(MenuBarPalette.panel, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(alignment: .leading) {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(tint.opacity(0.86))
                .frame(width: 3)
                .padding(.vertical, 10)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(MenuBarPalette.stroke, lineWidth: 1)
        }
    }
}

private struct MenuTargetChip: View {
    let target: MenuRouteTarget
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: target.systemImage)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(target.tint)
                    .frame(width: 24, height: 24)
                    .background(target.tint.opacity(isSelected ? 0.22 : 0.12), in: RoundedRectangle(cornerRadius: 7, style: .continuous))

                VStack(alignment: .leading, spacing: 1) {
                    Text(target.title)
                        .font(.caption.weight(.semibold))
                        .lineLimit(1)
                    Text(target.subtitle)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(isSelected ? target.tint : .secondary.opacity(0.7))
            }
            .padding(.horizontal, 9)
            .padding(.vertical, 8)
            .frame(width: 174, alignment: .leading)
            .background(
                isSelected ? target.tint.opacity(0.14) : MenuBarPalette.inset,
                in: RoundedRectangle(cornerRadius: 11, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .stroke(isSelected ? target.tint.opacity(0.62) : MenuBarPalette.stroke, lineWidth: isSelected ? 1.2 : 1)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(target.title), \(target.subtitle)")
    }
}

private struct MenuCompactRouteRow: View {
    let source: AudioSource
    let isSelected: Bool
    @ObservedObject var store: AudioRouterStore
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 9) {
                AppSourceIcon(source: source)
                    .frame(width: 26, height: 26)

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 5) {
                        Text(source.appName)
                            .font(.caption.weight(.semibold))
                            .lineLimit(1)
                        Circle()
                            .fill(source.isProducingAudio ? Color.green : Color.orange.opacity(0.85))
                            .frame(width: 6, height: 6)
                            .accessibilityHidden(true)
                    }
                    Text(store.routeOutputName(for: source))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer(minLength: 6)

                Text(source.volume.roundedPercentDescription)
                    .font(.caption2.monospacedDigit().weight(.bold))
                    .foregroundStyle(.orange)
                    .frame(width: 42, alignment: .trailing)

                MenuRouteStatusPill(source: source, store: store)
            }
            .padding(.horizontal, 9)
            .padding(.vertical, 8)
            .background(
                isSelected ? Color.teal.opacity(0.12) : MenuBarPalette.inset,
                in: RoundedRectangle(cornerRadius: 10, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(isSelected ? Color.teal.opacity(0.62) : MenuBarPalette.stroke, lineWidth: isSelected ? 1.2 : 1)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(source.appName), output \(store.routeOutputName(for: source)), \(store.routeStatus(for: source))")
    }
}

private struct MenuRouteStatusPill: View {
    let source: AudioSource
    @ObservedObject var store: AudioRouterStore

    var body: some View {
        StatusLabel(text: store.routeStatus(for: source), status: store.statusStyle(for: source))
    }
}

private struct MenuRouteTarget: Identifiable, Equatable {
    let id: String
    let title: String
    let subtitle: String
    let systemImage: String
    let tint: Color
}

private enum MenuBarPalette {
    static let background = LinearGradient(
        colors: [
            Color(red: 0.045, green: 0.047, blue: 0.052),
            Color(red: 0.028, green: 0.030, blue: 0.035)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    static let panel = Color(red: 0.070, green: 0.073, blue: 0.080).opacity(0.96)
    static let inset = Color.white.opacity(0.045)
    static let buttonBackground = Color.white.opacity(0.075)
    static let stroke = Color.white.opacity(0.095)
}
