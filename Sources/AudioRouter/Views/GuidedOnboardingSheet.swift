import SwiftUI

struct GuidedOnboardingSheet: View {
    @ObservedObject var store: AudioRouterStore
    @Environment(\.dismiss) private var dismiss
    @State private var selectedStep: GuidedSetupStep = .welcome

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
                .opacity(0.35)

            ViewThatFits(in: .horizontal) {
                HStack(spacing: 0) {
                    stepRail
                        .frame(width: 230)
                    Divider()
                        .opacity(0.35)
                    stepDetail
                }

                VStack(spacing: 0) {
                    horizontalStepRail
                    Divider()
                        .opacity(0.35)
                    stepDetail
                }
            }

            Divider()
                .opacity(0.35)
            footer
        }
        .background(OnboardingPalette.background)
        .accessibilityElement(children: .contain)
    }

    private var header: some View {
        HStack(spacing: 14) {
            AudioRouterLogo(size: 42)
            VStack(alignment: .leading, spacing: 3) {
                Text("AudioRouter Guided Setup")
                    .font(.title2.weight(.semibold))
                Text("Get devices, source apps, permission, and your first visual route ready.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            StatusBadge(text: store.settings.demoMode ? "Demo Mode" : "Live Mode", isActive: !store.settings.demoMode)
            Button {
                store.dismissOnboardingForNow()
                dismiss()
            } label: {
                Image(systemName: "xmark")
            }
            .buttonStyle(.borderless)
            .accessibilityLabel("Close guided setup")
            .accessibilityHint("Closes setup for now without marking it complete")
        }
        .padding(18)
    }

    private var stepRail: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(GuidedSetupStep.allCases) { step in
                GuidedStepButton(
                    step: step,
                    isSelected: step == selectedStep,
                    status: status(for: step)
                ) {
                    selectedStep = step
                }
            }
            Spacer(minLength: 0)
            setupSummary
        }
        .padding(14)
        .background(OnboardingPalette.rail)
    }

    private var horizontalStepRail: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 8) {
                ForEach(GuidedSetupStep.allCases) { step in
                    GuidedStepButton(
                        step: step,
                        isSelected: step == selectedStep,
                        status: status(for: step),
                        compact: true
                    ) {
                        selectedStep = step
                    }
                    .frame(width: 170)
                }
            }
            .padding(12)
        }
        .background(OnboardingPalette.rail)
    }

    private var stepDetail: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                stepHeader

                switch selectedStep {
                case .welcome:
                    welcomeStep
                case .devices:
                    devicesStep
                case .apps:
                    appsStep
                case .permission:
                    permissionStep
                case .route:
                    routeStep
                }
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var stepHeader: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: selectedStep.systemImage)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(selectedStep.tint)
                .frame(width: 38, height: 38)
                .background(selectedStep.tint.opacity(0.14), in: RoundedRectangle(cornerRadius: 10, style: .continuous))

            VStack(alignment: .leading, spacing: 4) {
                Text(selectedStep.title)
                    .font(.title3.weight(.semibold))
                Text(selectedStep.detail)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
            StatusBadge(text: status(for: selectedStep).label, isActive: status(for: selectedStep).isReady)
        }
    }

    private var welcomeStep: some View {
        VStack(alignment: .leading, spacing: 14) {
            visualPatchPreview

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 185), spacing: 10)], spacing: 10) {
                readinessCard(
                    title: "Outputs",
                    value: store.outputDevices.isEmpty ? "None found" : "\(store.outputDevices.count) ready",
                    systemImage: "speaker.wave.2.fill",
                    tint: .teal,
                    ready: !store.outputDevices.isEmpty
                )
                readinessCard(
                    title: "Source Apps",
                    value: store.audioSources.isEmpty ? "Waiting" : "\(store.audioSources.count) configured",
                    systemImage: "app.connected.to.app.below.fill",
                    tint: .blue,
                    ready: !store.audioSources.isEmpty
                )
                readinessCard(
                    title: "Engine",
                    value: store.backendReadinessTitle,
                    systemImage: "waveform.circle.fill",
                    tint: store.backendReadinessState.visualStatus.foreground,
                    ready: store.backendReadinessState == .working || store.backendReadinessState == .ready || store.backendReadinessState == .live
                )
            }

            HStack(spacing: 10) {
                Button {
                    store.refresh()
                } label: {
                    Label("Refresh Devices", systemImage: "arrow.clockwise")
                }
                Button {
                    store.settings.demoMode.toggle()
                    store.refresh()
                } label: {
                    Label(store.settings.demoMode ? "Use Live Mode" : "Preview Demo Mode", systemImage: "switch.2")
                }
            }
            .controlSize(.small)
        }
    }

    private var devicesStep: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let output = store.currentOutput {
                OnboardingDeviceRow(title: "Current Output", device: output, badge: output.isDefault ? "System" : "Selected")
            } else {
                emptyState(
                    title: "No output is visible",
                    detail: "Connect a speaker, headphones, AirPods, HDMI, USB, or use the built-in speakers, then refresh.",
                    systemImage: "speaker.slash.fill"
                )
            }

            DockCard {
                SectionHeader(title: "Available Outputs", systemImage: "speaker.wave.2.fill", trailing: "\(store.outputDevices.count)")
                ForEach(store.outputDevices.prefix(6)) { device in
                    OnboardingDeviceRow(title: device.name, device: device, badge: device.isDefault ? "Default" : "Ready")
                    if device.uid != store.outputDevices.prefix(6).last?.uid {
                        Divider()
                            .opacity(0.35)
                    }
                }
                if store.outputDevices.isEmpty {
                    Text("No output devices loaded yet.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            HStack(spacing: 10) {
                Button {
                    store.refresh()
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
                Button {
                    openSection(.devices)
                } label: {
                    Label("Open Devices", systemImage: "speaker.wave.2")
                }
            }
            .controlSize(.small)
        }
    }

    private var appsStep: some View {
        VStack(alignment: .leading, spacing: 12) {
            DockCard {
                SectionHeader(title: "Configured Source Apps", systemImage: "app.fill", trailing: "\(store.audioSources.count)")
                ForEach(store.audioSources.prefix(6)) { source in
                    OnboardingSourceRow(source: source, level: store.sourceMeters[source.id] ?? 0)
                    if source.id != store.audioSources.prefix(6).last?.id {
                        Divider()
                            .opacity(0.35)
                    }
                }
                if store.audioSources.isEmpty {
                    Text("No source apps loaded yet.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            HStack(spacing: 10) {
                Button {
                    store.refresh()
                } label: {
                    Label("Refresh Apps", systemImage: "arrow.clockwise")
                }
                Button {
                    openSection(.dashboard)
                } label: {
                    Label("Add or Reorder Apps", systemImage: "plus.app")
                }
            }
            .controlSize(.small)
        }
    }

    private var permissionStep: some View {
        VStack(alignment: .leading, spacing: 12) {
            DockCard {
                SectionHeader(title: "macOS Permission", systemImage: "checkmark.shield")
                Text("AudioRouter cannot auto-approve macOS security prompts. Use the check below to trigger the system audio recording prompt when Core Audio needs it, then approve it in System Settings.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 10) {
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
                        .padding(10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(.secondary.opacity(0.10), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
            }

            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "info.circle.fill")
                    .foregroundStyle(.blue)
                Text("Device switching and system volume work without this permission. App stream monitoring or live process-tap routing may ask for System Audio Recording.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(10)
            .background(.blue.opacity(0.10), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
    }

    private var routeStep: some View {
        VStack(alignment: .leading, spacing: 12) {
            visualPatchPreview

            DockCard {
                SectionHeader(title: "First Route", systemImage: "point.3.connected.trianglepath.dotted")
                HStack(spacing: 10) {
                    routeEndpoint(title: sampleSourceName, subtitle: "Source app", systemImage: "app.fill", tint: .blue)
                    Image(systemName: "arrow.right")
                        .font(.system(size: 18, weight: .heavy))
                        .foregroundStyle(.orange)
                    routeEndpoint(title: sampleOutputName, subtitle: "Output device", systemImage: "speaker.wave.2.fill", tint: .teal)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Text(store.backendReadinessDetail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack(spacing: 10) {
                Button {
                    openSection(.dashboard)
                } label: {
                    Label("Open Route Builder", systemImage: "arrow.left.and.right")
                }
                Button {
                    store.completeOnboarding()
                    dismiss()
                } label: {
                    Label("Finish Setup", systemImage: "checkmark")
                }
                .buttonStyle(.borderedProminent)
                .tint(.teal)
            }
            .controlSize(.small)
        }
    }

    private var visualPatchPreview: some View {
        DockCard {
            HStack(alignment: .center, spacing: 12) {
                routeEndpoint(title: sampleSourceName, subtitle: "Input app", systemImage: "app.fill", tint: .blue)
                VStack(spacing: 5) {
                    Text("ROUTE")
                        .font(.system(size: 9, weight: .heavy, design: .monospaced))
                        .foregroundStyle(.secondary)
                    Image(systemName: "arrow.right")
                        .font(.system(size: 20, weight: .heavy))
                        .foregroundStyle(.orange)
                    Circle()
                        .fill(.green)
                        .frame(width: 7, height: 7)
                        .shadow(color: .green.opacity(0.65), radius: 4)
                }
                routeEndpoint(title: sampleOutputName, subtitle: "Output", systemImage: "speaker.wave.2.fill", tint: .teal)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var footer: some View {
        HStack(spacing: 10) {
            Button {
                store.dismissOnboardingForNow()
                dismiss()
            } label: {
                Text("Continue Later")
            }

            Spacer()

            Button {
                moveStep(by: -1)
            } label: {
                Label("Back", systemImage: "chevron.left")
            }
            .disabled(selectedStep == GuidedSetupStep.allCases.first)

            Button {
                if selectedStep == GuidedSetupStep.allCases.last {
                    store.completeOnboarding()
                    dismiss()
                } else {
                    moveStep(by: 1)
                }
            } label: {
                Label(selectedStep == GuidedSetupStep.allCases.last ? "Finish" : "Next", systemImage: selectedStep == GuidedSetupStep.allCases.last ? "checkmark" : "chevron.right")
            }
            .buttonStyle(.borderedProminent)
            .tint(.teal)
        }
        .padding(14)
    }

    private var setupSummary: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Setup Status")
                .font(.caption.weight(.semibold))
            summaryRow("Outputs", status: status(for: .devices))
            summaryRow("Apps", status: status(for: .apps))
            summaryRow("Route", status: status(for: .route))
        }
        .font(.caption2)
        .foregroundStyle(.secondary)
        .padding(10)
        .background(.black.opacity(0.18), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private func summaryRow(_ title: String, status: GuidedStepStatus) -> some View {
        HStack(spacing: 7) {
            Image(systemName: status.systemImage)
                .foregroundStyle(status.tint)
            Text(title)
            Spacer()
            Text(status.label)
        }
    }

    private func readinessCard(title: String, value: String, systemImage: String, tint: Color, ready: Bool) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: systemImage)
                    .foregroundStyle(tint)
                Spacer()
                Image(systemName: ready ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                    .foregroundStyle(ready ? .green : .orange)
            }
            Text(title.uppercased())
                .font(.system(size: 9, weight: .heavy, design: .monospaced))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.headline)
                .lineLimit(1)
        }
        .padding(12)
        .background(OnboardingPalette.card, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(.white.opacity(0.08), lineWidth: 1)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title), \(value)")
    }

    private func routeEndpoint(title: String, subtitle: String, systemImage: String, tint: Color) -> some View {
        HStack(spacing: 10) {
            Image(systemName: systemImage)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 32, height: 32)
                .background(tint.opacity(0.14), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                Text(subtitle.uppercased())
                    .font(.system(size: 8, weight: .heavy, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(OnboardingPalette.card, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(.white.opacity(0.08), lineWidth: 1)
        }
    }

    private func emptyState(title: String, detail: String, systemImage: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: systemImage)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(.orange)
                .frame(width: 36, height: 36)
                .background(.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.headline)
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(OnboardingPalette.card, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func status(for step: GuidedSetupStep) -> GuidedStepStatus {
        switch step {
        case .welcome:
            return .ready
        case .devices:
            return store.outputDevices.isEmpty ? .needsAction : .ready
        case .apps:
            return store.audioSources.isEmpty ? .needsAction : .ready
        case .permission:
            return store.processTapProbeMessage == nil ? .optional : .ready
        case .route:
            if store.activeLiveRouteCount > 0 {
                return .ready
            }
            return store.savedCustomRouteCount > 0 ? .saved : .optional
        }
    }

    private var sampleSourceName: String {
        store.audioSources.first?.appName ?? "Spotify"
    }

    private var sampleOutputName: String {
        store.currentOutput?.name ?? "System Output"
    }

    private func openSection(_ section: SettingsSection) {
        store.selectedSettingsSection = section
        store.dismissOnboardingForNow()
        dismiss()
    }

    private func moveStep(by offset: Int) {
        let steps = GuidedSetupStep.allCases
        guard let current = steps.firstIndex(of: selectedStep) else { return }
        let next = min(max(current + offset, steps.startIndex), steps.index(before: steps.endIndex))
        selectedStep = steps[next]
    }
}

private enum GuidedSetupStep: Int, CaseIterable, Identifiable {
    case welcome
    case devices
    case apps
    case permission
    case route

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .welcome: return "Welcome"
        case .devices: return "Audio Devices"
        case .apps: return "Source Apps"
        case .permission: return "Permission"
        case .route: return "First Route"
        }
    }

    var detail: String {
        switch self {
        case .welcome: return "A quick readiness pass before you start routing sound."
        case .devices: return "Check which outputs AudioRouter can see right now."
        case .apps: return "Confirm the apps that appear as routeable sources."
        case .permission: return "Prepare macOS audio recording permission for process monitoring."
        case .route: return "Open the visual Route Builder and connect an app to an output."
        }
    }

    var systemImage: String {
        switch self {
        case .welcome: return "sparkles.rectangle.stack"
        case .devices: return "speaker.wave.2.fill"
        case .apps: return "app.connected.to.app.below.fill"
        case .permission: return "checkmark.shield.fill"
        case .route: return "point.3.connected.trianglepath.dotted"
        }
    }

    var tint: Color {
        switch self {
        case .welcome: return .teal
        case .devices: return .cyan
        case .apps: return .blue
        case .permission: return .green
        case .route: return .orange
        }
    }
}

private enum GuidedStepStatus {
    case ready
    case saved
    case optional
    case needsAction

    var label: String {
        switch self {
        case .ready: return "Ready"
        case .saved: return "Saved"
        case .optional: return "Optional"
        case .needsAction: return "Needs Action"
        }
    }

    var isReady: Bool {
        switch self {
        case .ready, .saved: return true
        case .optional, .needsAction: return false
        }
    }

    var systemImage: String {
        switch self {
        case .ready: return "checkmark.circle.fill"
        case .saved: return "tray.and.arrow.down.fill"
        case .optional: return "circle.dashed"
        case .needsAction: return "exclamationmark.circle.fill"
        }
    }

    var tint: Color {
        switch self {
        case .ready: return .green
        case .saved: return .orange
        case .optional: return .secondary
        case .needsAction: return .orange
        }
    }
}

private struct GuidedStepButton: View {
    let step: GuidedSetupStep
    let isSelected: Bool
    let status: GuidedStepStatus
    var compact = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: step.systemImage)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(step.tint)
                    .frame(width: 30, height: 30)
                    .background(step.tint.opacity(0.14), in: RoundedRectangle(cornerRadius: 8, style: .continuous))

                VStack(alignment: .leading, spacing: 2) {
                    Text(step.title)
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)
                    if !compact {
                        Text(status.label)
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(status.tint)
                    }
                }

                Spacer(minLength: 0)

                Image(systemName: status.systemImage)
                    .foregroundStyle(status.tint)
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(isSelected ? step.tint.opacity(0.14) : Color.white.opacity(0.035), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(isSelected ? step.tint.opacity(0.55) : Color.white.opacity(0.07), lineWidth: isSelected ? 1.3 : 1)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(step.title), \(status.label)")
    }
}

private struct OnboardingDeviceRow: View {
    let title: String
    let device: AudioDevice
    let badge: String

    var body: some View {
        HStack(spacing: 10) {
            DeviceIcon(device: device)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                Text("\(device.typeDescription) · \(device.sampleRateDescription)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer()
            StatusBadge(text: badge, isActive: device.isDefault)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title), \(device.typeDescription), \(badge)")
    }
}

private struct OnboardingSourceRow: View {
    let source: AudioSource
    let level: Double

    var body: some View {
        HStack(spacing: 10) {
            AppSourceIcon(source: source)
            VStack(alignment: .leading, spacing: 2) {
                Text(source.appName)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                Text(source.bundleIdentifier ?? "No bundle identifier")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer()
            MiniOnboardingMeter(level: level)
                .frame(width: 54)
            StatusBadge(text: source.isRunning ? "Running" : "Ready", isActive: source.isRunning)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(source.appName), \(source.isRunning ? "running" : "ready")")
    }
}

private struct MiniOnboardingMeter: View {
    let level: Double

    var body: some View {
        HStack(alignment: .bottom, spacing: 2) {
            ForEach(0..<7, id: \.self) { index in
                let threshold = Double(index + 1) / 7
                RoundedRectangle(cornerRadius: 1.5, style: .continuous)
                    .fill(threshold <= level.clampedUnit ? Color.green : Color.white.opacity(0.13))
                    .frame(width: 4, height: 7 + CGFloat(index * 2))
            }
        }
        .frame(height: 22, alignment: .bottom)
        .accessibilityHidden(true)
    }
}

private enum OnboardingPalette {
    static let background = Color(red: 0.045, green: 0.047, blue: 0.052)
    static let rail = Color(red: 0.060, green: 0.063, blue: 0.070)
    static let card = Color(red: 0.086, green: 0.089, blue: 0.096)
}

#if DEBUG
struct GuidedOnboardingSheet_Previews: PreviewProvider {
    @MainActor
    static var previews: some View {
        GuidedOnboardingSheet(store: PreviewSupport.demoStore())
            .frame(width: 860, height: 620)
            .preferredColorScheme(.dark)
    }
}
#endif
