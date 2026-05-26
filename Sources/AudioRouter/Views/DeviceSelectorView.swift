import SwiftUI

struct DeviceSelectorView: View {
    let title: String
    let devices: [AudioDevice]
    let selectedUID: String?
    let onSelect: (AudioDevice) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Picker(title, selection: selection) {
                ForEach(devices) { device in
                    HStack {
                        Text(device.name)
                        if device.isDefault {
                            Text("Default")
                        }
                    }
                    .tag(device.uid)
                }
            }
            .labelsHidden()
            .pickerStyle(.menu)
            .accessibilityLabel("\(title) device")
            .accessibilityValue(selectedDeviceName)
            .accessibilityHint("Choose the system \(title.lowercased()) device")
        }
    }

    private var selectedDeviceName: String {
        devices.first { $0.uid == selectedUID }?.name ?? "None selected"
    }

    private var selection: Binding<String> {
        Binding(
            get: { selectedUID ?? devices.first?.uid ?? "" },
            set: { uid in
                if let device = devices.first(where: { $0.uid == uid }) {
                    onSelect(device)
                }
            }
        )
    }
}
