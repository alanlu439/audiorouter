import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct RoutingDashboardView: View {
    @ObservedObject var store: AudioRouterStore

    var body: some View {
        StudioConsoleFrame {
            StudioPatchBayPanel(store: store)
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
    static let console = Color(red: 0.055, green: 0.057, blue: 0.062)
    static let header = Color(red: 0.083, green: 0.087, blue: 0.095)
    static let panel = Color(red: 0.069, green: 0.072, blue: 0.079)
    static let strip = Color(red: 0.096, green: 0.100, blue: 0.108)
    static let inset = Color(red: 0.038, green: 0.040, blue: 0.045)
    static let stroke = Color.white.opacity(0.075)
    static let strongStroke = Color.white.opacity(0.125)
    static let green = Color(red: 0.45, green: 0.88, blue: 0.58)
    static let amber = Color(red: 0.94, green: 0.66, blue: 0.36)
    static let teal = Color(red: 0.36, green: 0.80, blue: 0.75)
    static let blue = Color(red: 0.50, green: 0.63, blue: 0.92)
    static let red = Color(red: 0.94, green: 0.38, blue: 0.36)
    static let warmInk = Color(red: 0.11, green: 0.085, blue: 0.050)
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
        HStack(alignment: .center, spacing: 9) {
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
                .frame(width: 16, height: 16, alignment: .center)
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
        HStack(alignment: .center, spacing: 9) {
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
        HStack(alignment: .center, spacing: 6) {
            StudioLED(color: status.foreground)
            Text(text.uppercased())
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundStyle(status.foreground)
                .lineLimit(1)
        }
        .padding(.horizontal, 8)
        .frame(height: 22, alignment: .center)
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
        StudioPanel(title: "Guided Setup", systemImage: "wand.and.stars", trailing: "First run") {
            VStack(alignment: .leading, spacing: 12) {
                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .top, spacing: 10) {
                        OnboardingStep(number: "1", title: "Confirm devices", detail: "Make sure your speaker, AirPods, or built-in output is visible.")
                        OnboardingArrow()
                        OnboardingStep(number: "2", title: "Choose source and output", detail: "Use the side-by-side Route Builder to connect an app to a destination.")
                        OnboardingArrow()
                        OnboardingStep(number: "3", title: "Check permission", detail: "When macOS asks, approve System Audio Recording manually.")
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        OnboardingStep(number: "1", title: "Confirm devices", detail: "Make sure your speaker, AirPods, or built-in output is visible.")
                        OnboardingStep(number: "2", title: "Choose source and output", detail: "Use the side-by-side Route Builder to connect an app to a destination.")
                        OnboardingStep(number: "3", title: "Check permission", detail: "When macOS asks, approve System Audio Recording manually.")
                    }
                }

                HStack(spacing: 8) {
                    Button {
                        store.showOnboarding()
                    } label: {
                        Label("Open Guided Setup", systemImage: "sparkles.rectangle.stack")
                    }
                    .accessibilityHint("Opens the full AudioRouter guided setup assistant")

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
                .foregroundStyle(StudioPalette.warmInk)
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
            HStack(alignment: .center, spacing: 9) {
                Image(systemName: systemImage)
                    .font(.system(size: 14, weight: .heavy))
                    .foregroundStyle(StudioPalette.amber)
                    .frame(width: 18, height: 18, alignment: .center)
                Text(title.uppercased())
                    .font(.system(size: 12, weight: .heavy, design: .monospaced))
                    .tracking(1.2)
                    .lineLimit(1)
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
                .padding(12)
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
            title: "Routes",
            systemImage: "app.connected.to.app.below.fill",
            trailing: "\(store.routeAppDisplayNames.count) configured"
        ) {
            VStack(spacing: 8) {
                StudioPatchBayActions(store: store) {
                    isAddingApp = true
                }

                StudioPatchBayHeader()

                ForEach(store.audioSources) { source in
                    StudioChannelStrip(source: source, store: store)
                }

                StudioRouteReliabilityCenter(store: store)

                StudioDeviceChangeGuardPanel(store: store)

                StudioSectionMarker(
                    title: "Outputs",
                    detail: "\(store.outputDevices.count) devices, \(store.outputGroups.count) group\(store.outputGroups.count == 1 ? "" : "s")",
                    tint: StudioPalette.teal
                )

                StudioOutputActions(store: store)

                if !store.outputGroups.isEmpty {
                    StudioSectionMarker(
                        title: "Group Play",
                        detail: "Multi-speaker routes",
                        tint: StudioPalette.amber
                    )

                    ForEach(store.outputGroups) { group in
                        StudioOutputGroupStrip(group: group, store: store)
                    }
                }

                StudioSectionMarker(
                    title: "Individual Outputs",
                    detail: "Single-device destinations",
                    tint: StudioPalette.teal
                )

                ForEach(store.outputDevices) { device in
                    StudioOutputStrip(device: device, store: store)
                }
            }
        }
        .sheet(isPresented: $isAddingApp) {
            AddRouteAppSheet(store: store)
        }
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

private struct StudioRouteReliabilityCenter: View {
    @ObservedObject var store: AudioRouterStore

    private var routeRows: [AudioSource] {
        store.audioSources
    }

    private var warningCount: Int {
        routeRows.filter { store.routeStatusIsWarning(for: $0) || store.routeDiagnostic(for: $0) != nil }.count
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            StudioSectionMarker(
                title: "Reliability Center",
                detail: warningCount == 0 ? "All routes ready" : "\(warningCount) route\(warningCount == 1 ? "" : "s") need attention",
                tint: warningCount == 0 ? StudioPalette.green : StudioPalette.amber
            )

            VStack(spacing: 7) {
                HStack(spacing: 8) {
                    Label("Route checks", systemImage: "stethoscope")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)

                    Spacer()

                    Button {
                        store.refresh()
                    } label: {
                        Label("Refresh", systemImage: "arrow.clockwise")
                    }

                    Button {
                        store.probeProcessTapPermission()
                    } label: {
                        Label("Check Permission", systemImage: "checkmark.shield")
                    }
                }
                .controlSize(.small)

                if routeRows.isEmpty {
                    reliabilityEmptyState
                } else {
                    ForEach(routeRows) { source in
                        StudioReliabilityRow(source: source, store: store)
                    }
                }
            }
            .padding(.horizontal, 11)
            .padding(.vertical, 9)
            .background(StudioPalette.inset.opacity(0.62), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .stroke(StudioPalette.stroke, lineWidth: 1)
            }
        }
    }

    private var reliabilityEmptyState: some View {
        Text("Add a source app to start route checks.")
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 4)
    }
}

private struct StudioReliabilityRow: View {
    let source: AudioSource
    @ObservedObject var store: AudioRouterStore

    private var status: RouteVisualStatus {
        store.statusStyle(for: source)
    }

    private var diagnosticText: String {
        store.routeDiagnostic(for: source) ?? "Route is ready for \(store.routeOutputName(for: source))."
    }

    private var healthItems: [RouteHealthItem] {
        store.routeHealthItems(for: source)
    }

    var body: some View {
        HStack(alignment: .center, spacing: 9) {
            AppSourceIcon(source: source)
                .frame(width: 24, height: 24)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 7) {
                    Text(source.appName)
                        .font(.caption.weight(.bold))
                        .lineLimit(1)
                    StudioLEDLabel(text: store.routeStatus(for: source), status: status)
                }
                Text(diagnosticText)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            compactHealthSummary

            Button {
                store.testRoute(for: source)
            } label: {
                Image(systemName: "speaker.wave.2.fill")
            }
            .buttonStyle(.borderless)
            .help("Play a test tone through \(store.routeOutputName(for: source))")
            .accessibilityLabel("Test \(source.appName) route")

            if canRetry {
                Button {
                    store.retrySourceRoute(source)
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .buttonStyle(.borderless)
                .help("Retry \(source.appName) route")
                .accessibilityLabel("Retry \(source.appName) route")
            }
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 7)
        .background(StudioPalette.strip.opacity(0.72), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
        .overlay(alignment: .leading) {
            Rectangle()
                .fill(status.foreground)
                .frame(width: 3)
                .clipShape(RoundedRectangle(cornerRadius: 2, style: .continuous))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .stroke(status.foreground.opacity(store.routeStatusIsWarning(for: source) ? 0.36 : 0.16), lineWidth: 1)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("\(source.appName), \(store.routeStatus(for: source)), \(diagnosticText)")
    }

    private var compactHealthSummary: some View {
        HStack(spacing: 5) {
            ForEach(healthItems.prefix(4)) { item in
                StudioLED(color: item.state.visualStatus.foreground)
                    .help("\(item.title): \(item.detail)")
                    .accessibilityLabel("\(item.title), \(item.state.badgeTitle)")
            }
        }
    }

    private var canRetry: Bool {
        let route = store.route(for: source)
        return route.routeMode == .customOutput && route.status != .active
    }
}

private struct StudioDeviceChangeGuardPanel: View {
    @ObservedObject var store: AudioRouterStore

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            StudioSectionMarker(
                title: "Device Change Guard",
                detail: guardDetail,
                tint: StudioPalette.blue
            )

            HStack(alignment: .center, spacing: 9) {
                guardTile(
                    title: "Protect Routes",
                    detail: "Delay route cleanup while Bluetooth devices re-enumerate",
                    systemImage: "earbuds",
                    binding: protectPlaybackBinding
                )

                guardTile(
                    title: "Keep Playing",
                    detail: "Assert play for Spotify and Music during AirPods changes",
                    systemImage: "play.circle.fill",
                    binding: keepPlayingBinding
                )

                VStack(alignment: .leading, spacing: 4) {
                    Text("QUICK ACTIONS")
                        .font(.system(size: 8, weight: .heavy, design: .monospaced))
                        .foregroundStyle(.secondary)
                    HStack(spacing: 7) {
                        Button {
                            store.refresh()
                        } label: {
                            Label("Refresh", systemImage: "arrow.clockwise")
                        }
                        Button {
                            store.probeProcessTapPermission()
                        } label: {
                            Label("Probe", systemImage: "waveform.badge.magnifyingglass")
                        }
                    }
                    .controlSize(.small)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(StudioPalette.inset.opacity(0.62), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .stroke(StudioPalette.stroke, lineWidth: 1)
                }
            }
        }
    }

    private var guardDetail: String {
        if store.settings.protectPlaybackDuringDeviceChanges && store.settings.keepMediaPlayingDuringDeviceChanges {
            return "AirPods/Bluetooth protection active"
        }
        return "Some protection is off"
    }

    private func guardTile(
        title: String,
        detail: String,
        systemImage: String,
        binding: Binding<Bool>
    ) -> some View {
        Toggle(isOn: binding) {
            HStack(spacing: 8) {
                Image(systemName: systemImage)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(binding.wrappedValue ? StudioPalette.green : StudioPalette.amber)
                    .frame(width: 22, height: 22)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.caption.weight(.bold))
                    Text(detail)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }
        }
        .toggleStyle(.switch)
        .controlSize(.small)
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(StudioPalette.inset.opacity(0.62), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .stroke(StudioPalette.stroke, lineWidth: 1)
        }
    }

    private var protectPlaybackBinding: Binding<Bool> {
        Binding(
            get: { store.settings.protectPlaybackDuringDeviceChanges },
            set: { store.settings.protectPlaybackDuringDeviceChanges = $0 }
        )
    }

    private var keepPlayingBinding: Binding<Bool> {
        Binding(
            get: { store.settings.keepMediaPlayingDuringDeviceChanges },
            set: { store.settings.keepMediaPlayingDuringDeviceChanges = $0 }
        )
    }
}

private struct StudioSectionMarker: View {
    let title: String
    let detail: String
    let tint: Color

    var body: some View {
        HStack(alignment: .center, spacing: 8) {
            Capsule()
                .fill(tint)
                .frame(width: 4, height: 16)
                .shadow(color: tint.opacity(0.45), radius: 3)
            Text(title.uppercased())
                .font(.system(size: 10, weight: .heavy, design: .monospaced))
                .foregroundStyle(.primary.opacity(0.9))
                .lineLimit(1)
            Rectangle()
                .fill(StudioPalette.stroke)
                .frame(height: 1)
            Text(detail)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .frame(height: 16, alignment: .center)
        }
        .padding(.horizontal, 11)
        .padding(.top, 3)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title), \(detail)")
    }
}

private struct StudioSmoothRouteBuilder: View {
    @ObservedObject var store: AudioRouterStore
    @State private var selectedSourceID = ""
    @State private var selectedOutputID = ""
    @State private var lastAppliedSignature: String?
    @State private var recentlyAppliedRoute: String?
    @State private var advanceAfterApply = true

    private var selectedSource: AudioSource? {
        let id = selectedSourceID.isEmpty ? (store.selectedSourceID ?? store.audioSources.first?.id ?? "") : selectedSourceID
        return store.audioSources.first { $0.id == id }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            setupRail
            configurationToolbar
            routeReadinessStrip

            HStack(alignment: .top, spacing: 10) {
                SmoothRouteColumn(title: "Input", systemImage: "app.fill", tint: StudioPalette.blue) {
                    ScrollView {
                        LazyVStack(spacing: 7) {
                            ForEach(store.audioSources) { source in
                                SmoothSourceChoice(
                                    source: source,
                                    isSelected: source.id == selectedSource?.id,
                                    meterLevel: store.sourceMeters[source.id] ?? 0
                                ) {
                                    selectSource(source)
                                }
                            }
                        }
                    }
                    .frame(maxHeight: 170)
                }
                .frame(minWidth: 220, maxWidth: .infinity, alignment: .topLeading)

                routeGlyph
                    .frame(width: 42)

                SmoothRouteColumn(title: "Output", systemImage: "speaker.wave.2.fill", tint: StudioPalette.teal) {
                    VStack(alignment: .leading, spacing: 8) {
                        suggestedTargetStrip

                        ScrollView {
                            LazyVStack(spacing: 7) {
                                ForEach(routeTargets) { target in
                                    SmoothOutputChoice(target: target, isSelected: target.selectionID == selectedOutputID) {
                                        selectOutput(target.selectionID)
                                    }
                                }
                            }
                        }
                        .frame(maxHeight: 170)
                    }
                }
                .frame(minWidth: 240, maxWidth: .infinity, alignment: .topLeading)

                previewPanel
                    .frame(width: 152, alignment: .top)
            }

            HStack(spacing: 8) {
                StudioLED(color: routeAlreadySet ? StudioPalette.green : StudioPalette.amber)
                Text(routeSummary)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 2)
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
                syncOutputToSelectedSource()
            }
        }
        .onChange(of: store.selectedSourceID) { _, _ in syncFromStoreSelection() }
        .onAppear {
            selectedSourceID = store.selectedSourceID ?? store.audioSources.first?.id ?? ""
            syncOutputToSelectedSource()
        }
    }

    private var setupRail: some View {
        HStack(spacing: 8) {
            SmoothSetupStep(number: "1", title: "Input", detail: selectedSource?.appName ?? "Choose", tint: StudioPalette.blue, isActive: selectedSource != nil)
            SmoothSetupStep(number: "2", title: "Output", detail: outputDisplayName, tint: StudioPalette.teal, isActive: selectedSource != nil)
            SmoothSetupStep(number: "3", title: routeAlreadySet ? "Set" : "Apply", detail: routeActionTitle, tint: routeAlreadySet ? StudioPalette.green : StudioPalette.amber, isActive: selectedSource != nil)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Route setup, input \(selectedSource?.appName ?? "not selected"), output \(outputDisplayName), \(routeActionTitle)")
    }

    private var configurationToolbar: some View {
        HStack(spacing: 9) {
            Label(sourcePositionText, systemImage: "list.number")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)

            ProgressView(value: configurationProgress)
                .progressViewStyle(.linear)
                .tint(StudioPalette.teal)
                .frame(maxWidth: 150)
                .accessibilityLabel("Custom route progress")
                .accessibilityValue("\(customRouteCount) of \(max(store.audioSources.count, 1)) source apps routed")

            Text("\(customRouteCount)/\(store.audioSources.count) custom")
                .font(.caption2.monospacedDigit().weight(.semibold))
                .foregroundStyle(.secondary)

            Spacer(minLength: 0)

            Button {
                selectPreviousSource()
            } label: {
                Image(systemName: "chevron.up")
            }
            .buttonStyle(.borderless)
            .disabled(store.audioSources.count < 2)
            .help("Previous source")
            .accessibilityLabel("Previous source app")

            Button {
                selectNextSource()
            } label: {
                Image(systemName: "chevron.down")
            }
            .buttonStyle(.borderless)
            .disabled(store.audioSources.count < 2)
            .help("Next source")
            .accessibilityLabel("Next source app")

            Button {
                selectNextUnroutedSource()
            } label: {
                Label("Next unset", systemImage: "forward.end.fill")
            }
            .buttonStyle(.borderless)
            .disabled(nextUnroutedSource == nil)
            .help("Jump to the next source still following system output")
            .accessibilityHint("Selects the next source app without a custom output")

            Toggle("Auto-next", isOn: $advanceAfterApply)
                .toggleStyle(.switch)
                .font(.caption2.weight(.semibold))
                .help("After applying a route, keep the output selected and move to the next source")
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(StudioPalette.strip.opacity(0.58), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .stroke(StudioPalette.stroke, lineWidth: 1)
        }
    }

    private var routeReadinessStrip: some View {
        HStack(spacing: 7) {
            SmoothReadinessBadge(
                title: "App",
                value: selectedSource?.isRunning == true ? "Running" : "Open",
                systemImage: selectedSource?.isRunning == true ? "checkmark.circle.fill" : "play.circle",
                tint: selectedSource?.isRunning == true ? StudioPalette.green : StudioPalette.amber
            )
            SmoothReadinessBadge(
                title: "Audio",
                value: selectedSource?.audioObjectID == nil ? "Play sound" : "Detected",
                systemImage: selectedSource?.audioObjectID == nil ? "waveform.badge.exclamationmark" : "waveform.circle.fill",
                tint: selectedSource?.audioObjectID == nil ? StudioPalette.amber : StudioPalette.green
            )
            SmoothReadinessBadge(
                title: "Output",
                value: selectedOutputReadyLabel,
                systemImage: selectedOutputReady ? "speaker.wave.2.fill" : "speaker.slash.fill",
                tint: selectedOutputReady ? StudioPalette.teal : StudioPalette.amber
            )
            SmoothReadinessBadge(
                title: "Result",
                value: routeReadinessLabel,
                systemImage: routeReadinessIcon,
                tint: routeReadinessTint
            )
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Route readiness. App \(selectedSource?.isRunning == true ? "running" : "not running"), audio \(selectedSource?.audioObjectID == nil ? "not detected" : "detected"), output \(selectedOutputReadyLabel), result \(routeReadinessLabel)")
    }

    private var suggestedTargetStrip: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: "sparkles")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(StudioPalette.amber)
                Text("Suggested")
                    .font(.system(size: 8, weight: .heavy, design: .monospaced))
                    .foregroundStyle(.secondary)
                Spacer(minLength: 0)
            }

            ViewThatFits(in: .horizontal) {
                HStack(spacing: 6) {
                    ForEach(suggestedRouteTargets) { target in
                        SmoothSuggestionButton(target: target, isSelected: target.selectionID == selectedOutputID) {
                            selectOutput(target.selectionID)
                        }
                    }
                }

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 92), spacing: 6)], spacing: 6) {
                    ForEach(suggestedRouteTargets) { target in
                        SmoothSuggestionButton(target: target, isSelected: target.selectionID == selectedOutputID) {
                            selectOutput(target.selectionID)
                        }
                    }
                }
            }
        }
        .padding(8)
        .background(StudioPalette.inset.opacity(0.72), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .stroke(StudioPalette.stroke, lineWidth: 1)
        }
    }

    private var routeGlyph: some View {
        VStack(spacing: 6) {
            Text("TO")
                .font(.system(size: 8, weight: .heavy, design: .monospaced))
                .foregroundStyle(.secondary)
            Image(systemName: "arrow.right")
                .font(.system(size: 17, weight: .heavy))
                .foregroundStyle(routeReadinessTint)
            StudioLED(color: routeReadinessTint)
        }
        .padding(.top, 48)
        .accessibilityHidden(true)
    }

    private var previewPanel: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(spacing: 6) {
                Image(systemName: previewStatusIcon)
                    .foregroundStyle(routeReadinessTint)
                Text(previewStatusTitle)
                    .font(.system(size: 9, weight: .heavy, design: .monospaced))
                    .foregroundStyle(.secondary)
                Spacer(minLength: 0)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(selectedSource?.appName ?? "No Input")
                    .font(.caption.weight(.bold))
                    .lineLimit(1)
                HStack(spacing: 6) {
                    Capsule()
                        .fill(routeReadinessTint)
                        .frame(width: 28, height: 3)
                    Image(systemName: "arrow.right")
                        .font(.caption2.weight(.heavy))
                        .foregroundStyle(routeReadinessTint)
                }
                Text(outputDisplayName)
                    .font(.caption.weight(.bold))
                    .lineLimit(2)
            }

            Button {
                applyRoute()
            } label: {
                Label(routeActionTitle, systemImage: routeActionIcon)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
            .tint(routeButtonTint)
            .disabled(routeActionDisabled)
            .help(routeActionHelp)
            .accessibilityHint(routeActionHelp)

            HStack(spacing: 5) {
                sourceMenu
                outputMenu
                Spacer(minLength: 0)
                Button {
                    selectedOutputID = ""
                    applyRoute()
                } label: {
                    Image(systemName: "arrow.triangle.branch")
                }
                .buttonStyle(.borderless)
                .disabled(selectedSource == nil)
                .help("Follow system output")
                .accessibilityLabel("Follow system output")
            }
        }
        .padding(10)
        .background(StudioPalette.strip.opacity(0.70), in: RoundedRectangle(cornerRadius: 7, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .stroke(routeReadinessTint.opacity(0.24), lineWidth: 1)
        }
    }

    private var sourceMenu: some View {
        Menu {
            ForEach(store.audioSources) { source in
                Button(source.appName) {
                    selectSource(source)
                }
            }
        } label: {
            Image(systemName: "app.badge")
        }
        .menuStyle(.borderlessButton)
        .help("More input choices")
        .accessibilityLabel("More input choices")
    }

    private var outputMenu: some View {
        Menu {
            Button("Follow System") {
                selectOutput("")
            }
            Divider()
            ForEach(store.outputDevices) { device in
                Button(device.name) {
                    selectOutput(device.uid)
                }
            }
            if !store.outputGroups.isEmpty {
                Divider()
                ForEach(store.outputGroups) { group in
                    Button("\(group.name) Group") {
                        selectOutput(group.routeTargetID)
                    }
                }
            }
        } label: {
            Image(systemName: "speaker.badge.gearshape")
        }
        .menuStyle(.borderlessButton)
        .help("More output choices")
        .accessibilityLabel("More output choices")
    }

    private var routeTargets: [SmoothRouteTarget] {
        var targets = [
            SmoothRouteTarget(
                id: "follow-system",
                selectionID: "",
                title: "Follow System",
                detail: store.currentOutput?.name ?? "Current output",
                systemImage: "arrow.triangle.branch",
                tint: StudioPalette.blue
            )
        ]

        targets += store.outputDevices.map { device in
            SmoothRouteTarget(
                id: "device-\(device.uid)",
                selectionID: device.uid,
                title: device.name,
                detail: device.isDefault ? "\(device.typeDescription) · Main" : device.typeDescription,
                systemImage: device.kind.systemImage,
                tint: device.transport == .builtIn ? StudioPalette.amber : StudioPalette.teal
            )
        }

        targets += store.outputGroups.map { group in
            SmoothRouteTarget(
                id: "group-\(group.id.uuidString)",
                selectionID: group.routeTargetID,
                title: group.name,
                detail: "\(group.deviceUIDs.count) outputs · Group",
                systemImage: "speaker.3.fill",
                tint: StudioPalette.teal
            )
        }

        return targets
    }

    private var routeAlreadySet: Bool {
        guard let selectedSource else { return false }
        let route = store.route(for: selectedSource)
        let currentSelection = route.routeMode == .followSystemOutput ? "" : (route.outputDeviceID ?? "")
        return currentSelection == selectedOutputID
    }

    private var selectedRoute: AudioRoute? {
        selectedSource.map { store.route(for: $0) }
    }

    private var routeActionTitle: String {
        if selectedSource == nil { return "Choose" }
        if selectedOutputID.isEmpty {
            return routeAlreadySet ? "Following" : "Follow System"
        }
        if routeAlreadySet, selectedRoute?.status == .active {
            return "Live"
        }
        if canAttemptLiveRoute {
            return routeAlreadySet ? "Try Live" : "Save & Try"
        }
        return routeAlreadySet ? "Saved" : "Save Route"
    }

    private var previewStatusTitle: String {
        if routeAlreadySet, selectedRoute?.status == .active, !selectedOutputID.isEmpty {
            return "Live"
        }
        if routeAlreadySet {
            return selectedOutputID.isEmpty ? "System" : "Saved"
        }
        return "Preview"
    }

    private var previewStatusIcon: String {
        switch previewStatusTitle {
        case "Live": return "checkmark.circle.fill"
        case "System": return "arrow.triangle.branch.circle.fill"
        case "Saved": return "tray.and.arrow.down.fill"
        default: return "point.3.connected.trianglepath.dotted"
        }
    }

    private var routeActionIcon: String {
        if selectedOutputID.isEmpty { return "arrow.triangle.branch" }
        if routeAlreadySet, selectedRoute?.status == .active { return "checkmark" }
        if canAttemptLiveRoute { return "bolt.fill" }
        return routeAlreadySet ? "tray.and.arrow.down.fill" : "square.and.arrow.down"
    }

    private var routeButtonTint: Color {
        if selectedRoute?.status == .active && !selectedOutputID.isEmpty { return StudioPalette.green }
        if canAttemptLiveRoute { return StudioPalette.teal }
        return selectedOutputID.isEmpty ? StudioPalette.blue : StudioPalette.amber
    }

    private var routeActionDisabled: Bool {
        guard selectedSource != nil else { return true }
        if selectedOutputID.isEmpty {
            return routeAlreadySet
        }
        if routeAlreadySet, selectedRoute?.status == .active {
            return true
        }
        if routeAlreadySet {
            return !canAttemptLiveRoute
        }
        return false
    }

    private var routeActionHelp: String {
        guard let selectedSource else { return "Choose an app source first" }
        if selectedOutputID.isEmpty {
            return routeAlreadySet
                ? "\(selectedSource.appName) already follows the system output"
                : "Reset \(selectedSource.appName) to follow the current system output"
        }
        if routeAlreadySet, selectedRoute?.status == .active {
            return "\(selectedSource.appName) is already live on \(outputDisplayName)"
        }
        if routeTargetIsGroup {
            return "Routes this source to every connected output in the group. Separate devices may have small latency differences."
        }
        if !store.supportsTruePerAppRouting {
            return "Saves this output choice. This Mac cannot start live process-tap routing with the current backend."
        }
        if selectedSource.audioObjectID == nil {
            return "Saves this output choice. Start playback in \(selectedSource.appName), then try live routing."
        }
        if !selectedOutputReady {
            return "Choose a connected output before trying a live route."
        }
        return "Saves the output choice and tries to start the live Core Audio process-tap route."
    }

    private var routeSummary: String {
        guard let selectedSource else {
            return "Choose an input app to configure a route."
        }
        if routeTargetIsGroup {
            return "Output group selected. AudioRouter will fan this source out to each connected device in the group."
        }
        if routeAlreadySet, selectedOutputID.isEmpty {
            return "\(selectedSource.appName) follows the current system output."
        }
        if routeAlreadySet, selectedRoute?.status == .active, !selectedOutputID.isEmpty {
            return "\(selectedSource.appName) is live on \(outputDisplayName)."
        }
        if routeAlreadySet, !canAttemptLiveRoute, !selectedOutputID.isEmpty {
            return "\(selectedSource.appName) route is saved. \(routeActionHelp)"
        }
        if let recentlyAppliedRoute, !routeAlreadySet {
            return "\(recentlyAppliedRoute) saved. \(selectedSource.appName) is ready next."
        }
        if routeAlreadySet {
            return "\(selectedSource.appName) is set to \(outputDisplayName)."
        }
        if lastAppliedSignature == routeSignature {
            return "\(selectedSource.appName) route saved."
        }
        return "\(selectedSource.appName) -> \(outputDisplayName)"
    }

    private var routeSignature: String {
        "\(selectedSource?.id ?? "")|\(selectedOutputID)"
    }

    private var outputDisplayName: String {
        if selectedOutputID.isEmpty {
            return "Follow System"
        }
        return routeTargets.first { $0.selectionID == selectedOutputID }?.title ?? "Missing Output"
    }

    private var selectedOutputReady: Bool {
        selectedOutputID.isEmpty
            || store.outputDevices.contains { $0.uid == selectedOutputID }
            || store.outputGroups.contains { $0.routeTargetID == selectedOutputID }
    }

    private var selectedOutputReadyLabel: String {
        if selectedOutputID.isEmpty { return "System" }
        if routeTargetIsGroup { return "Group" }
        return selectedOutputReady ? "Ready" : "Missing"
    }

    private var routeTargetIsGroup: Bool {
        store.outputGroups.contains { $0.routeTargetID == selectedOutputID }
    }

    private var selectedOutputGroupHasDevices: Bool {
        guard let group = store.outputGroups.first(where: { $0.routeTargetID == selectedOutputID }) else {
            return false
        }
        return !store.outputDevices(for: group).isEmpty
    }

    private var canAttemptLiveRoute: Bool {
        guard let selectedSource,
              !store.settings.demoMode,
              store.supportsTruePerAppRouting,
              !selectedOutputID.isEmpty,
              selectedOutputReady,
              selectedSource.audioObjectID != nil else {
            return false
        }
        if routeTargetIsGroup {
            return selectedOutputGroupHasDevices
        }
        return true
    }

    private var routeReadinessLabel: String {
        if store.settings.demoMode { return "Demo" }
        if selectedOutputID.isEmpty { return "System" }
        if selectedRoute?.status == .active && routeAlreadySet { return "Live" }
        if canAttemptLiveRoute { return "Ready" }
        if !store.supportsTruePerAppRouting { return "Backend" }
        return "Saved"
    }

    private var routeReadinessIcon: String {
        switch routeReadinessLabel {
        case "Live": return "checkmark.circle.fill"
        case "Ready": return "bolt.circle.fill"
        case "Backend": return "exclamationmark.triangle.fill"
        case "Demo": return "sparkles"
        case "System": return "arrow.triangle.branch"
        default: return "tray.and.arrow.down.fill"
        }
    }

    private var routeReadinessTint: Color {
        switch routeReadinessLabel {
        case "Live", "Ready": return StudioPalette.green
        case "Backend", "Saved": return StudioPalette.amber
        case "System": return StudioPalette.blue
        default: return StudioPalette.teal
        }
    }

    private var customRouteCount: Int {
        store.audioSources.filter { source in
            store.route(for: source).routeMode != .followSystemOutput
        }.count
    }

    private var configurationProgress: Double {
        guard !store.audioSources.isEmpty else { return 0 }
        return Double(customRouteCount) / Double(store.audioSources.count)
    }

    private var selectedSourceIndex: Int? {
        guard let selectedSource else { return nil }
        return store.audioSources.firstIndex { $0.id == selectedSource.id }
    }

    private var sourcePositionText: String {
        guard let selectedSourceIndex else { return "No source" }
        return "Source \(selectedSourceIndex + 1) of \(store.audioSources.count)"
    }

    private var nextUnroutedSource: AudioSource? {
        guard let selectedSourceIndex, !store.audioSources.isEmpty else {
            return store.audioSources.first { store.route(for: $0).routeMode == .followSystemOutput }
        }

        let sources = store.audioSources
        for offset in 1...sources.count {
            let index = (selectedSourceIndex + offset) % sources.count
            let candidate = sources[index]
            if store.route(for: candidate).routeMode == .followSystemOutput {
                return candidate
            }
        }
        return nil
    }

    private var suggestedRouteTargets: [SmoothRouteTarget] {
        var ids = [""]
        if let currentOutputUID = store.currentOutput?.uid {
            ids.append(currentOutputUID)
        }
        if let bluetooth = store.outputDevices.first(where: { $0.transport == .bluetooth || $0.transport == .bluetoothLE }) {
            ids.append(bluetooth.uid)
        }
        if let builtIn = store.outputDevices.first(where: { $0.transport == .builtIn }) {
            ids.append(builtIn.uid)
        }
        if let group = store.outputGroups.first {
            ids.append(group.routeTargetID)
        }

        var seen: Set<String> = []
        return ids.compactMap { id in
            guard seen.insert(id).inserted else { return nil }
            return routeTargets.first { $0.selectionID == id }
        }
        .prefix(4)
        .map { $0 }
    }

    private func syncFromStoreSelection() {
        guard let storeSelection = store.selectedSourceID,
              storeSelection != selectedSourceID else {
            return
        }
        selectedSourceID = storeSelection
        syncOutputToSelectedSource()
    }

    private func syncOutputToSelectedSource() {
        selectedOutputID = selectedSource.flatMap { source in
            source.followsSystemOutput ? "" : (source.assignedOutputDeviceID ?? "")
        } ?? ""
        lastAppliedSignature = nil
    }

    private func selectOutput(_ outputID: String) {
        selectedOutputID = outputID
        lastAppliedSignature = nil
        recentlyAppliedRoute = nil
    }

    private func selectSource(_ source: AudioSource, keepCurrentOutput: Bool = false) {
        selectedSourceID = source.id
        store.selectedSourceID = source.id
        if keepCurrentOutput, store.route(for: source).routeMode == .followSystemOutput {
            lastAppliedSignature = nil
            return
        }
        syncOutputToSelectedSource()
    }

    private func selectPreviousSource() {
        selectSource(offset: -1)
    }

    private func selectNextSource() {
        selectSource(offset: 1)
    }

    private func selectSource(offset: Int) {
        guard let selectedSourceIndex, !store.audioSources.isEmpty else { return }
        let nextIndex = (selectedSourceIndex + offset + store.audioSources.count) % store.audioSources.count
        selectSource(store.audioSources[nextIndex])
    }

    private func selectNextUnroutedSource(keepCurrentOutput: Bool = false) {
        guard let nextUnroutedSource else { return }
        selectSource(nextUnroutedSource, keepCurrentOutput: keepCurrentOutput)
    }

    private func applyRoute() {
        guard let selectedSource else { return }
        let appliedSourceID = selectedSource.id
        let appliedSummary = "\(selectedSource.appName) -> \(outputDisplayName)"
        store.prepareAndAssignSourceOutput(source: selectedSource, uid: selectedOutputID.isEmpty ? nil : selectedOutputID)
        lastAppliedSignature = routeSignature
        recentlyAppliedRoute = appliedSummary
        if advanceAfterApply, store.audioSources.count > 1 {
            advanceToNextSource(afterApplying: appliedSourceID)
        }
    }

    private func advanceToNextSource(afterApplying sourceID: String) {
        guard let appliedIndex = store.audioSources.firstIndex(where: { $0.id == sourceID }) else { return }
        if let nextUnroutedSource {
            selectSource(nextUnroutedSource, keepCurrentOutput: true)
            return
        }
        let nextIndex = (appliedIndex + 1) % store.audioSources.count
        selectSource(store.audioSources[nextIndex], keepCurrentOutput: true)
    }
}

