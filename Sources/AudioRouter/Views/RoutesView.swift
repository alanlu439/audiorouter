import SwiftUI

struct RoutesView: View {
    @ObservedObject var store: AudioRouterStore
    @State private var searchText = ""

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let isCompact = width < 760
            let useCompactRows = width < 980

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    MixerPanelView(store: store, isCompact: isCompact)

                    DisclosureGroup {
                        RouteComposerView(store: store, isCompact: isCompact)
                            .padding(.top, 8)
                    } label: {
                        Label("Batch Routing and Output Groups", systemImage: "slider.horizontal.3")
                            .font(.headline)
                    }
                    .padding(14)
                    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))

                    if filteredRoutes.isEmpty {
                        ContentUnavailableView(
                            store.routes.isEmpty ? "Nothing connected" : "No matches",
                            systemImage: "arrow.triangle.branch",
                            description: Text(store.routes.isEmpty ? "Choose an app and output above." : "Clear the search field.")
                        )
                        .frame(maxWidth: .infinity, minHeight: 260)
                    } else {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Connected")
                                .font(.headline)
                                .foregroundStyle(.secondary)

                            ForEach(filteredRoutes) { route in
                                RouteRowView(store: store, route: route, isCompact: useCompactRows)
                            }
                        }
                    }
                }
                .padding(isCompact ? 14 : 24)
            }
        }
        .navigationTitle("Home")
        .searchable(text: $searchText, placement: .toolbar, prompt: "Search connections")
    }

    private var filteredRoutes: [RouteRule] {
        guard !searchText.isEmpty else { return store.routes }
        return store.routes.filter { route in
            route.processDisplayName.localizedCaseInsensitiveContains(searchText)
                || route.deviceName.localizedCaseInsensitiveContains(searchText)
                || (route.bundleID?.localizedCaseInsensitiveContains(searchText) ?? false)
        }
    }
}

private struct MixerPanelView: View {
    @ObservedObject var store: AudioRouterStore
    let isCompact: Bool

    var body: some View {
        VStack(spacing: 0) {
            header
                .padding(16)

            Divider()

            if let defaultOutput = store.devices.first(where: \.isDefaultOutput) ?? store.devices.first(where: \.isRoutableOutput) {
                MixerDeviceRow(store: store, device: defaultOutput, isCompact: isCompact)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
            } else {
                ContentUnavailableView("No output", systemImage: "speaker.slash")
                    .frame(maxWidth: .infinity, minHeight: 76)
            }

            Divider()

            HStack {
                Text("Applications")
                    .font(.headline)
                Spacer()
                Text("\(store.applications.count)")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)

            if store.applications.isEmpty {
                ContentUnavailableView("No applications", systemImage: "app.dashed")
                    .frame(maxWidth: .infinity, minHeight: 120)
            } else {
                VStack(spacing: 0) {
                    ForEach(store.applications) { application in
                        Divider()
                        MixerApplicationRow(store: store, application: application, isCompact: isCompact)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                    }
                }
            }
        }
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color.secondary.opacity(0.18), lineWidth: 1)
                .allowsHitTesting(false)
        }
    }

    private var header: some View {
        HStack(spacing: 14) {
            AudioRouterLogo(size: .compact)

            VStack(alignment: .leading, spacing: 4) {
                Text("AudioRouter")
                    .font(.system(size: 24, weight: .semibold))
                    .lineLimit(1)

                Text(summary)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Spacer()

            Button {
                store.refresh()
            } label: {
                Label("Refresh", systemImage: "arrow.clockwise")
            }
            .buttonStyle(.bordered)
        }
    }

    private var summary: String {
        let active = store.routes.filter(\.isEnabled).count
        let routable = store.devices.filter(\.isRoutableOutput).count
        if active == 0 {
            return routable == 0 ? "Connect an output in macOS, then refresh." : "\(routable) outputs available"
        }
        return "\(active) active app route\(active == 1 ? "" : "s")"
    }
}

private struct MixerDeviceRow: View {
    @ObservedObject var store: AudioRouterStore
    let device: AudioDeviceInfo
    let isCompact: Bool

