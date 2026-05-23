import SwiftUI

struct DevicesView: View {
    @ObservedObject var store: AudioRouterStore
    @State private var searchText = ""

    var body: some View {
        List(filteredDevices) { device in
            DeviceRow(store: store, device: device)
        }
        .navigationTitle("Devices")
        .searchable(text: $searchText, placement: .toolbar, prompt: "Search devices")
        .safeAreaInset(edge: .top, spacing: 0) {
            DashboardHeader(
                title: "Output Devices",
                subtitle: "Connected CoreAudio outputs available for app routing.",
                primaryMetric: "\(store.devices.filter(\.isRoutableOutput).count)",
                primaryLabel: "Routable",
                secondaryMetric: "\(store.devices.filter { $0.transport == .bluetooth || $0.transport == .bluetoothLE }.count)",
                secondaryLabel: "Bluetooth",
                tertiaryMetric: "\(store.devices.filter(\.isDefaultOutput).count)",
                tertiaryLabel: "Default"
            )
            .padding(20)
            .background(.bar)
        }
        .overlay {
            if filteredDevices.isEmpty {
                ContentUnavailableView(
                    store.devices.isEmpty ? "No output devices" : "No matches",
                    systemImage: "speaker.slash",
                    description: Text(store.devices.isEmpty ? "Connect an audio output in macOS, then refresh." : "Clear the search field.")
                )
            }
        }
    }

    private var filteredDevices: [AudioDeviceInfo] {
        guard !searchText.isEmpty else { return store.devices }
        return store.devices.filter { device in
            device.name.localizedCaseInsensitiveContains(searchText)
                || device.transport.rawValue.localizedCaseInsensitiveContains(searchText)
                || device.uid.localizedCaseInsensitiveContains(searchText)
        }
    }
}

private struct DeviceRow: View {
    @ObservedObject var store: AudioRouterStore
    let device: AudioDeviceInfo

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 12) {
                identity
                Spacer()
                controls
            }

            VStack(alignment: .leading, spacing: 12) {
                identity
                controls
            }
        }
        .padding(.vertical, 7)
    }

    private var identity: some View {
        HStack(spacing: 12) {
            Image(systemName: device.transport == .bluetooth || device.transport == .bluetoothLE ? "headphones" : "speaker.wave.2")
                .font(.title3)
                .foregroundStyle(.secondary)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 4) {
                Text(device.name)
                    .font(.headline)
                    .lineLimit(1)

                Text("\(device.transport.rawValue) · \(device.outputChannelCount) output channels")
                    .foregroundStyle(.secondary)
                    .font(.callout)
                    .lineLimit(1)
            }
        }
        .frame(minWidth: 180, maxWidth: .infinity, alignment: .leading)
    }

    private var controls: some View {
        HStack(spacing: 12) {
            if let outputVolume = currentDevice.outputVolume {
                HStack(spacing: 8) {
                    Image(systemName: currentDevice.isMuted == true ? "speaker.slash.fill" : "speaker.wave.2.fill")
                        .foregroundStyle(.secondary)
                        .frame(width: 18)
                    Slider(value: volumeBinding, in: 0...1)
                        .frame(width: 120)
                        .disabled(!currentDevice.canSetVolume)
                    Text("\(Int(outputVolume * 100))%")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                        .frame(width: 42, alignment: .trailing)
                }
            }

            if currentDevice.canSetMute {
                Toggle("Mute", isOn: muteBinding)
                    .toggleStyle(.switch)
                    .labelsHidden()
            }

            if !currentDevice.isDefaultOutput {
                Button {
                    store.setDefaultOutput(device)
                } label: {
                    Label("Default", systemImage: "checkmark.circle")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            } else {
                StatusPill(title: "Default", systemImage: "checkmark.circle.fill")
            }

            if !currentDevice.isAlive {
                StatusPill(title: "Offline", systemImage: "exclamationmark.triangle")
            }
        }
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

    private var muteBinding: Binding<Bool> {
        Binding(
            get: {
                currentDevice.isMuted ?? false
            },
            set: { newValue in
                store.setDeviceMuted(currentDevice, isMuted: newValue)
            }
        )
    }
}