private struct SmoothSetupStep: View {
    let number: String
    let title: String
    let detail: String
    let tint: Color
    let isActive: Bool

    var body: some View {
        HStack(spacing: 7) {
            Text(number)
                .font(.system(size: 10, weight: .heavy, design: .monospaced))
                .foregroundStyle(isActive ? .black : .secondary)
                .frame(width: 18, height: 18)
                .background((isActive ? tint : StudioPalette.stroke), in: Circle())

            VStack(alignment: .leading, spacing: 1) {
                Text(title.uppercased())
                    .font(.system(size: 8, weight: .heavy, design: .monospaced))
                    .foregroundStyle(.secondary)
                Text(detail)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.primary.opacity(isActive ? 0.88 : 0.45))
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(StudioPalette.strip.opacity(0.58), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .stroke(tint.opacity(isActive ? 0.20 : 0.08), lineWidth: 1)
        }
    }
}

private struct SmoothRouteColumn<Content: View>: View {
    let title: String
    let systemImage: String
    let tint: Color
    let content: Content

    init(title: String, systemImage: String, tint: Color, @ViewBuilder content: () -> Content) {
        self.title = title
        self.systemImage = systemImage
        self.tint = tint
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 7) {
                Image(systemName: systemImage)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(tint)
                    .frame(width: 20, height: 20)
                    .background(tint.opacity(0.13), in: RoundedRectangle(cornerRadius: 5, style: .continuous))
                Text(title.uppercased())
                    .font(.system(size: 9, weight: .heavy, design: .monospaced))
                    .foregroundStyle(.secondary)
                Spacer(minLength: 0)
            }

