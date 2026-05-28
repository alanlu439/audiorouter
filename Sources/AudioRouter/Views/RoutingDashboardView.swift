import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct RoutingDashboardView: View {
    @ObservedObject var store: AudioRouterStore

    var body: some View {
        StudioConsoleFrame {
            VStack(alignment: .leading, spacing: 14) {
                consoleHeader
                consoleStatusRail
                if !store.settings.hasCompletedOnboarding {
                    StudioOnboardingCard(store: store)
                }

                if let note = store.unsupportedNote {
                    SupportNote(note: note) {
                        store.dismissUnsupportedNote()
                    }
                }

                consoleSurface
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var consoleHeader: some View {
        HStack(spacing: 14) {
            AudioRouterLogo(size: 44)

            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 10) {
                    Text("Live Routing Console")
                        .font(.title2.weight(.semibold))
                    StudioLEDLabel(text: store.backendReadinessTitle, status: store.backendReadinessState.visualStatus)
                }

                HStack(spacing: 8) {
                    Text("AudioRouter")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Text("MAIN OUT")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(StudioPalette.amber)
                    Text(store.currentOutput?.name ?? "No system output")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            Button {
                store.refresh()
            } label: {
                Image(systemName: "arrow.clockwise")
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
            .help("Refresh")
            .accessibilityLabel("Refresh AudioRouter")
            .accessibilityHint("Reloads audio devices, apps, routes, and meters")

            Picker("Mode", selection: demoBinding) {
                Text("Live").tag(false)
                Text("Demo").tag(true)
            }
            .pickerStyle(.segmented)
            .frame(width: 154)
            .accessibilityLabel("AudioRouter mode")
            .accessibilityValue(store.settings.demoMode ? "Demo Mode" : "Live Mode")
        }
        .padding(14)
        .background(StudioPalette.header, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(StudioPalette.stroke, lineWidth: 1)
        }
    }

    private var consoleStatusRail: some View {
        HStack(spacing: 8) {
            StudioMetricTile(title: "Sources", value: "\(store.audioSources.count)", systemImage: "app.connected.to.app.below.fill", tint: StudioPalette.blue)
            StudioMetricTile(title: "Outputs", value: "\(store.outputDevices.count)", systemImage: "speaker.wave.2.fill", tint: StudioPalette.teal)
            StudioMetricTile(title: "Live", value: "\(store.activeLiveRouteCount)", systemImage: "waveform.circle.fill", tint: StudioPalette.green)
            StudioMetricTile(title: "Saved", value: "\(store.savedCustomRouteCount)", systemImage: "tray.and.arrow.down.fill", tint: StudioPalette.amber)
            StudioBackendStrip(store: store)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var consoleSurface: some View {
        ScrollView(.horizontal) {
            HStack(alignment: .top, spacing: 14) {
                StudioPatchBayPanel(store: store)
                    .frame(minWidth: 700, idealWidth: 760, maxWidth: .infinity, alignment: .top)
                StudioOutputRackPanel(store: store)
                    .frame(minWidth: 300, idealWidth: 328, maxWidth: 360, alignment: .top)
            }
            .containerRelativeFrame(.horizontal, alignment: .topLeading) { length, _ in
                max(length, 1_014)
            }
        }
        .scrollIndicators(.visible)
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }

    private var demoBinding: Binding<Bool> {
        Binding(
            get: { store.settings.demoMode },
            set: { value in
                store.settings.demoMode = value
                store.refresh()
            }
        )
    }
}

private enum StudioPalette {
    static let console = Color(red: 0.045, green: 0.047, blue: 0.052)
    static let header = Color(red: 0.075, green: 0.079, blue: 0.088)
    static let panel = Color(red: 0.060, green: 0.063, blue: 0.070)
    static let strip = Color(red: 0.086, green: 0.089, blue: 0.096)
    static let inset = Color(red: 0.026, green: 0.028, blue: 0.032)
    static let stroke = Color.white.opacity(0.085)
    static let strongStroke = Color.white.opacity(0.15)
    static let green = Color(red: 0.35, green: 0.95, blue: 0.55)
    static let amber = Color(red: 1.0, green: 0.70, blue: 0.28)
    static let teal = Color(red: 0.24, green: 0.86, blue: 0.80)
    static let blue = Color(red: 0.43, green: 0.65, blue: 1.0)
    static let red = Color(red: 1.0, green: 0.32, blue: 0.32)
}

private struct StudioConsoleFrame<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding(14)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(StudioPalette.console, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(alignment: .top) {
                Rectangle()
                    .fill(StudioPalette.strongStroke)
                    .frame(height: 1)
                    .padding(.horizontal, 12)
            }
            .overlay {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(StudioPalette.strongStroke, lineWidth: 1)
            }
    }
}

private struct StudioMetricTile: View {
    let title: String
    let value: String
    let systemImage: String
    let tint: Color

    var body: some View {
        HStack(spacing: 9) {
            StudioLED(color: tint)

            VStack(alignment: .leading, spacing: 1) {
                Text(value)
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(.primary)
                    .monospacedDigit()
                Text(title.uppercased())
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundStyle(.secondary)
            }

            Image(systemName: systemImage)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(tint.opacity(0.85))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(StudioPalette.inset, in: RoundedRectangle(cornerRadius: 7, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .stroke(StudioPalette.stroke, lineWidth: 1)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title), \(value)")
    }
}

private struct StudioBackendStrip: View {
    @ObservedObject var store: AudioRouterStore

    var body: some View {
        HStack(spacing: 9) {
            StudioLED(color: store.backendReadinessState.visualStatus.foreground)
            Text("ENGINE")
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundStyle(.secondary)
            Text(store.backendReadinessDetail)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 9)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(StudioPalette.inset, in: RoundedRectangle(cornerRadius: 7, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .stroke(StudioPalette.stroke, lineWidth: 1)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Engine, \(store.backendReadinessDetail)")
    }
}

private struct StudioLED: View {
    let color: Color

    var body: some View {
        Circle()
            .fill(color)
            .frame(width: 8, height: 8)
            .shadow(color: color.opacity(0.65), radius: 4)
            .accessibilityHidden(true)
    }
}

private struct StudioLEDLabel: View {
    let text: String
    let status: RouteVisualStatus

    var body: some View {
        HStack(spacing: 6) {
            StudioLED(color: status.foreground)
            Text(text.uppercased())
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundStyle(status.foreground)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(StudioPalette.inset, in: Capsule())
        .overlay {
            Capsule()
                .stroke(status.foreground.opacity(0.30), lineWidth: 1)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(text) status")
    }
}

private struct StudioOnboardingCard: View {
    @ObservedObject var store: AudioRouterStore

    var body: some View {
        StudioPanel(title: "Quick Start", systemImage: "wand.and.stars", trailing: "Visual setup") {
            VStack(alignment: .leading, spacing: 12) {
                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .top, spacing: 10) {
                        OnboardingStep(number: "1", title: "Add source apps", detail: "Keep Spotify, Music, Chrome, or add any app from Applications.")
                        OnboardingArrow()
                        OnboardingStep(number: "2", title: "Pick an output", detail: "Choose Follow System or a connected speaker from the route row.")
                        OnboardingArrow()
                        OnboardingStep(number: "3", title: "Approve macOS", detail: "When macOS asks, you must approve System Audio Recording yourself.")
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        OnboardingStep(number: "1", title: "Add source apps", detail: "Keep Spotify, Music, Chrome, or add any app from Applications.")
                        OnboardingStep(number: "2", title: "Pick an output", detail: "Choose Follow System or a connected speaker from the route row.")
                        OnboardingStep(number: "3", title: "Approve macOS", detail: "When macOS asks, you must approve System Audio Recording yourself.")
                    }
                }

                HStack(spacing: 8) {
                    Button {
                        store.probeProcessTapPermission()
                    } label: {
                        Label("Check Permission", systemImage: "checkmark.shield")
                    }
                    .accessibilityHint("Starts a safe process-tap probe so macOS can show its audio capture prompt if needed")

                    Button {
                        store.openSystemAudioPermissionSettings()
                    } label: {
                        Label("Open Privacy Settings", systemImage: "switch.2")
                    }
                    .accessibilityHint("Opens System Settings so you can approve AudioRouter manually")

                    Spacer()

                    Button {
                        store.completeOnboarding()
                    } label: {
                        Label("Got It", systemImage: "checkmark")
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(StudioPalette.teal)
                    .accessibilityHint("Hides the quick start card")
                }
                .controlSize(.small)
            }
        }
    }
}

private struct OnboardingStep: View {
    let number: String
    let title: String
    let detail: String

    var body: some View {
        HStack(alignment: .top, spacing: 9) {
            Text(number)
                .font(.system(size: 13, weight: .heavy, design: .monospaced))
                .foregroundStyle(.black)
                .frame(width: 24, height: 24)
                .background(StudioPalette.teal, in: Circle())

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.caption.weight(.bold))
                Text(detail)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Step \(number), \(title), \(detail)")
    }
}

private struct OnboardingArrow: View {
    var body: some View {
        Image(systemName: "arrow.right")
            .font(.system(size: 12, weight: .heavy))
            .foregroundStyle(StudioPalette.amber)
            .padding(.top, 6)
            .accessibilityHidden(true)
    }
}

private struct StudioPanel<Content: View>: View {
    let title: String
    let systemImage: String
    let trailing: String?
    let content: Content

    init(
        title: String,
        systemImage: String,
        trailing: String? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.systemImage = systemImage
        self.trailing = trailing
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 9) {
                Image(systemName: systemImage)
                    .foregroundStyle(StudioPalette.amber)
                Text(title.uppercased())
                    .font(.system(size: 12, weight: .heavy, design: .monospaced))
                    .tracking(1.2)
                Spacer()
                if let trailing {
                    Text(trailing)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(StudioPalette.header)

            Rectangle()
                .fill(StudioPalette.stroke)
                .frame(height: 1)

            content
                .padding(10)
        }
        .background(StudioPalette.panel, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(StudioPalette.strongStroke, lineWidth: 1)
        }
    }
}

private struct StudioPatchBayPanel: View {
    @ObservedObject var store: AudioRouterStore
    @State private var isAddingApp = false

    var body: some View {
        StudioPanel(
            title: "Patch Bay",
            systemImage: "point.3.connected.trianglepath.dotted",
            trailing: store.routeSummaryText
        ) {
            VStack(spacing: 9) {
                StudioSectionMarker(
                    title: "Controls",
                    detail: "\(store.routeAppDisplayNames.count) configured inputs",
                    tint: StudioPalette.blue
                )
                StudioPatchBayActions(store: store) {
                    isAddingApp = true
                }
                StudioSectionMarker(
                    title: "Route Builder",
                    detail: "Choose one input app and one output destination",
                    tint: StudioPalette.teal
                )
                StudioRouteBuilder(store: store)

                StudioSectionMarker(
                    title: "Input Apps",
                    detail: "Drag rows or use arrows to customize order",
                    tint: StudioPalette.blue
                )
                StudioPatchBayHeader()

                ForEach(store.audioSources) { source in
                    StudioChannelStrip(source: source, store: store)
                }

                if let selectedSource {
                    Divider()
                        .overlay(StudioPalette.stroke)
                        .padding(.vertical, 4)
                    StudioSectionMarker(
                        title: "Selected Route",
                        detail: selectedSource.appName,
                        tint: store.statusStyle(for: selectedSource).foreground
                    )
                    StudioRouteInspector(source: selectedSource, store: store)
                }
            }
        }
        .sheet(isPresented: $isAddingApp) {
            AddRouteAppSheet(store: store)
        }
    }

    private var selectedSource: AudioSource? {
        store.selectedSourceID.flatMap { id in store.audioSources.first { $0.id == id } }
    }
}

private struct StudioPatchBayActions: View {
    @ObservedObject var store: AudioRouterStore
    let onAddApp: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Label("\(store.routeAppDisplayNames.count) route app\(store.routeAppDisplayNames.count == 1 ? "" : "s")", systemImage: "app.badge")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            Spacer()

            Button {
                store.refresh()
            } label: {
                Label("Refresh", systemImage: "arrow.clockwise")
            }
            .accessibilityHint("Reloads running apps and audio devices")

            if store.hasHiddenDefaultRouteApps {
                Button {
                    store.restoreDefaultRouteApps()
                } label: {
                    Label("Restore Defaults", systemImage: "arrow.uturn.backward")
                }
                .accessibilityHint("Restores Spotify, Apple Music, and Chrome to the dashboard")
            }

            Button {
                store.resetRouteAppOrder()
            } label: {
                Label("Reset Order", systemImage: "arrow.up.arrow.down")
            }
            .accessibilityHint("Restores the default app order")

            Button {
                onAddApp()
            } label: {
                Label("Add App", systemImage: "plus.app.fill")
            }
            .buttonStyle(.borderedProminent)
            .tint(StudioPalette.teal)
            .accessibilityHint("Opens the app picker so you can add another routable source")
        }
        .controlSize(.small)
        .padding(.horizontal, 11)
        .padding(.vertical, 8)
        .background(StudioPalette.inset.opacity(0.70), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .stroke(StudioPalette.stroke, lineWidth: 1)
        }
    }
}

private struct StudioSectionMarker: View {
    let title: String
    let detail: String
    let tint: Color

    var body: some View {
        HStack(spacing: 8) {
            Capsule()
                .fill(tint)
                .frame(width: 4, height: 16)
                .shadow(color: tint.opacity(0.45), radius: 3)
            Text(title.uppercased())
                .font(.system(size: 10, weight: .heavy, design: .monospaced))
                .foregroundStyle(.primary.opacity(0.9))
            Rectangle()
                .fill(StudioPalette.stroke)
                .frame(height: 1)
            Text(detail)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .padding(.horizontal, 11)
        .padding(.top, 3)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title), \(detail)")
    }
}

private struct StudioRouteBuilder: View {
    @ObservedObject var store: AudioRouterStore
    @State private var selectedSourceID = ""
    @State private var selectedOutputID = ""

    private var selectedSource: AudioSource? {
        let id = selectedSourceID.isEmpty ? (store.selectedSourceID ?? store.audioSources.first?.id ?? "") : selectedSourceID
        return store.audioSources.first { $0.id == id }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(alignment: .top, spacing: 10) {
                inputEndpoint
                    .frame(minWidth: 190, maxWidth: .infinity, alignment: .topLeading)
                routeGlyph
                outputEndpoint
                    .frame(minWidth: 190, maxWidth: .infinity, alignment: .topLeading)
                routeActionStack
                    .frame(width: 128, alignment: .top)
            }

            HStack(spacing: 8) {
                Image(systemName: "hand.draw")
                    .foregroundStyle(StudioPalette.amber)
                Text("You can also drag a source row onto an output card, or use each source row's output menu.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.horizontal, 11)
        .padding(.vertical, 9)
        .background(StudioPalette.inset.opacity(0.72), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .stroke(StudioPalette.stroke, lineWidth: 1)
        }
        .onChange(of: store.audioSources) { _, _ in
            if selectedSource == nil {
                selectedSourceID = store.selectedSourceID ?? store.audioSources.first?.id ?? ""
            }
        }
        .onAppear {
            selectedSourceID = store.selectedSourceID ?? store.audioSources.first?.id ?? ""
            selectedOutputID = selectedSource.flatMap { $0.assignedOutputDeviceID } ?? ""
        }
    }

    private var inputEndpoint: some View {
        StudioRouteEndpoint(
            title: "Input",
            subtitle: selectedSource?.appName ?? "Choose app",
            systemImage: "app.fill",
            tint: StudioPalette.blue
        ) {
            Picker("Input App", selection: sourceSelection) {
                ForEach(store.audioSources) { source in
                    Text(source.appName).tag(source.id)
                }
            }
            .labelsHidden()
            .pickerStyle(.menu)
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityHint("Choose the app you want to route")
        }
    }

    private var outputEndpoint: some View {
        StudioRouteEndpoint(
            title: "Output",
            subtitle: outputSubtitle,
            systemImage: selectedOutputID.isEmpty ? "arrow.triangle.branch" : "speaker.wave.2.fill",
            tint: StudioPalette.teal
        ) {
            Picker("Output Device", selection: $selectedOutputID) {
                Text("Follow System").tag("")
                ForEach(store.outputDevices) { device in
                    Text(device.name).tag(device.uid)
                }
                if !store.outputGroups.isEmpty {
                    Divider()
                    ForEach(store.outputGroups) { group in
                        Text("\(group.name) (Group)").tag(group.routeTargetID)
                    }
                }
            }
            .labelsHidden()
            .pickerStyle(.menu)
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityHint("Choose the output device for the selected app")
        }
    }

    private var routeGlyph: some View {
        VStack(spacing: 5) {
            Text("ROUTE")
                .font(.system(size: 8, weight: .heavy, design: .monospaced))
                .foregroundStyle(.secondary)
            Image(systemName: "arrow.right")
                .font(.system(size: 16, weight: .heavy))
                .foregroundStyle(StudioPalette.amber)
            StudioLED(color: selectedOutputID.isEmpty ? StudioPalette.blue : StudioPalette.teal)
        }
        .padding(.top, 10)
        .frame(width: 54)
        .accessibilityHidden(true)
    }

    private var routeActionStack: some View {
        VStack(spacing: 8) {
            Button {
                applyRoute()
            } label: {
                Label(selectedOutputID.isEmpty ? "Follow System" : "Patch Route", systemImage: selectedOutputID.isEmpty ? "arrow.triangle.branch" : "point.3.connected.trianglepath.dotted")
            }
            .buttonStyle(.borderedProminent)
            .tint(selectedOutputID.isEmpty ? StudioPalette.blue : StudioPalette.teal)
            .disabled(selectedSource == nil)
            .accessibilityHint("Applies the selected app to output route")

            Text("INPUT -> OUTPUT")
                .font(.system(size: 8, weight: .heavy, design: .monospaced))
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
    }

    private var sourceSelection: Binding<String> {
        Binding(
            get: { selectedSourceID.isEmpty ? (store.selectedSourceID ?? store.audioSources.first?.id ?? "") : selectedSourceID },
            set: { value in
                selectedSourceID = value
                store.selectedSourceID = value
                selectedOutputID = selectedSource.flatMap { $0.assignedOutputDeviceID } ?? ""
            }
        )
    }

    private func applyRoute() {
        guard let selectedSource else { return }
        store.assignSourceOutput(source: selectedSource, uid: selectedOutputID.isEmpty ? nil : selectedOutputID)
    }

    private var outputSubtitle: String {
        if selectedOutputID.isEmpty {
            return "Follow System"
        }
        if let device = store.outputDevices.first(where: { $0.uid == selectedOutputID }) {
            return device.name
        }
        if let group = store.outputGroups.first(where: { $0.routeTargetID == selectedOutputID }) {
            return group.name
        }
        return "Missing Output"
    }
}

private struct StudioRouteEndpoint<Content: View>: View {
    let title: String
    let subtitle: String
    let systemImage: String
    let tint: Color
    let content: Content

    init(
        title: String,
        subtitle: String,
        systemImage: String,
        tint: Color,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.subtitle = subtitle
        self.systemImage = systemImage
        self.tint = tint
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: systemImage)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(tint)
                    .frame(width: 22, height: 22)
                    .background(tint.opacity(0.13), in: RoundedRectangle(cornerRadius: 5, style: .continuous))

                VStack(alignment: .leading, spacing: 1) {
                    Text(title.uppercased())
                        .font(.system(size: 9, weight: .heavy, design: .monospaced))
                        .foregroundStyle(.secondary)
                    Text(subtitle)
                        .font(.caption.weight(.semibold))
                        .lineLimit(1)
                }
            }

            content
        }
        .padding(10)
        .background(StudioPalette.strip.opacity(0.72), in: RoundedRectangle(cornerRadius: 7, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .stroke(tint.opacity(0.22), lineWidth: 1)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("\(title), \(subtitle)")
    }
}

private struct AddRouteAppSheet: View {
    @ObservedObject var store: AudioRouterStore
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""

    private var filteredCandidates: [AudioSource] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return store.availableAppCandidates }
        return store.availableAppCandidates.filter { source in
            source.appName.localizedCaseInsensitiveContains(query)
                || (source.bundleIdentifier?.localizedCaseInsensitiveContains(query) ?? false)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                Image(systemName: "plus.app.fill")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(StudioPalette.teal)

                VStack(alignment: .leading, spacing: 3) {
                    Text("Add Route App")
                        .font(.title3.weight(.semibold))
                    Text("Choose any app you want to appear as a routable source.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .accessibilityLabel("Close add app sheet")
            }

            TextField("Search running apps", text: $searchText)
                .textFieldStyle(.roundedBorder)
                .accessibilityLabel("Search running apps")

            HStack(spacing: 8) {
                Button {
                    store.refreshAppCandidates()
                } label: {
                    Label("Refresh Running Apps", systemImage: "arrow.clockwise")
                }
                .accessibilityHint("Reloads the list of running apps")

                Button {
                    chooseAppBundle()
                } label: {
                    Label("Browse Applications", systemImage: "folder")
                }
                .accessibilityHint("Choose an installed app from disk")

                if store.hasHiddenDefaultRouteApps {
                    Button {
                        store.restoreDefaultRouteApps()
                    } label: {
                        Label("Restore Defaults", systemImage: "arrow.uturn.backward")
                    }
                    .accessibilityHint("Restores Spotify, Apple Music, and Chrome")
                }

                Spacer()
            }
            .controlSize(.small)

            Divider()
                .overlay(StudioPalette.stroke)

            ScrollView {
                LazyVStack(spacing: 8) {
                    if filteredCandidates.isEmpty {
                        VStack(spacing: 8) {
                            Image(systemName: "app.dashed")
                                .font(.system(size: 28))
                                .foregroundStyle(.secondary)
                            Text("No running apps available to add")
                                .font(.subheadline.weight(.semibold))
                            Text("Open the app you want to route, click Refresh, or browse for an installed .app.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 28)
                    } else {
                        ForEach(filteredCandidates) { source in
                            AddRouteAppRow(source: source, store: store)
                        }
                    }
                }
            }
            .frame(minHeight: 260)
        }
        .padding(18)
        .frame(width: 520)
        .frame(minHeight: 430)
        .background(StudioPalette.console)
        .preferredColorScheme(.dark)
        .onAppear {
            store.refreshAppCandidates()
        }
    }

    private func chooseAppBundle() {
        let panel = NSOpenPanel()
        panel.title = "Choose an app to route"
        panel.prompt = "Add App"
        panel.directoryURL = URL(fileURLWithPath: "/Applications", isDirectory: true)
        panel.allowedContentTypes = [.applicationBundle]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        guard panel.runModal() == .OK,
              let url = panel.url else {
            return
        }
        store.addRouteApp(bundleURL: url)
    }
}

private struct AddRouteAppRow: View {
    let source: AudioSource
    @ObservedObject var store: AudioRouterStore

    var body: some View {
        HStack(spacing: 10) {
            AppSourceIcon(source: source)

            VStack(alignment: .leading, spacing: 2) {
                Text(source.appName)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                Text(source.bundleIdentifier ?? "No bundle identifier")
                    .font(.caption2.monospaced())
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            Button {
                store.addRouteApp(source: source)
            } label: {
                Label("Add", systemImage: "plus")
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .disabled(source.bundleIdentifier == nil)
            .help(source.bundleIdentifier == nil ? "AudioRouter needs a bundle identifier to save this app." : "Add this app to the routing dashboard.")
        }
        .padding(10)
        .background(StudioPalette.strip.opacity(0.78), in: RoundedRectangle(cornerRadius: 7, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .stroke(StudioPalette.stroke, lineWidth: 1)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("\(source.appName), \(source.bundleIdentifier ?? "no bundle identifier")")
    }
}

private struct StudioPatchBayHeader: View {
    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 12) {
                Text("ORDER")
                    .frame(width: 48, alignment: .leading)
                Text("INPUT APP")
                    .frame(minWidth: 134, maxWidth: 200, alignment: .leading)
                Text("METER")
                    .frame(width: 88, alignment: .leading)
                Text("OUTPUT")
                    .frame(minWidth: 168, maxWidth: .infinity, alignment: .leading)
                Text("GAIN")
                    .frame(width: 148, alignment: .leading)
            }

            HStack(spacing: 8) {
                Text("ORDER")
                    .frame(width: 48, alignment: .leading)
                Text("INPUT APP")
                Spacer()
                Text("OUTPUT")
            }
        }
        .font(.system(size: 9, weight: .bold, design: .monospaced))
        .foregroundStyle(.secondary)
        .padding(.horizontal, 11)
        .padding(.vertical, 5)
    }
}

private struct StudioChannelStrip: View {
    let source: AudioSource
    @ObservedObject var store: AudioRouterStore
    @State private var isDropTargeted = false

    private var isSelected: Bool {
        store.selectedSourceID == source.id
    }

    private var visualStatus: RouteVisualStatus {
        store.statusStyle(for: source)
    }

    var body: some View {
        fullChannelRow
            .padding(.horizontal, 11)
            .padding(.vertical, 10)
            .background(channelBackground, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
            .overlay(alignment: .leading) {
                Rectangle()
                    .fill(visualStatus.foreground)
                    .frame(width: 3)
                    .clipShape(RoundedRectangle(cornerRadius: 2, style: .continuous))
            }
            .overlay {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .stroke(rowStrokeColor, lineWidth: rowStrokeWidth)
            }
            .overlay(alignment: .topTrailing) {
                if isDropTargeted {
                    Text("DROP TO REORDER")
                        .font(.system(size: 8, weight: .heavy, design: .monospaced))
                        .foregroundStyle(StudioPalette.amber)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(StudioPalette.amber.opacity(0.14), in: Capsule())
                        .padding(6)
                }
            }
            .contentShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            .onTapGesture {
                store.selectedSourceID = source.id
            }
            .contextMenu {
                Button("Follow System Output") {
                    store.resetSourceToSystemOutput(source)
                }
                Button(source.isMuted ? "Unmute" : "Mute") {
                    store.setSourceMuted(source: source, isMuted: !source.isMuted)
                }
                Divider()
                Button("Move Up") {
                    store.moveRouteApp(source, offset: -1)
                }
                .disabled(!store.canMoveRouteApp(source, offset: -1))
                Button("Move Down") {
                    store.moveRouteApp(source, offset: 1)
                }
                .disabled(!store.canMoveRouteApp(source, offset: 1))
                if store.isUserAddedRouteApp(source) || store.isDefaultRouteApp(source) {
                    Divider()
                    Button(store.isDefaultRouteApp(source) ? "Hide App from Dashboard" : "Remove App from Dashboard", role: .destructive) {
                        store.removeRouteApp(source)
                    }
                }
            }
        .draggable(source.id) {
            StudioSourceDragPreview(source: source, outputName: store.routeOutputName(for: source))
        }
        .dropDestination(for: String.self) { sourceIDs, _ in
            guard let draggedSourceID = sourceIDs.first else { return false }
            return store.reorderRouteApp(draggedSourceID: draggedSourceID, targetSourceID: source.id)
        } isTargeted: { isTargeted in
            isDropTargeted = isTargeted
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("\(source.appName), output \(store.routeOutputName(for: source)), \(store.routeStatus(for: source))")
        .accessibilityHint("Selects this source for route controls. Drag this row onto another input app to reorder it, or drag it onto an output device to route it.")
    }

    private var fullChannelRow: some View {
        HStack(spacing: 12) {
            orderControls
                .frame(width: 48, alignment: .leading)

            channelIdentity
                .frame(minWidth: 134, maxWidth: 200, alignment: .leading)

            StudioSegmentMeter(
                level: store.sourceMeters[source.id] ?? 0,
                segmentCount: 12,
                tint: source.isProducingAudio ? StudioPalette.green : StudioPalette.teal
            )
            .frame(width: 88, alignment: .leading)

            routeAssignment
                .frame(minWidth: 168, maxWidth: .infinity, alignment: .leading)

            gainControls
                .frame(width: 148, alignment: .leading)
        }
    }

    private var orderControls: some View {
        HStack(spacing: 2) {
            Button {
                store.moveRouteApp(source, offset: -1)
            } label: {
                Image(systemName: "chevron.up")
            }
            .buttonStyle(.borderless)
            .disabled(!store.canMoveRouteApp(source, offset: -1))
            .help("Move \(source.appName) up")
            .accessibilityLabel("Move \(source.appName) up")

            Button {
                store.moveRouteApp(source, offset: 1)
            } label: {
                Image(systemName: "chevron.down")
            }
            .buttonStyle(.borderless)
            .disabled(!store.canMoveRouteApp(source, offset: 1))
            .help("Move \(source.appName) down")
            .accessibilityLabel("Move \(source.appName) down")
        }
        .font(.system(size: 10, weight: .bold))
    }

    private var channelIdentity: some View {
        HStack(spacing: 10) {
            AppSourceIcon(source: source)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(source.appName)
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)
                    StudioLED(color: source.isProducingAudio ? StudioPalette.green : StudioPalette.amber.opacity(0.75))
                }
                Text(source.debugLabel)
                    .font(.caption2.monospaced())
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
            }
        }
    }

    private var routeAssignment: some View {
        HStack(spacing: 10) {
            StudioRouteCable(status: visualStatus, followsSystem: source.followsSystemOutput)
                .frame(width: 68)

            Picker("Output", selection: outputSelection) {
                Text("Follow System").tag("")
                ForEach(store.outputDevices) { device in
                    Text(device.name).tag(device.uid)
                }
                if !store.outputGroups.isEmpty {
                    Divider()
                    ForEach(store.outputGroups) { group in
                        Text("\(group.name) (Group)").tag(group.routeTargetID)
                    }
                }
            }
            .labelsHidden()
            .pickerStyle(.menu)
            .controlSize(.small)
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityLabel("\(source.appName) output")
            .accessibilityValue(store.routeOutputName(for: source))
            .accessibilityHint("Chooses the output device for this source")

            StudioLEDLabel(text: store.routeStatus(for: source), status: visualStatus)
        }
    }

    private var gainControls: some View {
        HStack(spacing: 8) {
            Button {
                store.setSourceMuted(source: source, isMuted: !source.isMuted)
            } label: {
                Image(systemName: source.isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
            }
            .buttonStyle(.borderless)
            .foregroundStyle(source.isMuted ? StudioPalette.red : StudioPalette.green)
            .disabled(!store.supportsPerAppMute)
            .help(store.supportsPerAppMute ? "Mute this source" : "Per-app mute requires an audio backend.")
            .accessibilityLabel(source.isMuted ? "Unmute \(source.appName)" : "Mute \(source.appName)")
            .accessibilityHint(store.supportsPerAppMute ? "Toggles mute for this source" : "Per-app mute requires an audio backend")

            Slider(
                value: Binding(
                    get: { source.volume },
                    set: { store.setSourceVolume(source: source, volume: $0) }
                ),
                in: 0...1.5
            )
            .disabled(!store.supportsPerAppVolume)
            .help(store.supportsPerAppVolume ? "Set source volume" : "Per-app gain requires an audio backend.")
            .accessibilityLabel("\(source.appName) gain")
            .accessibilityValue(source.volume.roundedPercentDescription)
            .accessibilityHint(store.supportsPerAppVolume ? "Adjusts app route volume" : "Per-app gain requires an audio backend")

            Text("\(Int((source.volume * 100).rounded()))")
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundStyle(StudioPalette.amber)
                .frame(width: 28, alignment: .trailing)
        }
    }

    private var channelBackground: Color {
        if isDropTargeted {
            return StudioPalette.amber.opacity(0.12)
        }
        if isSelected {
            return StudioPalette.strip.opacity(0.95)
        }
        if store.routeStatusIsWarning(for: source) {
            return Color.orange.opacity(0.10)
        }
        return StudioPalette.strip.opacity(0.74)
    }

    private var rowStrokeColor: Color {
        if isDropTargeted {
            return StudioPalette.amber.opacity(0.95)
        }
        return isSelected ? StudioPalette.amber.opacity(0.95) : StudioPalette.stroke
    }

    private var rowStrokeWidth: CGFloat {
        if isDropTargeted {
            return 2
        }
        return isSelected ? 1.5 : 1
    }

    private var outputSelection: Binding<String> {
        Binding(
            get: { source.followsSystemOutput ? "" : (source.assignedOutputDeviceID ?? "") },
            set: { value in
                store.assignSourceOutput(source: source, uid: value.isEmpty ? nil : value)
            }
        )
    }
}

private struct StudioRouteCable: View {
    let status: RouteVisualStatus
    let followsSystem: Bool

    var body: some View {
        HStack(spacing: 5) {
            Circle()
                .stroke(status.foreground.opacity(0.9), lineWidth: 2)
                .frame(width: 9, height: 9)
            Capsule()
                .fill(status.foreground.opacity(followsSystem ? 0.35 : 0.95))
                .frame(height: followsSystem ? 2 : 4)
            Image(systemName: followsSystem ? "arrow.triangle.branch" : "arrow.right")
                .font(.system(size: 10, weight: .heavy))
                .foregroundStyle(status.foreground)
        }
        .accessibilityHidden(true)
    }
}

private struct StudioSourceDragPreview: View {
    let source: AudioSource
    let outputName: String

    var body: some View {
        HStack(spacing: 9) {
            AppSourceIcon(source: source)
            VStack(alignment: .leading, spacing: 2) {
                Text(source.appName)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                Text("Drag to reorder or route")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Image(systemName: "arrow.right")
                .font(.caption.weight(.heavy))
                .foregroundStyle(StudioPalette.amber)
            Text(outputName)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(StudioPalette.header.opacity(0.96), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(StudioPalette.amber.opacity(0.45), lineWidth: 1)
        }
        .frame(maxWidth: 260)
    }
}

private struct StudioSegmentMeter: View {
    let level: Double
    var segmentCount: Int = 12
    var tint: Color = StudioPalette.green
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        GeometryReader { proxy in
            let clampedLevel = max(0, min(1, level))

            HStack(spacing: 3) {
                ForEach(0..<segmentCount, id: \.self) { index in
                    let threshold = Double(index + 1) / Double(segmentCount)
                    RoundedRectangle(cornerRadius: 2, style: .continuous)
                        .fill(segmentColor(for: threshold).opacity(threshold <= clampedLevel ? 0.95 : 0.20))
                        .overlay {
                            RoundedRectangle(cornerRadius: 2, style: .continuous)
                                .stroke(Color.white.opacity(threshold <= clampedLevel ? 0.12 : 0.05), lineWidth: 0.5)
                        }
                        .shadow(
                            color: segmentColor(for: threshold).opacity(threshold <= clampedLevel ? 0.45 : 0),
                            radius: 3
                        )
                }
            }
            .padding(.horizontal, 5)
            .padding(.vertical, 5)
            .frame(width: proxy.size.width, height: proxy.size.height)
            .background {
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(StudioPalette.inset.opacity(0.92))
                    .overlay(tint.opacity(0.06))
            }
            .overlay(alignment: .trailing) {
                if clampedLevel > 0.92 {
                    Capsule()
                        .fill(StudioPalette.red)
                        .frame(width: 3)
                        .padding(.vertical, 4)
                        .padding(.trailing, 4)
                        .shadow(color: StudioPalette.red.opacity(0.7), radius: 4)
                }
            }
            .overlay {
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .stroke(StudioPalette.strongStroke, lineWidth: 1)
            }
            .animation(reduceMotion ? nil : .easeOut(duration: 0.18), value: clampedLevel)
        }
        .frame(height: 24)
        .accessibilityLabel("Audio level")
        .accessibilityValue(level.clampedUnit.roundedPercentDescription)
    }

    private func segmentColor(for threshold: Double) -> Color {
        if threshold > 0.88 {
            return StudioPalette.red
        }
        if threshold > 0.68 {
            return StudioPalette.amber
        }
        return tint
    }
}

private struct StudioRouteInspector: View {
    let source: AudioSource
    @ObservedObject var store: AudioRouterStore

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                StudioLED(color: store.statusStyle(for: source).foreground)
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(source.appName) -> \(store.routeOutputName(for: source))")
                        .font(.subheadline.weight(.semibold))
                    Text("SELECTED CHANNEL")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                StudioLEDLabel(text: store.routeStatus(for: source), status: store.statusStyle(for: source))
            }

            if let diagnostic = store.routeDiagnostic(for: source) {
                StudioDiagnosticBanner(text: diagnostic, isWarning: store.routeStatusIsWarning(for: source))
            }

            StudioRouteHealthGrid(items: store.routeHealthItems(for: source))

            HStack(spacing: 8) {
                Button {
                    store.resetSourceToSystemOutput(source)
                } label: {
                    Label("Follow System", systemImage: "arrow.triangle.branch")
                }
                .accessibilityHint("Removes the custom output assignment for \(source.appName)")
                Button(role: .destructive) {
                    store.resetSourceToSystemOutput(source)
                } label: {
                    Label("Delete Route", systemImage: "trash")
                }
                .accessibilityHint("Deletes this saved route and follows the system output")
                if routeCanRetry {
                    Button {
                        store.retrySourceRoute(source)
                    } label: {
                        Label("Retry Route", systemImage: "arrow.clockwise.circle")
                    }
                    .accessibilityHint("Retries the saved custom route for \(source.appName)")
                }
                if store.isUserAddedRouteApp(source) || store.isDefaultRouteApp(source) {
                    Button(role: .destructive) {
                        store.removeRouteApp(source)
                    } label: {
                        Label(store.isDefaultRouteApp(source) ? "Hide App" : "Remove App", systemImage: "minus.circle")
                    }
                    .accessibilityHint("Removes \(source.appName) from the routing dashboard")
                }
                Spacer()
                Toggle("Solo", isOn: soloBinding)
                    .toggleStyle(.switch)
                    .controlSize(.small)
                    .accessibilityHint("Mutes other app routes when backend support is available")
            }
            .controlSize(.small)
        }
        .padding(10)
        .background(StudioPalette.inset, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .stroke(StudioPalette.stroke, lineWidth: 1)
        }
    }

    private var soloBinding: Binding<Bool> {
        Binding(
            get: { store.soloSourceID == source.id },
            set: { enabled in
                if enabled != (store.soloSourceID == source.id) {
                    store.toggleSolo(source: source)
                }
            }
        )
    }

    private var routeCanRetry: Bool {
        let route = store.route(for: source)
        return route.routeMode == .customOutput && route.status != .active
    }
}

private struct StudioRouteHealthGrid: View {
    let items: [RouteHealthItem]

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 160), spacing: 8)], spacing: 8) {
            ForEach(items) { item in
                HStack(spacing: 7) {
                    StudioLED(color: item.state.visualStatus.foreground)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(item.title.uppercased())
                            .font(.system(size: 8, weight: .heavy, design: .monospaced))
                            .foregroundStyle(.secondary)
                        Text(item.detail)
                            .font(.caption2)
                            .foregroundStyle(.primary.opacity(0.86))
                            .lineLimit(1)
                    }
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 7)
                .background(StudioPalette.strip.opacity(0.68), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .stroke(StudioPalette.stroke, lineWidth: 1)
                }
                .help(item.detail)
                .accessibilityElement(children: .combine)
                .accessibilityLabel("\(item.title), \(item.detail), \(item.state.badgeTitle)")
            }
        }
    }
}

private struct StudioDiagnosticBanner: View {
    let text: String
    let isWarning: Bool

    var body: some View {
        Label(text, systemImage: isWarning ? "exclamationmark.triangle.fill" : "info.circle.fill")
            .font(.caption)
            .foregroundStyle(isWarning ? StudioPalette.amber : .secondary)
            .padding(.horizontal, 9)
            .padding(.vertical, 7)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background((isWarning ? StudioPalette.amber : Color.secondary).opacity(0.10), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
            .accessibilityLabel(isWarning ? "Warning, \(text)" : "Information, \(text)")
    }
}

private struct StudioOutputRackPanel: View {
    @ObservedObject var store: AudioRouterStore

    var body: some View {
        StudioPanel(
            title: "Output Rack",
            systemImage: "slider.vertical.3",
            trailing: "\(store.outputDevices.count)"
        ) {
            VStack(spacing: 8) {
                ForEach(store.outputDevices) { device in
                    StudioOutputModule(device: device, store: store)
                        .onDrop(of: [.text, .plainText], isTargeted: nil) { providers in
                            routeDroppedSource(from: providers, to: device)
                        }
                }
            }
        }
    }

    private func routeDroppedSource(from providers: [NSItemProvider], to device: AudioDevice) -> Bool {
        guard let provider = providers.first(where: { $0.canLoadObject(ofClass: NSString.self) }) else {
            return false
        }

        provider.loadObject(ofClass: NSString.self) { object, _ in
            guard let sourceID = object as? String else { return }
            Task { @MainActor in
                guard let source = store.audioSources.first(where: { $0.id == sourceID }) else { return }
                store.assignSourceOutput(source: source, uid: device.uid)
                store.selectedSourceID = source.id
            }
        }
        return true
    }
}

private struct StudioOutputModule: View {
    let device: AudioDevice
    @ObservedObject var store: AudioRouterStore

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                DeviceIcon(device: device)
                VStack(alignment: .leading, spacing: 2) {
                    Text(device.name)
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)
                    Text(device.typeDescription)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer()
                StudioLEDLabel(
                    text: device.isDefault ? "Main" : (device.isAlive ? "Ready" : "Missing"),
                    status: device.isAlive ? .working : .deviceMissing
                )
            }

            StudioSegmentMeter(level: store.deviceMeters[device.id] ?? 0, segmentCount: 14, tint: StudioPalette.teal)

            VolumeSlider(
                title: "Vol",
                value: device.volume,
                isEnabled: device.canSetVolume,
                systemImage: device.kind.systemImage,
                onChange: { store.setDeviceVolume(device, volume: $0) }
            )
            .controlSize(.small)

            HStack(spacing: 8) {
                Button {
                    store.setDeviceMuted(device, isMuted: !(device.isMuted ?? false))
                } label: {
                    Image(systemName: (device.isMuted ?? false) ? "speaker.slash.fill" : "speaker.wave.1.fill")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(!device.canSetMute)
                .accessibilityLabel((device.isMuted ?? false) ? "Unmute \(device.name)" : "Mute \(device.name)")
                .accessibilityHint(device.canSetMute ? "Toggles mute for this output" : "Mute is not supported by this output")

                Button(device.isDefault ? "System" : "Set System") {
                    store.setDefaultDevice(device)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(device.isDefault)
                .accessibilityHint(device.isDefault ? "\(device.name) is already the system output" : "Makes \(device.name) the system output")

                Spacer()

                Text(device.sampleRateDescription)
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.tertiary)
            }

            routedSources
        }
        .padding(10)
        .background(StudioPalette.strip.opacity(0.76), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .stroke(StudioPalette.stroke, lineWidth: 1)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("\(device.name), \(device.typeDescription), \(device.isDefault ? "system output" : "available output")")
    }

    @ViewBuilder
    private var routedSources: some View {
        let routed = store.routedSources(to: device)
        if routed.isEmpty {
            Label("No apps assigned", systemImage: "tray")
                .font(.caption)
                .foregroundStyle(.secondary)
        } else {
            HStack(spacing: 6) {
                ForEach(routed) { source in
                    Label(source.appName, systemImage: "app.fill")
                        .font(.caption2.weight(.medium))
                        .padding(.horizontal, 7)
                        .padding(.vertical, 4)
                        .background(StudioPalette.teal.opacity(0.13), in: Capsule())
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
