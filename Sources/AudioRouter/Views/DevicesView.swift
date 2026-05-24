import SwiftUI

struct DevicesView: View {
    @ObservedObject var store: AudioRouterStore

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Devices")
                .font(.largeTitle.weight(.bold))
            DeviceGroupView(title: "Output Devices", devices: store.outputDevices, store: store)
            DeviceGroupView(title: "Input Devices", devices: store.inputDevices, store: store)
            OutputGroupsView(store: store)
        }
    }
}

private struct DeviceGroupView: View {
    let title: String
    let devices: [AudioDevice]
    @ObservedObject var store: AudioRouterStore

    var body: some View {
        DockCard {
            SectionHeader(title: title, systemImage: devices.first?.kind.systemImage ?? "speaker.wave.2")
            if devices.isEmpty {
                Text("No devices found.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 260), spacing: 12)], spacing: 12) {
                    ForEach(devices) { device in
                        DeviceRow(device: device, store: store)
                    }
                }
            }
        }
    }
}

private struct DeviceRow: View {
    let device: AudioDevice
    @ObservedObject var store: AudioRouterStore

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                DeviceIcon(device: device)
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(device.name)
                            .font(.subheadline.weight(.semibold))
                            .lineLimit(1)
                        if device.isDefault {
                            StatusBadge(text: "System", isActive: true)
                        }
                    }
                    Text(device.typeDescription)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            MeterView(level: store.deviceMeters[device.id] ?? 0, barCount: 14, color: device.kind == .input ? .cyan : .teal)
            HStack {
                Text(device.isAlive ? "Connected" : "Disconnected")
                    .font(.caption)
                    .foregroundStyle(device.isAlive ? .green : .red)
                Spacer()
                Text(device.sampleRateDescription)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            VolumeSlider(
                title: "Volume",
                value: device.volume,
                isEnabled: device.canSetVolume,
                systemImage: device.kind.systemImage,
                onChange: { store.setDeviceVolume(device, volume: $0) }
            )
            HStack {
                Button {
                    store.setDeviceMuted(device, isMuted: !(device.isMuted ?? false))
                } label: {
                    Label((device.isMuted ?? false) ? "Muted" : "Mute", systemImage: (device.isMuted ?? false) ? "speaker.slash.fill" : "speaker.wave.1.fill")
                }
                .disabled(!device.canSetMute)
                if device.kind == .output {
                    Slider(
                        value: Binding(
                            get: { device.balance ?? 0 },
                            set: { store.setDeviceBalance(device, balance: $0) }
                        ),
                        in: -1...1
                    )
                    .disabled(!device.canSetBalance)
                }
                Button(device.isDefault ? "Default" : "Set as System \(device.kind.title)") {
                    store.setDefaultDevice(device)
                }
                .disabled(device.isDefault)
            }
            if device.kind == .output {
                let routed = store.routedSources(to: device)
                if !routed.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Routed Apps")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                        ForEach(routed) { source in
                            Label(source.appName, systemImage: "app.fill")
                                .font(.caption)
                        }
                    }
                }
            }
        }
        .padding(12)
        .background(.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

private struct OutputGroupsView: View {
    @ObservedObject var store: AudioRouterStore

    var body: some View {
        DockCard {
            SectionHeader(title: "Output Groups", systemImage: "speaker.3.fill", trailing: store.outputGroups.isEmpty ? nil : "\(store.outputGroups.count)")
            Text("Groups are saved route targets. Simultaneous playback to multiple outputs requires an audio backend.")
                .font(.caption)
                .foregroundStyle(.secondary)
            Button {
                store.createOutputGroup()
            } label: {
                Label("Create Output Group", systemImage: "plus.circle.fill")
            }
            .buttonStyle(.borderedProminent)
            if store.outputGroups.isEmpty {
                Text("No groups saved.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 280), spacing: 12)], spacing: 12) {
                    ForEach(store.outputGroups) { group in
                        OutputGroupCard(group: group, store: store)
                    }
                }
            }
        }
    }
}

private struct OutputGroupCard: View {
    let group: OutputDeviceGroup
    @ObservedObject var store: AudioRouterStore
    @State private var name: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                TextField("Group name", text: nameBinding)
                    .textFieldStyle(.roundedBorder)
                StatusLabel(text: "Requires Audio Backend", status: .requiresBackend)
            }
            ForEach(store.outputDevices) { device in
                VStack(alignment: .leading, spacing: 6) {
                    Toggle(isOn: includeBinding(device)) {
                        Text(device.name)
                            .font(.caption.weight(.semibold))
                    }
                    Slider(
                        value: groupVolumeBinding(device),
                        in: 0...1
                    )
                    .disabled(!group.deviceUIDs.contains(device.uid) || !device.canSetVolume)
                }
            }
            Button(role: .destructive) {
                store.deleteOutputGroup(group)
            } label: {
                Label("Delete Group", systemImage: "trash")
            }
        }
        .padding(12)
        .background(.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .onAppear {
            name = group.name
        }
    }

    private var nameBinding: Binding<String> {
        Binding(
            get: { name.isEmpty ? group.name : name },
            set: { newValue in
                name = newValue
                store.renameOutputGroup(group, to: newValue)
            }
        )
    }

    private func includeBinding(_ device: AudioDevice) -> Binding<Bool> {
        Binding(
            get: { group.deviceUIDs.contains(device.uid) },
            set: { store.setOutputGroup(group, includes: device, included: $0) }
        )
    }

    private func groupVolumeBinding(_ device: AudioDevice) -> Binding<Double> {
        Binding(
            get: { group.perDeviceVolumes[device.uid] ?? device.volume ?? 1 },
            set: { store.setOutputGroupVolume(group, deviceUID: device.uid, volume: $0) }
        )
    }
}
