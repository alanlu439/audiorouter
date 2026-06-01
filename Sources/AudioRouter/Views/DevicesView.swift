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
                accent: device.kind == .input ? .cyan : .teal,
                onChange: { store.setDeviceVolume(device, volume: $0) }
            )
            HStack {
                Button {
                    store.setDeviceMuted(device, isMuted: !(device.isMuted ?? false))
                } label: {
                    Label((device.isMuted ?? false) ? "Muted" : "Mute", systemImage: (device.isMuted ?? false) ? "speaker.slash.fill" : "speaker.wave.1.fill")
                }
                .disabled(!device.canSetMute)
                .accessibilityLabel((device.isMuted ?? false) ? "Unmute \(device.name)" : "Mute \(device.name)")
                .accessibilityHint(device.canSetMute ? "Toggles mute for this device" : "Mute is not supported by this device")
                if device.kind == .output {
                    Slider(
                        value: Binding(
                            get: { device.balance ?? 0 },
                            set: { store.setDeviceBalance(device, balance: $0) }
                        ),
                        in: -1...1
                    )
                    .disabled(!device.canSetBalance)
                    .accessibilityLabel("\(device.name) balance")
                    .accessibilityValue((device.balance ?? 0).balanceDescription)
                    .accessibilityHint(device.canSetBalance ? "Adjusts left and right output balance" : "Balance is not supported by this device")
                }
                Button(device.isDefault ? "Default" : "Set as System \(device.kind.title)") {
                    store.setDefaultDevice(device)
                }
                .disabled(device.isDefault)
                .accessibilityHint(device.isDefault ? "\(device.name) is already the system \(device.kind.title.lowercased())" : "Makes \(device.name) the system \(device.kind.title.lowercased())")
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
        .accessibilityElement(children: .contain)
        .accessibilityLabel("\(device.name), \(device.kind.title), \(device.isAlive ? "connected" : "disconnected"), \(device.isDefault ? "system default" : "not default")")
    }
}

private struct OutputGroupsView: View {
    @ObservedObject var store: AudioRouterStore

    var body: some View {
        DockCard {
            SectionHeader(title: "Output Groups", systemImage: "speaker.3.fill", trailing: store.outputGroups.isEmpty ? nil : "\(store.outputGroups.count)")
            Text("Groups can be selected as route targets. AudioRouter fans a live process-tap route out to each connected device in the group; separate devices may have small latency differences.")
                .font(.caption)
                .foregroundStyle(.secondary)
            Button {
                store.createOutputGroup()
            } label: {
                Label("Create Output Group", systemImage: "plus.circle.fill")
            }
            .buttonStyle(.borderedProminent)
            .accessibilityHint("Creates a group play route target using all currently visible outputs")
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
                StatusLabel(text: store.outputDevices(for: group).isEmpty ? "No Devices" : "Group Play", status: store.outputDevices(for: group).isEmpty ? .deviceMissing : .working)
            }
            ForEach(store.outputDevices) { device in
                VStack(alignment: .leading, spacing: 6) {
                    Toggle(isOn: includeBinding(device)) {
                        Text(device.name)
                            .font(.caption.weight(.semibold))
                    }
                    InlineVolumeSlider(
                        value: group.perDeviceVolumes[device.uid] ?? device.volume ?? 1,
                        isEnabled: group.deviceUIDs.contains(device.uid) && device.canSetVolume,
                        systemImage: device.kind.systemImage,
                        accent: .teal,
                        accessibilityLabel: "\(device.name) group volume",
                        accessibilityHint: group.deviceUIDs.contains(device.uid) ? "Adjusts saved group volume for this device" : "Include this device before changing its group volume",
                        onChange: { store.setOutputGroupVolume(group, deviceUID: device.uid, volume: $0) }
                    )
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

}