    var body: some View {
        if isCompact {
            VStack(alignment: .leading, spacing: 10) {
                deviceIdentity
                outputSelector
                HStack(spacing: 12) {
                    deviceVolumeControl
                    muteControl
                }
            }
        } else {
            HStack(spacing: 14) {
                deviceIdentity
                    .frame(minWidth: 210, maxWidth: .infinity, alignment: .leading)
                outputSelector
                deviceVolumeControl
                    .frame(width: 260)
                muteControl
            }
        }
    }

    private var deviceIdentity: some View {
        MixerIdentity(
            title: currentDevice.name,
            subtitle: currentDevice.isDefaultOutput ? "System Output" : currentDevice.transport.rawValue,
            systemImage: currentDevice.transport == .bluetooth || currentDevice.transport == .bluetoothLE ? "headphones" : "speaker.wave.2.fill",
            tint: .teal
        )
    }

    private var outputSelector: some View {
        Menu {
            ForEach(store.devices.filter(\.isRoutableOutput)) { output in
                Button {
                    store.setDefaultOutput(output)
                } label: {
                    Label(output.name, systemImage: output.isDefaultOutput ? "checkmark.circle.fill" : "speaker.wave.2")
                }
            }
        } label: {
            Label(currentDevice.name, systemImage: "speaker.wave.2")
                .lineLimit(1)
        }
        .frame(minWidth: isCompact ? 0 : 160, alignment: .leading)
    }

    private var deviceVolumeControl: some View {
        MixerVolumeControl(
            level: Float(currentDevice.outputVolume ?? 0),
            isActive: currentDevice.canSetVolume && currentDevice.isMuted != true,
            volume: volumeBinding,
            range: 0...1,
            accent: .teal,
            isEnabled: currentDevice.canSetVolume,
            isMuted: currentDevice.isMuted == true
        )
    }

    private var muteControl: some View {
        Button {
            store.setDeviceMuted(currentDevice, isMuted: !(currentDevice.isMuted ?? false))
        } label: {
            Image(systemName: currentDevice.isMuted == true ? "speaker.slash.fill" : "speaker.wave.2.fill")
        }
        .buttonStyle(.bordered)
        .disabled(!currentDevice.canSetMute)
        .help(currentDevice.isMuted == true ? "Unmute output" : "Mute output")
    }

    private var currentDevice: AudioDeviceInfo {
        store.devices.first { $0.uid == device.uid } ?? device
    }

    private var volumeBinding: Binding<Double> {
        Binding(
            get: {
                currentDevice.outputVolume ?? 0
            },
            set: { newValue in
                store.setDeviceVolume(currentDevice, volume: newValue)
            }
        )
    }

}

private struct MixerApplicationRow: View {
    @ObservedObject var store: AudioRouterStore
    let application: AppSoundSource
    let isCompact: Bool

    var body: some View {
        if isCompact {
            VStack(alignment: .leading, spacing: 10) {
                identity
                outputSelector
                HStack(spacing: 12) {
                    routeVolumeControl
                    enableControl
                    muteButton
                }
            }
        } else {
            HStack(spacing: 14) {
                identity
                    .frame(minWidth: 210, maxWidth: .infinity, alignment: .leading)
                outputSelector
                    .frame(width: 170, alignment: .leading)
                routeVolumeControl
                    .frame(width: 260)
                enableControl
                muteButton
            }
        }
    }

    private var identity: some View {
        MixerIdentity(
            title: application.displayName,
            subtitle: application.isRunningOutput ? "Playing" : (application.isRunning ? "Running" : "Ready"),
            systemImage: application.isRunningOutput ? "waveform" : "app.fill",
            tint: .blue
        )
    }

    private var outputSelector: some View {
        Menu {
            if !store.outputGroups.isEmpty {
                Section("Output Groups") {
                    ForEach(store.outputGroups) { group in
                        Button {
                            store.connect(applications: [application], outputGroup: group)
                        } label: {
                            Label(group.name, systemImage: "speaker.3.fill")
                        }
                    }
                }
            }

            Section("Outputs") {
                ForEach(store.devices.filter(\.isRoutableOutput)) { device in
                    Button {
                        store.connect(applications: [application], devices: [device])
                    } label: {
                        Label(device.name, systemImage: device.transport == .bluetooth || device.transport == .bluetoothLE ? "headphones" : "speaker.wave.2")
                    }
                }
            }
        } label: {
            Label(outputTitle, systemImage: routes.count > 1 ? "speaker.3.fill" : "speaker.wave.2")
                .lineLimit(1)
        }
    }