            content
        }
        .padding(10)
        .background(StudioPalette.strip.opacity(0.68), in: RoundedRectangle(cornerRadius: 7, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .stroke(tint.opacity(0.18), lineWidth: 1)
        }
    }
}

private struct SmoothSourceChoice: View {
    let source: AudioSource
    let isSelected: Bool
    let meterLevel: Double
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 9) {
                AppSourceIcon(source: source)

                VStack(alignment: .leading, spacing: 2) {
                    Text(source.appName)
                        .font(.caption.weight(.bold))
                        .lineLimit(1)
                    Text(source.isRunning ? "Running" : "Ready")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer(minLength: 0)

                SmoothMiniMeter(level: meterLevel, tint: source.isProducingAudio ? StudioPalette.green : StudioPalette.blue)
                    .frame(width: 38)

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(isSelected ? StudioPalette.blue : .secondary.opacity(0.55))
            }
            .padding(8)
            .frame(maxWidth: .infinity, minHeight: 48, alignment: .leading)
            .background(isSelected ? StudioPalette.blue.opacity(0.13) : StudioPalette.inset.opacity(0.68), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .stroke(isSelected ? StudioPalette.blue.opacity(0.70) : StudioPalette.stroke, lineWidth: isSelected ? 1.4 : 1)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(source.appName), \(isSelected ? "selected" : "not selected")")
    }
}

