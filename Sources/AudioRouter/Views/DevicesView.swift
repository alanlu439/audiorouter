import SwiftUI

struct DevicesView: View {
    @ObservedObject var store: AudioRouterStore

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
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
                VStack(spacing: 8) {
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
        HStack(spacing: 10) {
            DeviceIcon(device: device)
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(device.name)
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)
                    if device.isDefault {
                        StatusBadge(text: "Active", isActive: true)
                    }
                }
                Text(device.typeDescription)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button("Use") {
                store.setDefaultDevice(device)
            }
            .disabled(device.isDefault)
            .buttonStyle(.borderless)
        }
    }
}