    private var routeVolumeControl: some View {
        MixerVolumeControl(
            level: level,
            isActive: isEnabled,
            volume: volumeBinding,
            range: 0...1.5,
            accent: .blue,
            isEnabled: canControlVolume,
            isMuted: volume <= 0
        )
    }

    private var enableControl: some View {
        Toggle("Enabled", isOn: enabledBinding)
            .toggleStyle(.switch)
            .labelsHidden()
            .disabled(routes.isEmpty)
    }

    private var muteButton: some View {
        Button {
            setVolume(volume <= 0 ? 1 : 0)
        } label: {
            Image(systemName: volume <= 0 ? "speaker.slash.fill" : "speaker.wave.2.fill")
        }
        .buttonStyle(.bordered)
        .disabled(!canControlVolume)
        .help(volume <= 0 ? "Restore app volume" : "Mute app route")
    }

    private var routes: [RouteRule] {
        store.routes.filter { route in
            if let bundleID = application.bundleID, route.bundleID == bundleID {
                return true
            }
            if let processObjectID = application.processObjectID, route.processObjectID == processObjectID {
                return true
            }
            return route.processDisplayName == application.displayName
        }
    }

    private var outputTitle: String {
        switch routes.count {
        case 0:
            return "Choose Output"
        case 1:
            return store.deviceName(for: routes[0].deviceUID)
        default:
            return "\(routes.count) Outputs"
        }
    }

    private var volume: Double {
        guard !routes.isEmpty else { return 1 }
        return routes.map(\.volume).reduce(0, +) / Double(routes.count)
    }

    private var level: Float {
        routes.map { store.routeLevels[$0.id] ?? 0 }.max() ?? 0
    }

    private var isEnabled: Bool {
        routes.contains(where: \.isEnabled)
    }

    private var canControlVolume: Bool {
        !routes.isEmpty || defaultOutput != nil
    }

    private var defaultOutput: AudioDeviceInfo? {
        store.devices.first { $0.isDefaultOutput && $0.isRoutableOutput }
            ?? store.devices.first(where: \.isRoutableOutput)
    }

    private var volumeBinding: Binding<Double> {
        Binding(
            get: {
                volume
            },
            set: { newValue in
                setVolume(newValue)
            }
        )
    }

    private var enabledBinding: Binding<Bool> {
        Binding(
            get: {
                isEnabled
            },
            set: { newValue in
                for route in routes {
                    store.setRouteEnabled(route, isEnabled: newValue)
                }
            }
        )
    }

    private func setVolume(_ newValue: Double) {
        let targetRoutes = controllableRoutes()
        for route in targetRoutes {
            store.setRouteVolume(route, volume: newValue)
        }
    }

    private func controllableRoutes() -> [RouteRule] {
        if !routes.isEmpty {
            return routes
        }
        guard let defaultOutput else { return [] }
        store.connect(applications: [application], devices: [defaultOutput])
        return routes
    }
}

private struct MixerVolumeControl: View {
    let level: Float
    let isActive: Bool
    @Binding var volume: Double
    let range: ClosedRange<Double>
    let accent: Color
    let isEnabled: Bool
    let isMuted: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 8) {
                Image(systemName: isMuted || volume <= 0 ? "speaker.slash.fill" : "speaker.wave.2.fill")
                    .font(.caption)
                    .foregroundStyle(isEnabled ? accent : .secondary)
                    .frame(width: 18)

                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.secondary.opacity(0.16))
                        Capsule()
                            .fill(accent.opacity(isEnabled ? 0.30 : 0.12))
                            .frame(width: geometry.size.width * CGFloat(volumeProgress))
                        Capsule()
                            .fill(accent.opacity(isActive ? 0.82 : 0.26))
                            .frame(width: geometry.size.width * CGFloat(levelProgress))
                    }
                }
                .frame(height: 8)
                .accessibilityHidden(true)

                Text("\(Int(volume * 100))%")
                    .font(.caption.monospacedDigit().weight(.medium))
                    .foregroundStyle(isEnabled ? .secondary : Color.secondary.opacity(0.55))
                    .frame(width: 46, alignment: .trailing)
            }

            Slider(value: $volume, in: range)
                .controlSize(.small)
                .disabled(!isEnabled)
        }
        .opacity(isEnabled ? 1 : 0.62)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Volume")
        .accessibilityValue("\(Int(volume * 100)) percent")
    }

    private var volumeProgress: Double {
        guard range.upperBound > range.lowerBound else { return 0 }
        return max(0, min((volume - range.lowerBound) / (range.upperBound - range.lowerBound), 1))
    }

    private var levelProgress: Double {
        guard isActive else { return 0 }
        return max(0, min(Double(level), 1))
    }
}