private struct SmoothRouteTarget: Identifiable {
    let id: String
    let selectionID: String
    let title: String
    let detail: String
    let systemImage: String
    let tint: Color
}

private struct SmoothOutputChoice: View {
    let target: SmoothRouteTarget
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 9) {
                Image(systemName: target.systemImage)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(target.tint)
                    .frame(width: 28, height: 28)
                    .background(target.tint.opacity(0.13), in: RoundedRectangle(cornerRadius: 6, style: .continuous))

                VStack(alignment: .leading, spacing: 2) {
                    Text(target.title)
                        .font(.caption.weight(.bold))
                        .lineLimit(1)
                    Text(target.detail)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer(minLength: 0)

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(isSelected ? StudioPalette.teal : .secondary.opacity(0.55))
            }
            .padding(8)
            .frame(maxWidth: .infinity, minHeight: 48, alignment: .leading)
            .background(isSelected ? StudioPalette.teal.opacity(0.12) : StudioPalette.inset.opacity(0.68), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .stroke(isSelected ? StudioPalette.teal.opacity(0.68) : StudioPalette.stroke, lineWidth: isSelected ? 1.4 : 1)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(target.title), \(target.detail), \(isSelected ? "selected" : "not selected")")
    }
}

private struct SmoothReadinessBadge: View {
    let title: String
    let value: String
    let systemImage: String
    let tint: Color

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: systemImage)
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(tint)
            VStack(alignment: .leading, spacing: 1) {
                Text(title.uppercased())
                    .font(.system(size: 7, weight: .heavy, design: .monospaced))
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.primary.opacity(0.88))
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(StudioPalette.strip.opacity(0.58), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .stroke(tint.opacity(0.18), lineWidth: 1)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title), \(value)")
    }
}

