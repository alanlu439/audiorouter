import SwiftUI

struct RoutingDashboardView: View {
    @ObservedObject var store: AudioRouterStore

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            dashboardHeader
            if let note = store.unsupportedNote {
                SupportNote(note: note) {
                    store.dismissUnsupportedNote()
                }
            }
            HStack(alignment: .top, spacing: 14) {
                sourceColumn
                routeColumn
                outputColumn
            }
        }
    }

    private var dashboardHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Routing Dashboard")
                    .font(.largeTitle.weight(.bold))
                Text("Drag a source onto an output, or use each source dropdown.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Picker("Mode", selection: demoBinding) {
                Text("Live Mode").tag(false)
                Text("Demo Mode").tag(true)
            }
            .pickerStyle(.segmented)
            .frame(width: 240)
        }
    }

    private var sourceColumn: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: "Audio Sources", systemImage: "app.connected.to.app.below.fill", trailing: "\(store.audioSources.count)")
            ForEach(store.audioSources) { source in
                SourceRoutingCard(source: source, store: store)
                    .draggable(source.id)
                    .onTapGesture {
                        store.selectedSourceID = source.id
                    }
            }
        }
        .frame(minWidth: 260, maxWidth: 320, alignment: .top)
    }

    private var routeColumn: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: "Routes", systemImage: "arrow.left.and.right", trailing: store.supportsTruePerAppRouting ? "Live" : "Simulated")
            ForEach(store.audioSources) { source in
                Button {
                    store.selectedSourceID = source.id
                } label: {
                    RouteLineCard(source: source, store: store, isSelected: store.selectedSourceID == source.id)
                }
                .buttonStyle(.plain)
            }
            if let source = selectedSource {
                RouteControlCard(source: source, store: store)
            }
        }
        .frame(minWidth: 250, maxWidth: 330, alignment: .top)
    }

    private var outputColumn: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: "Output Devices", systemImage: "speaker.wave.2.fill", trailing: "\(store.outputDevices.count)")
            ForEach(store.outputDevices) { device in
                OutputRoutingCard(device: device, store: store)
                    .dropDestination(for: String.self) { sourceIDs, _ in
                        guard let sourceID = sourceIDs.first,
                              let source = store.audioSources.first(where: { $0.id == sourceID }) else {
                            return false
                        }
                        store.assignSourceOutput(source: source, uid: device.uid)
                        store.selectedSourceID = source.id
                        return true
                    }
            }
        }
        .frame(minWidth: 260, maxWidth: 340, alignment: .top)
    }

    private var selectedSource: AudioSource? {
        store.selectedSourceID.flatMap { id in store.audioSources.first { $0.id == id } }
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

private struct SourceRoutingCard: View {
    let source: AudioSource
    @ObservedObject var store: AudioRouterStore

    var body: some View {
        DockCard {
            HStack(spacing: 10) {
                AppSourceIcon(source: source)
                VStack(alignment: .leading, spacing: 3) {
                    Text(source.appName)
                        .font(.headline)
                        .lineLimit(1)
                    Text("Last active \(source.lastActiveTime.shortRelativeDescription)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                StatusLabel(text: store.routeStatus(for: source), status: store.routeStatusIsWarning(for: source) ? .requiresDriver : .working)
            }

            MeterView(level: store.sourceMeters[source.id] ?? 0, barCount: 12, color: source.isProducingAudio ? .green : .cyan)

            HStack {
                Button {
                    store.setSourceMuted(source: source, isMuted: !source.isMuted)
                } label: {
                    Image(systemName: source.isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                }
                .buttonStyle(.bordered)
                Button {
                    store.toggleSolo(source: source)
                } label: {
                    Text(store.soloSourceID == source.id ? "Solo On" : "Solo")
                }
                .buttonStyle(.bordered)
                Spacer()
                Toggle("Follow System Output", isOn: followSystemBinding)
                    .toggleStyle(.switch)
            }

            VolumeLine(source: source, store: store)
            outputPicker
        }
    }

    private var outputPicker: some View {
        Picker("Assigned Output", selection: outputSelection) {
            Text("Follow System Output").tag("")
            ForEach(store.outputDevices) { device in
                Text(device.name).tag(device.uid)
            }
        }
        .pickerStyle(.menu)
    }

    private var outputSelection: Binding<String> {
        Binding(
            get: { source.followsSystemOutput ? "" : (source.assignedOutputDeviceID ?? "") },
            set: { value in
                store.assignSourceOutput(source: source, uid: value.isEmpty ? nil : value)
            }
        )
    }

    private var followSystemBinding: Binding<Bool> {
        Binding(
            get: { source.followsSystemOutput },
            set: { follows in
                if follows {
                    store.resetSourceToSystemOutput(source)
                }
            }
        )
    }
}

private struct VolumeLine: View {
    let source: AudioSource
    @ObservedObject var store: AudioRouterStore

    var body: some View {
        HStack {
            Image(systemName: "slider.horizontal.3")
                .foregroundStyle(.secondary)
            Slider(value: Binding(get: { source.volume }, set: { store.setSourceVolume(source: source, volume: $0) }), in: 0...1.5)
            Text("\(Int((source.volume * 100).rounded()))%")
                .font(.caption.monospacedDigit())
                .frame(width: 42, alignment: .trailing)
        }
    }
}

private struct RouteLineCard: View {
    let source: AudioSource
    @ObservedObject var store: AudioRouterStore
    let isSelected: Bool

    var body: some View {
        let route = store.route(for: source)
        HStack(spacing: 10) {
            Text(source.appName)
                .font(.caption.weight(.semibold))
                .lineLimit(1)
                .frame(width: 74, alignment: .leading)
            RouteLineShape(isDashed: route.routeMode == .customDevice && !store.supportsTruePerAppRouting)
                .stroke(route.routeMode == .followSystem ? Color.secondary : Color.teal, style: StrokeStyle(lineWidth: 2, dash: route.routeMode == .customDevice && !store.supportsTruePerAppRouting ? [6, 4] : []))
                .frame(height: 18)
            Image(systemName: route.routeMode == .followSystem ? "arrow.triangle.branch" : "arrow.right.circle.fill")
                .foregroundStyle(route.routeMode == .followSystem ? Color.secondary : Color.teal)
            Text(store.routeOutputName(for: source))
                .font(.caption)
                .lineLimit(1)
                .frame(width: 110, alignment: .leading)
            if route.routeMode == .customDevice && !store.supportsTruePerAppRouting {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
            }
        }
        .padding(10)
        .background(isSelected ? Color.teal.opacity(0.14) : Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

private struct RouteLineShape: Shape {
    let isDashed: Bool

    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.midY))
        path.addCurve(
            to: CGPoint(x: rect.maxX, y: rect.midY),
            control1: CGPoint(x: rect.midX * 0.55, y: rect.minY),
            control2: CGPoint(x: rect.midX * 1.35, y: rect.maxY)
        )
        return path
    }
}

private struct RouteControlCard: View {
    let source: AudioSource
    @ObservedObject var store: AudioRouterStore

    var body: some View {
        DockCard {
            SectionHeader(title: "Route Controls", systemImage: "slider.horizontal.3")
            Text("\(source.appName) -> \(store.routeOutputName(for: source))")
                .font(.subheadline.weight(.semibold))
            VolumeLine(source: source, store: store)
            HStack {
                Button {
                    store.resetSourceToSystemOutput(source)
                } label: {
                    Label("Follow System", systemImage: "arrow.triangle.branch")
                }
                Button(role: .destructive) {
                    store.resetSourceToSystemOutput(source)
                } label: {
                    Label("Delete Route", systemImage: "trash")
                }
            }
            if store.routeStatusIsWarning(for: source) {
                StatusLabel(text: "Requires Driver", status: .requiresDriver)
            }
        }
    }
}

private struct OutputRoutingCard: View {
    let device: AudioDevice
    @ObservedObject var store: AudioRouterStore

    var body: some View {
        DockCard {
            HStack(spacing: 10) {
                DeviceIcon(device: device)
                VStack(alignment: .leading, spacing: 3) {
                    Text(device.name)
                        .font(.headline)
                        .lineLimit(1)
                    Text(device.typeDescription)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                StatusLabel(text: device.isAlive ? "Connected" : "Device Missing", status: device.isAlive ? .working : .deviceMissing)
            }
            MeterView(level: store.deviceMeters[device.id] ?? 0, barCount: 12, color: .teal)
            HStack {
                Text(device.sampleRateDescription)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Button(device.isDefault ? "System Output" : "Set System") {
                    store.setDefaultDevice(device)
                }
                .disabled(device.isDefault)
            }
            let routed = store.routedSources(to: device)
            if routed.isEmpty {
                Text("Drop sources here")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(routed) { source in
                        Label(source.appName, systemImage: "app.fill")
                            .font(.caption)
                    }
                }
            }
        }
    }
}