private struct MixerIdentity: View {
    let title: String
    let subtitle: String
    let systemImage: String
    let tint: Color

    var body: some View {
        HStack(spacing: 11) {
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(tint.opacity(0.14))
                Image(systemName: systemImage)
                    .font(.title3)
                    .foregroundStyle(tint)
            }
            .frame(width: 38, height: 38)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.headline)
                    .lineLimit(1)

                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
    }
}

private struct RouteComposerView: View {
    @ObservedObject var store: AudioRouterStore
    let isCompact: Bool
    @State private var selectedApplicationIDs: [String] = []
    @State private var selectedDeviceUIDs: [String] = []
    @State private var appSearchText = ""
    @State private var speakerSearchText = ""
    @State private var outputGroupName = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            stepHeader

            selectionPanels

            outputGroupTools

            ConnectionPreview(applications: selectedApplications, devices: selectedDevices, isCompact: isCompact)

            actionButtons
        }
        .padding(16)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
    }

    @ViewBuilder
    private var stepHeader: some View {
        if isCompact {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    StepBadge(number: 1, title: "Inputs", isComplete: !selectedApplications.isEmpty)
                    StepBadge(number: 2, title: "Outputs", isComplete: !selectedDevices.isEmpty)
                    StepBadge(number: 3, title: "Connect", isComplete: canConnect)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Label("App only", systemImage: "checkmark.shield")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        } else {
            HStack(spacing: 12) {
                StepBadge(number: 1, title: "Inputs", isComplete: !selectedApplications.isEmpty)
                Image(systemName: "arrow.right")
                    .foregroundStyle(.secondary)
                StepBadge(number: 2, title: "Outputs", isComplete: !selectedDevices.isEmpty)
                Image(systemName: "arrow.right")
                    .foregroundStyle(.secondary)
                StepBadge(number: 3, title: "Connect", isComplete: canConnect)

                Spacer()

                Label("App only", systemImage: "checkmark.shield")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private var selectionPanels: some View {
        if isCompact {
            VStack(spacing: 12) {
                inputPanel

                Image(systemName: "arrow.down")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(.secondary)

                outputPanel
            }
        } else {
            HStack(alignment: .center, spacing: 16) {
                inputPanel

                Image(systemName: "arrow.right")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(.secondary)

                outputPanel
            }
        }
    }

    private var inputPanel: some View {
        VisualSelectionPanel(
            title: "Inputs",
            detail: selectedApplications.isEmpty ? "Choose apps" : "\(selectedApplications.count) selected",
            systemImage: "app",
            accent: .blue,
            searchText: $appSearchText,
            searchPrompt: "Find app"
        ) {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: isCompact ? 112 : 132), spacing: 10)], spacing: 10) {
                ForEach(filteredApplications) { application in
                    AppTile(
                        application: application,
                        selectionIndex: selectionIndex(for: application)
                    ) {
                        toggleApplication(application)
                    }
                }
            }
        }
    }

    private var outputPanel: some View {
        VisualSelectionPanel(
            title: "Outputs",
            detail: selectedDevices.isEmpty ? "Choose outputs" : "\(selectedDevices.count) selected",
            systemImage: "speaker.wave.2",
            accent: .teal,
            searchText: $speakerSearchText,
            searchPrompt: "Find output"
        ) {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: isCompact ? 112 : 132), spacing: 10)], spacing: 10) {
                ForEach(filteredOutputs) { device in
                    SpeakerTile(
                        device: device,
                        selectionIndex: selectionIndex(for: device)
                    ) {
                        toggleDevice(device)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var actionButtons: some View {
        if isCompact {
            VStack(spacing: 10) {
                refreshButton
                    .frame(maxWidth: .infinity)
                connectButton
                    .frame(maxWidth: .infinity)
            }
        } else {
            HStack(spacing: 10) {
                refreshButton
                Spacer()
                connectButton
            }
        }
    }

    private var refreshButton: some View {
        Button {
            store.refresh()
        } label: {
            Label("Refresh", systemImage: "arrow.clockwise")
        }
        .buttonStyle(.bordered)
    }

    private var connectButton: some View {
        Button {
            store.connect(applications: selectedApplications, devices: selectedDevices)
            selectedApplicationIDs.removeAll()
            selectedDeviceUIDs.removeAll()
        } label: {
            Label(connectButtonTitle, systemImage: "cable.connector")
        }
        .controlSize(.large)
        .buttonStyle(.borderedProminent)
        .disabled(!canConnect)
    }

    private var outputGroupTools: some View {
        VStack(alignment: .leading, spacing: 10) {
            if !store.outputGroups.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(store.outputGroups) { group in
                            HStack(spacing: 4) {
                                Button {
                                    selectedDeviceUIDs = group.deviceUIDs.filter { uid in
                                        store.devices.contains { $0.uid == uid && $0.isRoutableOutput }
                                    }
                                } label: {
                                    Label("\(group.name) · \(group.deviceUIDs.count)", systemImage: "speaker.3.fill")
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.small)

                                Button(role: .destructive) {
                                    store.removeOutputGroup(group)
                                } label: {
                                    Label("Delete \(group.name)", systemImage: "xmark")
                                }
                                .buttonStyle(.borderless)
                                .labelStyle(.iconOnly)
                                .controlSize(.small)
                            }
                        }
                    }
                }
            }

            if selectedDevices.count > 1 {
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 8) {
                        groupNameField
                        saveGroupButton
                    }

                    VStack(spacing: 8) {
                        groupNameField
                        saveGroupButton
                    }
                }
            }
        }
    }

    private var groupNameField: some View {
        TextField("Group name", text: $outputGroupName)
            .textFieldStyle(.roundedBorder)
            .frame(minWidth: 180)
    }

    private var saveGroupButton: some View {
        Button {
            store.createOutputGroup(name: outputGroupName, deviceUIDs: selectedDeviceUIDs)
            outputGroupName = ""
        } label: {
            Label("Save Output Group", systemImage: "plus.square.on.square")
        }
        .buttonStyle(.bordered)
        .disabled(selectedDevices.count < 2)
    }

    private var availableOutputs: [AudioDeviceInfo] {
        store.devices.filter(\.isRoutableOutput)
    }

    private var filteredApplications: [AppSoundSource] {
        guard !appSearchText.isEmpty else { return store.applications }
        return store.applications.filter { application in
            application.displayName.localizedCaseInsensitiveContains(appSearchText)
                || (application.bundleID?.localizedCaseInsensitiveContains(appSearchText) ?? false)
        }
    }

    private var filteredOutputs: [AudioDeviceInfo] {
        guard !speakerSearchText.isEmpty else { return availableOutputs }
        return availableOutputs.filter { device in
            device.name.localizedCaseInsensitiveContains(speakerSearchText)
                || device.transport.rawValue.localizedCaseInsensitiveContains(speakerSearchText)
        }
    }

    private var selectedApplications: [AppSoundSource] {
        selectedApplicationIDs.compactMap { id in
            store.applications.first { $0.id == id }
        }
    }

    private var selectedDevices: [AudioDeviceInfo] {
        selectedDeviceUIDs.compactMap { uid in
            store.devices.first { $0.uid == uid }
        }
    }

    private var canConnect: Bool {
        !selectedApplications.isEmpty && !selectedDevices.isEmpty
    }

    private var connectButtonTitle: String {
        let count = selectedApplications.count * selectedDevices.count
        return count <= 1 ? "Connect" : "Connect \(count) routes"
    }

    private func toggleApplication(_ application: AppSoundSource) {
        if let index = selectedApplicationIDs.firstIndex(of: application.id) {
            selectedApplicationIDs.remove(at: index)
        } else {
            selectedApplicationIDs.append(application.id)
        }
    }

    private func toggleDevice(_ device: AudioDeviceInfo) {
        if let index = selectedDeviceUIDs.firstIndex(of: device.uid) {
            selectedDeviceUIDs.remove(at: index)
        } else {
            selectedDeviceUIDs.append(device.uid)
        }
    }

    private func selectionIndex(for application: AppSoundSource) -> Int? {
        selectedApplicationIDs.firstIndex(of: application.id).map { $0 + 1 }
    }

    private func selectionIndex(for device: AudioDeviceInfo) -> Int? {
        selectedDeviceUIDs.firstIndex(of: device.uid).map { $0 + 1 }
    }
}

