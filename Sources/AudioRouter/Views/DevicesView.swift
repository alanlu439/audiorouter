import SwiftUI

struct DevicesView: View {
    @ObservedObject var store: AudioRouterStore

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Devices")
                .font(.largeTitle.weight(.bold))
            DeviceGroupView(title: "Output Devices", devices: store.outputDevices, store: store)
            DeviceGroupView(title: "Input Devices", devices: store.inputDevices, store: store)
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
            if device.kind == .output {
                VolumeSlider(
                    title: "Volume",
                    value: device.volume,
                    isEnabled: device.canSetVolume,
                    systemImage: "speaker.wave.2.fill",
                    onChange: { store.setDeviceVolume(device, volume: $0) }
                )
                HStack {
                    Slider(
                        value: Binding(
                            get: { device.balance ?? 0 },
                            set: { store.setDeviceBalance(device, balance: $0) }
                        ),
                        in: -1...1
                    )
                    .disabled(!device.canSetBalance)
                    Button(device.isDefault ? "Default" : "Set as System Output") {
                        store.setDefaultDevice(device)
                    }
                    .disabled(device.isDefault)
                }
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