private struct SmoothSuggestionButton: View {
    let target: SmoothRouteTarget
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: target.systemImage)
                    .font(.system(size: 9, weight: .bold))
                Text(target.title)
                    .font(.caption2.weight(.bold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 8, weight: .heavy))
                }
            }
            .foregroundStyle(isSelected ? StudioPalette.warmInk : target.tint)
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .frame(maxWidth: .infinity)
            .background(isSelected ? target.tint : target.tint.opacity(0.13), in: Capsule())
            .overlay {
                Capsule()
                    .stroke(target.tint.opacity(isSelected ? 0.0 : 0.28), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
        .help("Choose \(target.title)")
        .accessibilityLabel("Suggested output, \(target.title)")
        .accessibilityValue(isSelected ? "Selected" : "Not selected")
    }
}

private struct SmoothMiniMeter: View {
    let level: Double
    let tint: Color

    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<5, id: \.self) { index in
                let threshold = Double(index + 1) / 5
                RoundedRectangle(cornerRadius: 1.5, style: .continuous)
                    .fill(tint.opacity(threshold <= level.clampedUnit ? 0.95 : 0.20))
                    .frame(width: 4, height: 8 + CGFloat(index * 3))
            }
        }
        .frame(height: 22, alignment: .bottom)
        .accessibilityHidden(true)
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
            HStack(spacing: 8) {
                Text("INPUT APP")
                    .frame(minWidth: 150, maxWidth: 210, alignment: .leading)
                Text("METER")
                    .frame(width: 76, alignment: .leading)
                Text("OUTPUT")
                    .frame(minWidth: 168, maxWidth: .infinity, alignment: .leading)
                Text("GAIN")
                    .frame(width: 230, alignment: .leading)
            }

            HStack(spacing: 8) {
                Text("INPUT APP")
                Spacer()
                Text("OUTPUT")
            }
        }
        .font(.system(size: 9, weight: .bold, design: .monospaced))
        .foregroundStyle(.secondary)
        .padding(.horizontal, 11)
        .padding(.vertical, 3)
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
            .padding(.horizontal, 9)
            .padding(.vertical, 6)
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
        HStack(spacing: 8) {
            channelIdentity
                .frame(minWidth: 150, maxWidth: 210, alignment: .leading)

            StudioSegmentMeter(
                level: store.sourceMeters[source.id] ?? 0,
                segmentCount: 10,
                tint: source.isProducingAudio ? StudioPalette.green : StudioPalette.teal
            )
            .frame(width: 76, alignment: .leading)

            routeAssignment
                .frame(minWidth: 150, maxWidth: .infinity, alignment: .leading)

            gainControls
                .frame(width: 246, alignment: .leading)
        }
    }

    private var channelIdentity: some View {
        HStack(spacing: 8) {
            AppSourceIcon(source: source)
                .frame(width: 28, height: 28)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(source.appName)
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)
                    SourceQualityPill(
                        label: store.sourceAudioQualityLabel(for: source),
                        isLive: store.sourceAudioQualityIsLive(for: source)
                    )
                    .help(store.sourceAudioQualityHelp(for: source))
                    StudioLED(color: source.isProducingAudio ? StudioPalette.green : StudioPalette.amber.opacity(0.75))
                }
                Text(source.isRunning ? "Running" : "Ready")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(source.isRunning ? StudioPalette.green.opacity(0.85) : .secondary)
                    .lineLimit(1)
            }
        }
    }

    private var routeAssignment: some View {
        HStack(spacing: 7) {
            StudioRouteCable(status: visualStatus, followsSystem: source.followsSystemOutput)
                .frame(width: 56)

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
            .disabled(store.isPreparingRoute(for: source))
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityLabel("\(source.appName) output")
            .accessibilityValue(store.routeOutputName(for: source))
            .accessibilityHint("Chooses the output device, then AudioRouter refreshes and prepares the route automatically")

            if store.isPreparingRoute(for: source) {
                HStack(spacing: 5) {
                    ProgressView()
                        .controlSize(.small)
                        .scaleEffect(0.68)
                    Text("Detecting")
                        .font(.system(size: 9, weight: .heavy, design: .monospaced))
                        .foregroundStyle(StudioPalette.teal)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(StudioPalette.teal.opacity(0.12), in: Capsule())
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Detecting audio source")
            } else {
                StudioLEDLabel(text: store.routeStatus(for: source), status: visualStatus)
            }
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

            Button {
                store.testRoute(for: source)
            } label: {
                Image(systemName: "speaker.wave.2.fill")
            }
            .buttonStyle(.borderless)
            .foregroundStyle(StudioPalette.amber)
            .help("Play a test tone through \(store.routeOutputName(for: source))")
            .accessibilityLabel("Test \(source.appName) route")

            InlineVolumeSlider(
                value: source.volume,
                isEnabled: store.supportsPerAppVolume,
                systemImage: "slider.horizontal.3",
                range: 0...1.5,
                accent: StudioPalette.amber,
                accessibilityLabel: "\(source.appName) gain",
                accessibilityHint: store.supportsPerAppVolume ? "Adjusts app route volume" : "Per-app gain requires an audio backend",
                onChange: { store.setSourceVolume(source: source, volume: $0) }
            )
            .frame(minWidth: 198, maxWidth: .infinity)
            .help(store.supportsPerAppVolume ? "Set source volume" : "Per-app gain requires an audio backend.")
        }
    }

    private var channelBackground: Color {
        if isDropTargeted {
            return StudioPalette.amber.opacity(0.12)
        }
        if isSelected {
            return StudioPalette.strip.opacity(0.86)
        }
        if store.routeStatusIsWarning(for: source) {
            return StudioPalette.amber.opacity(0.08)
        }
        return StudioPalette.strip.opacity(0.74)
    }

    private var rowStrokeColor: Color {
        if isDropTargeted {
            return StudioPalette.amber.opacity(0.70)
        }
        return isSelected ? StudioPalette.amber.opacity(0.58) : StudioPalette.stroke
    }

    private var rowStrokeWidth: CGFloat {
        if isDropTargeted {
            return 1.5
        }
        return isSelected ? 1.2 : 1
    }

    private var outputSelection: Binding<String> {
        Binding(
            get: { source.followsSystemOutput ? "" : (source.assignedOutputDeviceID ?? "") },
            set: { value in
                store.prepareAndAssignSourceOutput(source: source, uid: value.isEmpty ? nil : value)
            }
        )
    }
}

