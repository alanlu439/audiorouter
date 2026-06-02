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
            routingBackground

            VStack(spacing: 0) {
                header
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                    .padding(.bottom, 12)

                Divider()
                    .opacity(0.28)

                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        if !store.settings.hasCompletedOnboarding {
                            compactOnboardingPrompt
                        }

                        if let note = store.unsupportedNote {
                            SupportNote(note: note) {
                                store.dismissUnsupportedNote()
                            }
                        }

                        if let error = store.lastError {
                            SupportNote(note: error) {
                                store.dismissUnsupportedNote()
                            }
                        }

                        routeBuilder
                        currentRoutes
                        destinationRack
                    }
                    .padding(16)
                }

                Divider()
                    .opacity(0.28)

                footer
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
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
        .onChange(of: selectedSourceID) { _, _ in
            if !selectedSourceID.isEmpty {
                store.selectedSourceID = selectedSourceID
            }
            syncOutputFromSelectedSource()
        }
    }

    private var routingBackground: some View {
        ZStack {
            Color(red: 0.035, green: 0.038, blue: 0.045)
            LinearGradient(
                colors: [
                    Color.teal.opacity(0.16),
                    Color.black.opacity(0.08),
                    Color.blue.opacity(0.06)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
        .ignoresSafeArea()
    }

    private var header: some View {
        HStack(spacing: 11) {
            AudioRouterLogo(size: 36)

            VStack(alignment: .leading, spacing: 2) {
                Text("Routing")
                    .font(.title3.weight(.bold))
                Text(store.routeSummaryText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            StatusLabel(
                text: store.settings.demoMode ? "Demo" : "Live",
                status: store.settings.demoMode ? .demo : .working
            )

            Button {
                store.refresh()
                syncSelectionIfNeeded()
            } label: {
                Image(systemName: "arrow.clockwise")
            }
            .buttonStyle(.borderless)
            .help("Refresh route apps and outputs")
            .accessibilityLabel("Refresh routing")
        }
    }

    private var routeBuilder: some View {
        DockCard {
            SectionHeader(title: "Route Builder", systemImage: "point.3.connected.trianglepath.dotted", trailing: "Source -> Output")

            if store.audioSources.isEmpty {
                emptyRouteState
            } else {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(alignment: .center, spacing: 10) {
                        routePickerColumn(
                            title: "Source",
                            systemImage: "app.fill",
                            tint: .blue
                        ) {
                            Picker("Source", selection: $selectedSourceID) {
                                ForEach(store.audioSources) { source in
                                    Text(source.appName).tag(source.id)
                                }
                            }
                            .labelsHidden()
                            .pickerStyle(.menu)
                            .accessibilityLabel("Routing source")
                        }

                        Image(systemName: "arrow.right")
                            .font(.headline.weight(.bold))
                            .foregroundStyle(.teal)
                            .frame(width: 22)
                            .accessibilityHidden(true)

                        routePickerColumn(
                            title: "Output",
                            systemImage: "speaker.wave.2.fill",
                            tint: .teal
                        ) {
                            outputPicker(selection: $selectedOutputID)
                                .accessibilityLabel("Routing output")
                        }
                    }

                    HStack(spacing: 8) {
                        if let selectedSource {
                            MenuRouteStatusPill(source: selectedSource, store: store)
                        }

                        Spacer(minLength: 8)

                        Button {
                            applySelectedRoute()
                        } label: {
                            Label(builderActionTitle, systemImage: builderActionIcon)
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                        .disabled(selectedSource == nil)
                        .help(builderActionHelp)
                    }

                    if let note = selectedRouteNote {
                        Text(note)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
    }

    private var currentRoutes: some View {
        DockCard {
            SectionHeader(title: "App Routes", systemImage: "arrow.triangle.branch", trailing: "\(store.audioSources.count)")

            if store.audioSources.isEmpty {
                Text("Add route apps from the full dashboard, then assign them here.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                VStack(spacing: 8) {
                    ForEach(store.audioSources) { source in
                        MenuRouteRow(source: source, store: store)
                    }
                }
            }
        }
    }

    private var destinationRack: some View {
        DockCard {
            SectionHeader(title: "Destinations", systemImage: "speaker.2.fill", trailing: "\(store.outputDevices.count)")

            if store.outputDevices.isEmpty {
                Text("No output devices detected.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                VStack(spacing: 8) {
                    ForEach(store.outputDevices) { device in
                        MenuDestinationRow(device: device, store: store)
                    }

                    ForEach(store.outputGroups) { group in
                        MenuOutputGroupRow(group: group, store: store)
                    }
                }
            }
        }
    }

    private var footer: some View {
        HStack(spacing: 10) {
            Button {
                store.selectedSettingsSection = .dashboard
                openWindow(id: "main")
            } label: {
                Label("Full Routing Board", systemImage: "square.grid.2x2")
            }
            .buttonStyle(.bordered)
            .controlSize(.small)

            Spacer()

            Button {
                store.selectedSettingsSection = .dashboard
                openWindow(id: "main")
            } label: {
                Label("Add Apps", systemImage: "app.badge.plus")
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
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
        .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private func routePickerColumn<Content: View>(
        title: String,
        systemImage: String,
        tint: Color,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Label(title, systemImage: systemImage)
                .font(.caption2.weight(.bold))
                .foregroundStyle(tint)
                .textCase(.uppercase)

            content()
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.055), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(tint.opacity(0.18), lineWidth: 1)
        }
    }

    private func outputPicker(selection: Binding<String>) -> some View {
        Picker("Output", selection: selection) {
            Text("Follow System").tag("")
            ForEach(store.outputDevices) { device in
                Text(device.name).tag(device.uid)
            }
            if !store.outputGroups.isEmpty {
                Divider()
                ForEach(store.outputGroups) { group in
                    Text("\(group.name) Group").tag(group.routeTargetID)
                }
            }
        }
        .labelsHidden()
        .pickerStyle(.menu)
    }

    private var compactOnboardingPrompt: some View {
        DockCard {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "point.3.connected.trianglepath.dotted")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.teal)
                    .frame(width: 28, height: 28)
                    .background(.teal.opacity(0.14), in: RoundedRectangle(cornerRadius: 8, style: .continuous))

                VStack(alignment: .leading, spacing: 4) {
                    Text("Set up routing")
                        .font(.subheadline.weight(.semibold))
                    Text("Choose your route apps and outputs before building routes.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 8)

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

    private var selectedSource: AudioSource? {
        store.audioSources.first { $0.id == selectedSourceID } ?? store.audioSources.first
    }

    private var routeMatchesSelection: Bool {
        guard let source = selectedSource else { return false }
        let route = store.route(for: source)
        if selectedOutputID.isEmpty {
            return route.routeMode == .followSystemOutput
        }
        return route.routeMode == .customOutput && route.outputDeviceID == selectedOutputID
    }

    private var builderActionTitle: String {
        guard let source = selectedSource else { return "Route" }
        let route = store.route(for: source)
        if selectedOutputID.isEmpty {
            return route.routeMode == .followSystemOutput ? "Following System" : "Follow System"
        }
        if routeMatchesSelection {
            return route.status == .active ? "Route Applied" : "Retry Route"
        }
        return "Apply Route"
    }

    private var builderActionIcon: String {
        if selectedOutputID.isEmpty { return "arrow.triangle.branch" }
        return routeMatchesSelection ? "arrow.clockwise" : "cable.connector"
    }

    private var builderActionHelp: String {
        guard let source = selectedSource else { return "Choose a source first." }
        if selectedOutputID.isEmpty {
            return "\(source.appName) will follow the current system output."
        }
        return "Assign \(source.appName) to \(destinationName(for: selectedOutputID))."
    }

    private var selectedRouteNote: String? {
        guard let source = selectedSource else { return nil }
        if selectedOutputID.isEmpty {
            return "\(source.appName) will move with the system output device."
        }
        if let diagnostic = store.routeDiagnostic(for: source), routeMatchesSelection {
            return diagnostic
        }
        return "This saves \(source.appName) -> \(destinationName(for: selectedOutputID)) and starts live routing when the backend can support it."
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

    private func applySelectedRoute() {
        guard let source = selectedSource else { return }
        store.prepareAndAssignSourceOutput(source: source, uid: selectedOutputID.isEmpty ? nil : selectedOutputID)
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

private struct MenuRouteRow: View {
    let source: AudioSource
    @ObservedObject var store: AudioRouterStore

    private var isSelected: Bool {
        store.selectedSourceID == source.id
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(spacing: 9) {
                AppSourceIcon(source: source)
                    .frame(width: 26, height: 26)

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 5) {
                        Text(source.appName)
                            .font(.subheadline.weight(.semibold))
                            .lineLimit(1)
                        Circle()
                            .fill(source.isProducingAudio ? Color.green : Color.orange.opacity(0.85))
                            .frame(width: 6, height: 6)
                            .accessibilityHidden(true)
                    }
                    Text(source.bundleIdentifier ?? "No bundle id")
                        .font(.caption2.monospaced())
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }

                Spacer(minLength: 8)

                MenuRouteStatusPill(source: source, store: store)
            }

            HStack(spacing: 8) {
                Image(systemName: "arrow.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.teal)
                    .frame(width: 18)

                outputPicker

                if shouldShowRetry {
                    Button {
                        store.retrySourceRoute(source)
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .buttonStyle(.borderless)
                    .help("Retry this route")
                    .accessibilityLabel("Retry \(source.appName) route")
                }

                Button {
                    store.resetSourceToSystemOutput(source)
                } label: {
                    Image(systemName: "arrow.triangle.branch")
                }
                .buttonStyle(.borderless)
                .disabled(source.followsSystemOutput)
                .help("Follow system output")
                .accessibilityLabel("Set \(source.appName) to follow system output")
            }
        }
        .padding(10)
        .background(
            (isSelected ? Color.teal.opacity(0.12) : Color.white.opacity(0.052)),
            in: RoundedRectangle(cornerRadius: 10, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(
                    isSelected ? Color.teal.opacity(0.65) : store.statusStyle(for: source).foreground.opacity(0.16),
                    lineWidth: isSelected ? 1.4 : 1
                )
        }
        .contentShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .onTapGesture {
            store.selectedSourceID = source.id
        }
        .help(store.routeDiagnostic(for: source) ?? "Route is ready.")
        .accessibilityElement(children: .contain)
        .accessibilityLabel("\(source.appName), output \(store.routeOutputName(for: source)), \(store.routeStatus(for: source))")
    }

    private var outputPicker: some View {
        Picker("Output", selection: outputSelection) {
            Text("Follow System").tag("")
            ForEach(store.outputDevices) { device in
                Text(device.name).tag(device.uid)
            }
            if !store.outputGroups.isEmpty {
                Divider()
                ForEach(store.outputGroups) { group in
                    Text("\(group.name) Group").tag(group.routeTargetID)
                }
            }
        }
        .labelsHidden()
        .pickerStyle(.menu)
        .controlSize(.small)
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityLabel("\(source.appName) output")
        .accessibilityValue(store.routeOutputName(for: source))
    }

    private var outputSelection: Binding<String> {
        Binding(
            get: {
                let route = store.route(for: source)
                return route.routeMode == .customOutput ? (route.outputDeviceID ?? "") : ""
            },
            set: { value in
                store.prepareAndAssignSourceOutput(source: source, uid: value.isEmpty ? nil : value)
            }
        )
    }

    private var shouldShowRetry: Bool {
        let route = store.route(for: source)
        return route.routeMode == .customOutput && route.status != .active
    }
}

private struct MenuRouteStatusPill: View {
    let source: AudioSource
    @ObservedObject var store: AudioRouterStore

    var body: some View {
        StatusLabel(text: store.routeStatus(for: source), status: store.statusStyle(for: source))
    }
}

private struct MenuDestinationRow: View {
    let device: AudioDevice
    @ObservedObject var store: AudioRouterStore

    var body: some View {
        HStack(spacing: 10) {
            DeviceIcon(device: device)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(device.name)
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)
                    if device.isDefault {
                        StatusBadge(text: "System", isActive: true)
                    }
                }

                Text(assignedSummary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            Text("\(assignedSources.count)")
                .font(.caption.monospacedDigit().weight(.bold))
                .foregroundStyle(.teal)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(.teal.opacity(0.12), in: Capsule())
                .accessibilityLabel("\(assignedSources.count) assigned apps")
        }
        .padding(10)
        .background(Color.white.opacity(0.045), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(device.name), \(assignedSummary)")
    }

    private var assignedSources: [AudioSource] {
        store.routedSources(to: device)
    }

    private var assignedSummary: String {
        guard !assignedSources.isEmpty else {
            return device.isAlive ? "No custom routes" : "Device missing"
        }
        return assignedSources.map(\.appName).joined(separator: ", ")
    }
}

private struct MenuOutputGroupRow: View {
    let group: OutputDeviceGroup
    @ObservedObject var store: AudioRouterStore

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "speaker.3.fill")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.orange)
                .frame(width: 28, height: 28)
                .background(.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 8, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text(group.name)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                Text(assignedSummary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            StatusLabel(text: "Backend", status: .requiresBackend)
        }
        .padding(10)
        .background(Color.white.opacity(0.045), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(group.name) group, requires audio backend")
    }

    private var assignedSources: [AudioSource] {
        store.audioSources.filter { source in
            store.route(for: source).outputDeviceID == group.routeTargetID
        }
    }

    private var assignedSummary: String {
        guard !assignedSources.isEmpty else { return "No assigned apps" }
        return assignedSources.map(\.appName).joined(separator: ", ")
    }
}