private struct StepBadge: View {
    let number: Int
    let title: String
    let isComplete: Bool

    var body: some View {
        HStack(spacing: 7) {
            ZStack {
                Circle()
                    .fill(isComplete ? Color.green.opacity(0.18) : Color.secondary.opacity(0.14))
                Image(systemName: isComplete ? "checkmark" : "\(number).circle")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(isComplete ? .green : .secondary)
            }
            .frame(width: 24, height: 24)

            Text(title)
                .font(.callout.weight(.medium))
                .foregroundStyle(isComplete ? .primary : .secondary)
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 6)
        .background(.quaternary, in: Capsule())
    }
}

private struct ConnectionPreview: View {
    let applications: [AppSoundSource]
    let devices: [AudioDeviceInfo]
    let isCompact: Bool

    var body: some View {
        Group {
            if isCompact {
                VStack(alignment: .leading, spacing: 10) {
                    appNode

                    Image(systemName: "arrow.down")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)

                    outputNode
                }
            } else {
                HStack(spacing: 14) {
                    appNode

                    Image(systemName: "arrow.right")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(.secondary)

                    outputNode

                    Spacer()
                }
            }
        }
        .padding(12)
        .background(.quaternary.opacity(0.6), in: RoundedRectangle(cornerRadius: 8))
    }

    private var appNode: some View {
        PreviewNode(
            title: title(forApplications: applications),
            systemImage: applications.isEmpty ? "app.dashed" : "app.fill",
            tint: .blue,
            isSelected: !applications.isEmpty
        )
    }

    private var outputNode: some View {
        PreviewNode(
            title: title(forDevices: devices),
            systemImage: devices.isEmpty ? "speaker.slash" : "headphones",
            tint: .teal,
            isSelected: !devices.isEmpty
        )
    }

    private func title(forApplications applications: [AppSoundSource]) -> String {
        switch applications.count {
        case 0:
            return "Choose inputs"
        case 1:
            return applications[0].displayName
        default:
            return "\(applications.count) apps"
        }
    }

    private func title(forDevices devices: [AudioDeviceInfo]) -> String {
        switch devices.count {
        case 0:
            return "Choose outputs"
        case 1:
            return devices[0].name
        default:
            return "\(devices.count) outputs"
        }
    }
}