private struct StudioOutputActions: View {
    @ObservedObject var store: AudioRouterStore

    var body: some View {
        HStack(spacing: 8) {
            Label(
                "\(store.outputDevices.count) output device\(store.outputDevices.count == 1 ? "" : "s")",
                systemImage: "speaker.wave.2.fill"
            )
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)

            Spacer()

            Text("Drag an input app onto a device or group to route it")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
                .lineLimit(1)

            Button {
                store.createOutputGroup()
            } label: {
                Label("New Group Play", systemImage: "speaker.3.fill")
            }
            .buttonStyle(.borderedProminent)
            .tint(StudioPalette.teal)
            .accessibilityHint("Creates a group containing all currently visible outputs")
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

private struct StudioOutputStrip: View {
    let device: AudioDevice
    @ObservedObject var store: AudioRouterStore

    var body: some View {
        HStack(spacing: 8) {
            outputIdentity
                .frame(minWidth: 188, maxWidth: 260, alignment: .leading)

            StudioSegmentMeter(
                level: store.deviceMeters[device.id] ?? 0,
                segmentCount: 10,
                tint: StudioPalette.teal
            )
            .frame(width: 76, alignment: .leading)

            InlineVolumeSlider(
                value: device.volume,
                isEnabled: device.canSetVolume,
                systemImage: "slider.horizontal.3",
                accent: StudioPalette.amber,
                accessibilityLabel: "\(device.name) output volume",
                accessibilityHint: device.canSetVolume ? "Adjusts \(device.name) output volume" : "Volume is not supported by this output",
                onChange: {
                    store.selectOutputDevice(device)
                    store.setDeviceVolume(device, volume: $0)
                }
            )
            .controlSize(.small)
            .frame(width: 246, alignment: .leading)
            .help(device.canSetVolume ? "Set \(device.name) output volume" : "Volume is not supported by this output.")

            outputActions
                .frame(width: 190, alignment: .leading)

            routedSources
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 7)
        .background(
            (isSelected ? StudioPalette.amber.opacity(0.08) : StudioPalette.strip.opacity(0.72)),
            in: RoundedRectangle(cornerRadius: 6, style: .continuous)
        )
        .overlay(alignment: .leading) {
            Rectangle()
                .fill(isSelected ? StudioPalette.amber : (device.isDefault ? StudioPalette.green : StudioPalette.teal))
                .frame(width: 3)
                .clipShape(RoundedRectangle(cornerRadius: 2, style: .continuous))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .stroke(isSelected ? StudioPalette.amber.opacity(0.64) : StudioPalette.stroke, lineWidth: isSelected ? 1.4 : 1)
        }
        .contentShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        .onTapGesture {
            store.selectOutputDevice(device)
        }
        .dropDestination(for: String.self) { sourceIDs, _ in
            guard let sourceID = sourceIDs.first,
                  let source = store.audioSources.first(where: { $0.id == sourceID }) else {
                return false
            }
            store.prepareAndAssignSourceOutput(source: source, uid: device.uid)
            store.selectedSourceID = source.id
            return true
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("\(device.name), \(device.typeDescription), \(device.isDefault ? "system output" : "available output")")
        .accessibilityHint(isSelected ? "Selected for Command = and Command - volume shortcuts" : "Selects this output for Command = and Command - volume shortcuts")
    }

    private var isSelected: Bool {
        store.selectedOutputDeviceID == device.uid
    }

    private var outputIdentity: some View {
        HStack(spacing: 8) {
            DeviceIcon(device: device)
                .frame(width: 28, height: 28)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(device.name)
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)
                    StudioLED(color: device.isAlive ? StudioPalette.green : StudioPalette.red)
                }
                Text(device.typeDescription)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
    }

    private var outputActions: some View {
        HStack(spacing: 6) {
            Button {
                store.testOutput(device)
            } label: {
                Image(systemName: "speaker.wave.2.fill")
            }
            .buttonStyle(.borderless)
            .foregroundStyle(StudioPalette.amber)
            .help("Play a test tone on \(device.name)")
            .accessibilityLabel("Test \(device.name)")

            Button {
                store.selectOutputDevice(device)
                store.setDeviceMuted(device, isMuted: !(device.isMuted ?? false))
            } label: {
                Image(systemName: (device.isMuted ?? false) ? "speaker.slash.fill" : "speaker.wave.1.fill")
            }
            .buttonStyle(.borderless)
            .foregroundStyle((device.isMuted ?? false) ? StudioPalette.red : StudioPalette.teal)
            .disabled(!device.canSetMute)
            .help(device.canSetMute ? "Mute this output" : "Mute is not supported by this output")
            .accessibilityLabel((device.isMuted ?? false) ? "Unmute \(device.name)" : "Mute \(device.name)")

            Button(device.isDefault ? "System" : "Set System") {
                store.selectOutputDevice(device)
                store.setDefaultDevice(device)
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .disabled(device.isDefault)
            .accessibilityHint(device.isDefault ? "\(device.name) is already the system output" : "Makes \(device.name) the system output")
        }
    }

    @ViewBuilder
    private var routedSources: some View {
        let routed = store.routedSources(to: device)
        if routed.isEmpty {
            Text("No apps assigned")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
        } else {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(routed) { source in
                        Label(source.appName, systemImage: "app.fill")
                            .font(.caption2.weight(.semibold))
                            .padding(.horizontal, 7)
                            .padding(.vertical, 4)
                            .background(StudioPalette.teal.opacity(0.13), in: Capsule())
                    }
                }
            }
        }
    }
}

private struct StudioOutputGroupStrip: View {
    let group: OutputDeviceGroup
    @ObservedObject var store: AudioRouterStore
    @State private var isControlsPresented = false
    @State private var selectedGroupSourceID = ""

