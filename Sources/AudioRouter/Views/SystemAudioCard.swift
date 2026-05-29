import SwiftUI

struct SystemAudioCard: View {
    @ObservedObject var store: AudioRouterStore

    var body: some View {
        DockCard {
            SectionHeader(title: "System", systemImage: "dial.high")

            HStack(spacing: 10) {
                DeviceSelectorView(
                    title: "Output",
                    devices: store.outputDevices,
                    selectedUID: store.currentOutput?.uid,
                    onSelect: store.setDefaultDevice
                )
                DeviceSelectorView(
                    title: "Input",
                    devices: store.inputDevices,
                    selectedUID: store.currentInput?.uid,
                    onSelect: store.setDefaultDevice
                )
            }

            if let output = store.currentOutput {
                HStack(spacing: 10) {
                    DeviceIcon(device: output)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(output.name)
                            .font(.subheadline.weight(.semibold))
                            .lineLimit(1)
                        Text(output.typeDescription)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button {
                        store.setDeviceMuted(output, isMuted: !(output.isMuted ?? false))
                    } label: {
                        Image(systemName: (output.isMuted ?? false) ? "speaker.slash.fill" : "speaker.wave.2.fill")
                    }
                    .buttonStyle(.borderless)
                    .disabled(!output.canSetMute)
                    .help(output.canSetMute ? "Mute output" : "Mute is not supported by this device")
                    .accessibilityLabel((output.isMuted ?? false) ? "Unmute system output" : "Mute system output")
                    .accessibilityHint(output.canSetMute ? "Toggles mute for \(output.name)" : "Mute is not supported by this device")
                }
                .accessibilityElement(children: .contain)
                .accessibilityLabel("Current output device, \(output.name), \(output.typeDescription)")

                VolumeSlider(
                    title: "Output",
                    value: output.volume,
                    isEnabled: output.canSetVolume,
                    systemImage: "speaker.wave.2.fill",
                    accent: .teal,
                    showsStepButtons: true,
                    onChange: store.setSystemOutputVolume
                )

                BalanceSlider(device: output, store: store)
            } else {
                Text("No output device found.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if let input = store.currentInput {
                VolumeSlider(
                    title: "Input",
                    value: input.volume,
                    isEnabled: input.canSetVolume,
                    systemImage: "mic.fill",
                    accent: .cyan,
                    showsStepButtons: true,
                    onChange: store.setInputVolume
                )
            }
        }
    }
}

private struct BalanceSlider: View {
    let device: AudioDevice
    @ObservedObject var store: AudioRouterStore

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "circle.lefthalf.filled")
                .foregroundStyle(device.canSetBalance ? .primary : .secondary)
                .frame(width: 18)
            Text("Balance")
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 48, alignment: .leading)
            Slider(
                value: Binding(
                    get: { device.balance ?? 0 },
                    set: { store.setDeviceBalance(device, balance: $0) }
                ),
                in: -1...1
            )
            .disabled(!device.canSetBalance)
            .accessibilityLabel("Output balance")
            .accessibilityValue((device.balance ?? 0).balanceDescription)
            .accessibilityHint(device.canSetBalance ? "Adjusts left and right output balance" : "Balance is not supported by this device")
            Text("L/R")
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(width: 42, alignment: .trailing)
        }
        .help(device.canSetBalance ? "Adjust left and right output level" : "Balance is not supported by this device")
    }
}