private struct PreviewNode: View {
    let title: String
    let systemImage: String
    let tint: Color
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 9) {
            Image(systemName: systemImage)
                .font(.title3)
                .foregroundStyle(isSelected ? tint : .secondary)
                .frame(width: 28)

            Text(title)
                .font(.headline)
                .lineLimit(1)
                .foregroundStyle(isSelected ? .primary : .secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct RouteRowView: View {
    @ObservedObject var store: AudioRouterStore
    let route: RouteRule
    let isCompact: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            if isCompact {
                compactRouteLayout
            } else {
                regularRouteLayout
            }

            if let lastError = route.lastError, !lastError.isEmpty {
                Label(lastError, systemImage: "exclamationmark.triangle")
                    .foregroundStyle(.red)
                    .font(.callout)
            }
        }
        .padding(16)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
    }

    private var regularRouteLayout: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 16) {
                appEndpoint

                Image(systemName: "arrow.right")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.secondary)

                outputEndpoint

                Spacer()

                routeVolumeControl

                routeToggle

                deleteButton
            }

            HStack(spacing: 10) {
                routeStatus

                Spacer()

                outputShortcuts
            }
        }
    }

    private var compactRouteLayout: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 8) {
                appEndpoint

                Image(systemName: "arrow.down")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)

                outputEndpoint
            }

            routeVolumeControl

            HStack(spacing: 10) {
                routeStatus

                Spacer()

                routeToggle
                deleteButton
            }

            ScrollView(.horizontal, showsIndicators: false) {
                outputShortcuts
            }
        }
    }

    private var appEndpoint: some View {
        ConnectionEndpoint(
            title: route.processDisplayName,
            detail: route.bundleID ?? "Application",
            systemImage: "app",
            isCompact: isCompact
        )
    }

    private var outputEndpoint: some View {
        ConnectionEndpoint(
            title: store.deviceName(for: route.deviceUID),
            detail: isBluetoothRoute ? "Bluetooth speaker" : "Output device",
            systemImage: isBluetoothRoute ? "headphones" : "speaker.wave.2",
            isCompact: isCompact
        )
    }

    private var routeVolumeControl: some View {
        RouteVolumeControl(
            level: store.routeLevels[route.id] ?? 0,
            isActive: route.status == .running,
            volume: bindingVolume,
            isCompact: isCompact
        )
    }

    private var routeStatus: some View {
        HStack(spacing: 10) {
            StatusPill(title: route.status.rawValue, systemImage: route.status.systemImage)

            Label("App only", systemImage: "checkmark.shield")
                .font(.callout)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
    }

    private var outputShortcuts: some View {
        HStack(spacing: 10) {
            ForEach(preferredOutputs.prefix(4)) { device in
                Button {
                    store.updateRoute(route, deviceUID: device.uid, muteOriginal: true)
                } label: {
                    Label(device.name, systemImage: device.transport == .bluetooth || device.transport == .bluetoothLE ? "headphones" : "speaker.wave.2")
                        .lineLimit(1)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
    }

    private var routeToggle: some View {
        Toggle("Enabled", isOn: bindingEnabled)
            .toggleStyle(.switch)
    }

    private var deleteButton: some View {
        Button(role: .destructive) {
            store.removeRoute(route)
        } label: {
            Label("Delete", systemImage: "trash")
        }
        .labelStyle(.iconOnly)
    }

    private var isBluetoothRoute: Bool {
        guard let deviceUID = route.deviceUID,
              let device = store.devices.first(where: { $0.uid == deviceUID }) else {
            return route.deviceName.localizedCaseInsensitiveContains("bluetooth")
        }
        return device.transport == .bluetooth || device.transport == .bluetoothLE
    }

    private var preferredOutputs: [AudioDeviceInfo] {
        store.devices.filter(\.isRoutableOutput)
    }

    private var bindingEnabled: Binding<Bool> {
        Binding(
            get: {
                store.routes.first(where: { $0.id == route.id })?.isEnabled ?? false
            },
            set: { newValue in
                store.setRouteEnabled(route, isEnabled: newValue)
            }
        )
    }

    private var bindingVolume: Binding<Double> {
        Binding(
            get: {
                store.routes.first(where: { $0.id == route.id })?.volume ?? 1
            },
            set: { newValue in
                store.setRouteVolume(route, volume: newValue)
            }
        )
    }

}

private struct RouteVolumeControl: View {
    let level: Float
    let isActive: Bool
    @Binding var volume: Double
    let isCompact: Bool

    var body: some View {
        MixerVolumeControl(
            level: level,
            isActive: isActive,
            volume: $volume,
            range: 0...1.5,
            accent: .blue,
            isEnabled: true,
            isMuted: volume <= 0
        )
        .frame(minWidth: isCompact ? 0 : 240, maxWidth: isCompact ? .infinity : 240, alignment: .trailing)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Route volume")
        .accessibilityValue("\(Int(volume * 100)) percent")
    }
}

private struct ConnectionEndpoint: View {
    let title: String
    let detail: String
    let systemImage: String
    var isCompact: Bool = false

    var body: some View {
        HStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(.quaternary)
                Image(systemName: systemImage)
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }
            .frame(width: 44, height: 44)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.headline)
                    .lineLimit(1)
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .frame(minWidth: isCompact ? 0 : 160, maxWidth: isCompact ? .infinity : 260, alignment: .leading)
    }
}

private struct VisualSelectionPanel<Content: View>: View {
    let title: String
    let detail: String
    let systemImage: String
    let accent: Color
    @Binding var searchText: String
    let searchPrompt: String
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(accent.opacity(0.16))
                    Image(systemName: systemImage)
                        .foregroundStyle(accent)
                }
                .frame(width: 38, height: 38)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.headline)
                    Text(detail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField(searchPrompt, text: $searchText)
                    .textFieldStyle(.plain)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(.quaternary, in: RoundedRectangle(cornerRadius: 8))

            ScrollView {
                content
                    .padding(1)
            }
            .frame(minHeight: 170, maxHeight: 230)
        }
        .padding(14)
        .frame(maxWidth: .infinity)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
    }
}