    private var connectedOutputs: [AudioDevice] {
        store.outputDevices(for: group)
    }

    var body: some View {
        Button {
            isControlsPresented = true
        } label: {
            compactCard
        }
        .buttonStyle(.plain)
        .popover(isPresented: $isControlsPresented, arrowEdge: .trailing) {
            groupControlsPopover
                .frame(width: 620)
        }
        .dropDestination(for: String.self) { sourceIDs, _ in
            guard let sourceID = sourceIDs.first,
                  let source = store.audioSources.first(where: { $0.id == sourceID }) else {
                return false
            }
            store.prepareAndAssignSourceOutput(source: source, uid: group.routeTargetID)
            store.selectedSourceID = source.id
            return true
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(group.name), group, \(connectedOutputs.count) speakers, \(routedGroupSources.count) routed apps")
        .accessibilityHint("Opens Group Play controls")
    }

    private var compactCard: some View {
        HStack(alignment: .center, spacing: 14) {
            Image(systemName: "speaker.wave.3.fill")
                .font(.system(size: 22, weight: .heavy))
                .foregroundStyle(StudioPalette.amber)
                .frame(width: 56, height: 56)
                .background(StudioPalette.amber.opacity(0.14), in: RoundedRectangle(cornerRadius: 9, style: .continuous))

            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .center, spacing: 8) {
                    Text(group.name)
                        .font(.title3.weight(.bold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    Text("GROUP")
                        .font(.system(size: 10, weight: .heavy, design: .monospaced))
                        .foregroundStyle(StudioPalette.amber)
                        .padding(.horizontal, 8)
                        .frame(height: 22)
                        .background(StudioPalette.amber.opacity(0.12), in: Capsule())
                        .overlay {
                            Capsule()
                                .stroke(StudioPalette.amber.opacity(0.25), lineWidth: 1)
                        }
                }

                Text("\(connectedOutputs.count) speaker\(connectedOutputs.count == 1 ? "" : "s") · \(routedGroupSources.count) routed app\(routedGroupSources.count == 1 ? "" : "s")")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 12)

            Image(systemName: "slider.horizontal.3")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(.secondary)
                .frame(width: 26, height: 26)
                .background(StudioPalette.inset.opacity(0.80), in: RoundedRectangle(cornerRadius: 7, style: .continuous))
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity, minHeight: 92, alignment: .leading)
        .background(StudioPalette.strip.opacity(0.72), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(StudioPalette.stroke, lineWidth: 1)
        }
        .contentShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private var groupControlsPopover: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 12) {
                Image(systemName: "speaker.3.fill")
                    .font(.system(size: 20, weight: .heavy))
                    .foregroundStyle(StudioPalette.warmInk)
                    .frame(width: 42, height: 42, alignment: .center)
                    .background(StudioPalette.amber.opacity(0.82), in: RoundedRectangle(cornerRadius: 8, style: .continuous))

                VStack(alignment: .leading, spacing: 2) {
                    Text("Group Play Controls")
                        .font(.headline.weight(.bold))
                    Text("\(connectedOutputs.count) speaker\(connectedOutputs.count == 1 ? "" : "s") · \(routedGroupSources.count) routed app\(routedGroupSources.count == 1 ? "" : "s")")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }

                Spacer()

                StudioLEDLabel(
                    text: connectedOutputs.isEmpty ? "No Devices" : "Group",
                    status: connectedOutputs.isEmpty ? .deviceMissing : .working
                )
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("NAME")
                    .font(.system(size: 8, weight: .heavy, design: .monospaced))
                    .foregroundStyle(.secondary)

                TextField("Group name", text: nameBinding)
                    .textFieldStyle(.roundedBorder)
                    .accessibilityLabel("Output group name")
            }

            groupRouteFlow

            VStack(alignment: .leading, spacing: 7) {
                Text("SPEAKERS")
                    .font(.system(size: 8, weight: .heavy, design: .monospaced))
                    .foregroundStyle(.secondary)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 7) {
                        ForEach(store.outputDevices) { device in
                            groupDeviceChip(device)
                        }
                    }
                }
            }

            HStack(spacing: 8) {
                Text("Choose a source app above, or drop a route app on the dashboard card to send it to this group.")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)

                Spacer()

                Button {
                    store.testOutputGroup(group)
                } label: {
                    Label("Test Group", systemImage: "speaker.wave.3.fill")
                }
                .controlSize(.small)
                .help("Play a test tone through each speaker in \(group.name)")

                Button {
                    store.retryRoutesUsingGroup(group)
                } label: {
                    Label("Retry", systemImage: "arrow.clockwise")
                }
                .controlSize(.small)
                .help("Retry routes assigned to \(group.name)")

                Button(role: .destructive) {
                    isControlsPresented = false
                    store.deleteOutputGroup(group)
                } label: {
                    Label("Delete", systemImage: "trash")
                }
                .controlSize(.small)
                .help("Delete group")
                .accessibilityLabel("Delete \(group.name)")
            }

            if !connectedOutputs.isEmpty {
                VStack(alignment: .leading, spacing: 7) {
                    Text("PER-SPEAKER LEVEL")
                        .font(.system(size: 8, weight: .heavy, design: .monospaced))
                        .foregroundStyle(.secondary)

                    ForEach(connectedOutputs) { device in
                        groupDeviceMixerRow(device)
                    }
                }
            }
        }
        .padding(14)
        .background(StudioPalette.panel)
    }

    private var nameBinding: Binding<String> {
        Binding(
            get: { group.name },
            set: { store.renameOutputGroup(group, to: $0) }
        )
    }

    private var groupSourceSelection: Binding<String> {
        Binding(
            get: { selectedGroupSourceID },
            set: { sourceID in
                selectedGroupSourceID = sourceID
                assignSourceToGroup(sourceID)
            }
        )
    }

    private var routedGroupSources: [AudioSource] {
        store.audioSources.filter { source in
            store.route(for: source).outputDeviceID == group.routeTargetID
        }
    }

    private var groupRouteFlow: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 12) {
                groupSourceDeck
                    .frame(minWidth: 180, maxWidth: .infinity, alignment: .leading)
                groupFanoutCable
                    .frame(width: 94)
                groupSpeakerDeck
                    .frame(minWidth: 210, maxWidth: .infinity, alignment: .leading)
            }

            VStack(alignment: .leading, spacing: 10) {
                groupSourceDeck
                groupFanoutCable
                    .frame(maxWidth: .infinity)
                groupSpeakerDeck
            }
        }
        .padding(10)
        .background(StudioPalette.inset.opacity(0.46), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(StudioPalette.amber.opacity(0.18), lineWidth: 1)
        }
    }

    private var groupSourceDeck: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text("SOURCE APPS")
                .font(.system(size: 8, weight: .heavy, design: .monospaced))
                .foregroundStyle(.secondary)

            HStack(spacing: 8) {
                Image(systemName: "app.badge")
                    .font(.system(size: 13, weight: .heavy))
                    .foregroundStyle(StudioPalette.amber)
                    .frame(width: 22, height: 22)

                Picker("Source app", selection: groupSourceSelection) {
                    Text("Choose source app").tag("")
                    ForEach(store.audioSources) { source in
                        Text(source.appName).tag(source.id)
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
                .controlSize(.small)
                .disabled(store.audioSources.isEmpty)
                .accessibilityLabel("Group Play source app")
                .accessibilityHint("Routes the selected source app to this speaker group")

                Spacer(minLength: 8)

                if !routedGroupSources.isEmpty {
                    Text("\(routedGroupSources.count) routed")
                        .font(.system(size: 8, weight: .heavy, design: .monospaced))
                        .foregroundStyle(StudioPalette.amber)
                        .padding(.horizontal, 7)
                        .frame(height: 18)
                        .background(StudioPalette.amber.opacity(0.10), in: Capsule())
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(StudioPalette.amber.opacity(0.09), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .stroke(StudioPalette.amber.opacity(0.18), lineWidth: 1)
            }

            if routedGroupSources.isEmpty {
                Text("No source apps routed yet")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
            } else {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 96), spacing: 6)], alignment: .leading, spacing: 6) {
                    ForEach(routedGroupSources) { source in
                        Label(source.appName, systemImage: "app.fill")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(StudioPalette.warmInk)
                            .padding(.horizontal, 9)
                            .padding(.vertical, 6)
                            .background(StudioPalette.amber.opacity(0.82), in: Capsule())
                    }
                }
            }
        }
    }

    private func assignSourceToGroup(_ sourceID: String) {
        guard !sourceID.isEmpty,
              let source = store.audioSources.first(where: { $0.id == sourceID }) else {
            return
        }
        store.prepareAndAssignSourceOutput(source: source, uid: group.routeTargetID)
        store.selectedSourceID = source.id
    }

    private var groupFanoutCable: some View {
        HStack(spacing: 7) {
            Capsule()
                .fill(StudioPalette.amber.opacity(0.92))
                .frame(height: 4)
            Image(systemName: "arrow.triangle.branch")
                .font(.system(size: 17, weight: .heavy))
                .foregroundStyle(StudioPalette.amber)
            Capsule()
                .fill(StudioPalette.amber.opacity(0.92))
                .frame(height: 4)
        }
        .accessibilityHidden(true)
    }

    private var groupSpeakerDeck: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text("SPEAKER GROUP")
                .font(.system(size: 8, weight: .heavy, design: .monospaced))
                .foregroundStyle(.secondary)
            if connectedOutputs.isEmpty {
                Text("No connected speakers selected")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(StudioPalette.red)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(StudioPalette.red.opacity(0.10), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
            } else {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 132), spacing: 6)], alignment: .leading, spacing: 6) {
                    ForEach(connectedOutputs) { device in
                        Label(device.name, systemImage: device.kind.systemImage)
                            .font(.caption.weight(.bold))
                            .foregroundStyle(StudioPalette.amber)
                            .padding(.horizontal, 9)
                            .padding(.vertical, 6)
                            .background(StudioPalette.amber.opacity(0.09), in: Capsule())
                            .overlay {
                                Capsule()
                                    .stroke(StudioPalette.amber.opacity(0.22), lineWidth: 1)
                            }
                    }
                }
            }
        }
    }

    private func groupDeviceChip(_ device: AudioDevice) -> some View {
        let isIncluded = group.deviceUIDs.contains(device.uid)
        return Button {
            store.setOutputGroup(group, includes: device, included: !isIncluded)
        } label: {
            HStack(spacing: 5) {
                Image(systemName: isIncluded ? "checkmark.circle.fill" : "circle")
                Text(device.name)
                    .lineLimit(1)
            }
            .font(.caption2.weight(.semibold))
            .foregroundStyle(isIncluded ? StudioPalette.warmInk : StudioPalette.amber)
            .padding(.horizontal, 9)
            .padding(.vertical, 6)
            .background(isIncluded ? StudioPalette.amber.opacity(0.82) : StudioPalette.amber.opacity(0.09), in: Capsule())
            .overlay {
                Capsule()
                    .stroke(StudioPalette.amber.opacity(isIncluded ? 0 : 0.24), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
        .help(isIncluded ? "Remove \(device.name) from \(group.name)" : "Add \(device.name) to \(group.name)")
        .accessibilityLabel("\(isIncluded ? "Remove" : "Add") \(device.name) \(isIncluded ? "from" : "to") \(group.name)")
    }

    private func groupDeviceMixerRow(_ device: AudioDevice) -> some View {
        HStack(spacing: 8) {
            DeviceIcon(device: device)
                .frame(width: 24, height: 24)
            VStack(alignment: .leading, spacing: 1) {
                Text(device.name)
                    .font(.caption.weight(.bold))
                    .lineLimit(1)
                Text(device.typeDescription)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            InlineVolumeSlider(
                value: group.perDeviceVolumes[device.uid] ?? device.volume,
                isEnabled: device.canSetVolume,
                systemImage: "slider.horizontal.3",
                accent: StudioPalette.amber,
                accessibilityLabel: "\(device.name) group volume",
                accessibilityHint: device.canSetVolume ? "Adjusts this speaker in \(group.name)" : "Volume is not supported by this output",
                onChange: { store.setOutputGroupVolume(group, deviceUID: device.uid, volume: $0) }
            )
            .frame(minWidth: 160, maxWidth: .infinity)

            Button {
                store.testOutput(device)
            } label: {
                Image(systemName: "speaker.wave.2.fill")
            }
            .buttonStyle(.borderless)
            .foregroundStyle(StudioPalette.amber)
            .help("Test \(device.name)")
            .accessibilityLabel("Test \(device.name)")
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 7)
        .background(StudioPalette.inset.opacity(0.58), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .stroke(StudioPalette.stroke, lineWidth: 1)
        }
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
        .frame(height: 20)
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
                    store.testRoute(for: source)
                } label: {
                    Label("Test Route", systemImage: "speaker.wave.2.fill")
                }
                .accessibilityHint("Plays a short test tone through \(store.routeOutputName(for: source))")
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

            InlineVolumeSlider(
                value: device.volume,
                isEnabled: device.canSetVolume,
                systemImage: "slider.horizontal.3",
                accent: StudioPalette.amber,
                accessibilityLabel: "\(device.name) output volume",
                accessibilityHint: device.canSetVolume ? "Adjusts \(device.name) output volume" : "Volume is not supported by this output",
                onChange: {
                    store.selectOutputDevice(device)
                    store.setDeviceVolume(device, volume: $0)
                }
            )
            .controlSize(.small)
            .help(device.canSetVolume ? "Set \(device.name) output volume" : "Volume is not supported by this output.")

            HStack(spacing: 8) {
                Button {
                    store.selectOutputDevice(device)
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
                    store.selectOutputDevice(device)
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
        .background(
            (isSelected ? StudioPalette.amber.opacity(0.08) : StudioPalette.strip.opacity(0.76)),
            in: RoundedRectangle(cornerRadius: 6, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .stroke(isSelected ? StudioPalette.amber.opacity(0.64) : StudioPalette.stroke, lineWidth: isSelected ? 1.4 : 1)
        }
        .contentShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        .onTapGesture {
            store.selectOutputDevice(device)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("\(device.name), \(device.typeDescription), \(device.isDefault ? "system output" : "available output")")
        .accessibilityHint(isSelected ? "Selected for Command = and Command - volume shortcuts" : "Selects this output for Command = and Command - volume shortcuts")
    }

    private var isSelected: Bool {
        store.selectedOutputDeviceID == device.uid
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