private struct AppTile: View {
    let application: AppSoundSource
    let selectionIndex: Int?
    let action: () -> Void

    var body: some View {
        let isSelected = selectionIndex != nil

        Button(action: action) {
            VStack(spacing: 8) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(isSelected ? Color.blue.opacity(0.18) : Color.secondary.opacity(0.10))
                    Image(systemName: application.isRunningOutput ? "waveform" : "app.fill")
                        .font(.title2)
                        .foregroundStyle(isSelected ? .blue : .secondary)
                    if let selectionIndex {
                        SelectionNumber(value: selectionIndex, color: .blue)
                            .offset(x: 23, y: -23)
                    }
                }
                .frame(width: 46, height: 46)

                Text(application.displayName)
                    .font(.caption.weight(.medium))
                    .lineLimit(1)

                StatusDot(title: application.isRunningOutput ? "Playing" : (application.isRunning ? "Running" : "Ready"), isActive: application.isRunningOutput || application.isRunning)
            }
            .padding(10)
            .frame(maxWidth: .infinity, minHeight: 116)
            .background(isSelected ? Color.blue.opacity(0.12) : Color.clear, in: RoundedRectangle(cornerRadius: 8))
            .overlay {
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? Color.blue : Color.secondary.opacity(0.22), lineWidth: isSelected ? 3 : 1.5)
                    .allowsHitTesting(false)
            }
            .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

private struct SpeakerTile: View {
    let device: AudioDeviceInfo
    let selectionIndex: Int?
    let action: () -> Void

    var body: some View {
        let isSelected = selectionIndex != nil

        Button(action: action) {
            VStack(spacing: 8) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(isSelected ? Color.teal.opacity(0.18) : Color.secondary.opacity(0.10))
                    Image(systemName: device.transport == .bluetooth || device.transport == .bluetoothLE ? "headphones" : "speaker.wave.2.fill")
                        .font(.title2)
                        .foregroundStyle(isSelected ? .teal : .secondary)
                    if let selectionIndex {
                        SelectionNumber(value: selectionIndex, color: .teal)
                            .offset(x: 23, y: -23)
                    }
                }
                .frame(width: 46, height: 46)

                Text(device.name)
                    .font(.caption.weight(.medium))
                    .lineLimit(1)

                StatusDot(title: device.transport.rawValue, isActive: device.isAlive)
            }
            .padding(10)
            .frame(maxWidth: .infinity, minHeight: 116)
            .background(isSelected ? Color.teal.opacity(0.12) : Color.clear, in: RoundedRectangle(cornerRadius: 8))
            .overlay {
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? Color.teal : Color.secondary.opacity(0.22), lineWidth: isSelected ? 3 : 1.5)
                    .allowsHitTesting(false)
            }
            .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

private struct SelectionNumber: View {
    let value: Int
    let color: Color

    var body: some View {
        Text("\(value)")
            .font(.caption2.weight(.bold))
            .foregroundStyle(.white)
            .frame(width: 18, height: 18)
            .background(color, in: Circle())
            .shadow(color: .black.opacity(0.16), radius: 2, x: 0, y: 1)
    }
}

private struct StatusDot: View {
    let title: String
    let isActive: Bool

    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(isActive ? Color.green : Color.secondary.opacity(0.5))
                .frame(width: 6, height: 6)
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
    }
}
