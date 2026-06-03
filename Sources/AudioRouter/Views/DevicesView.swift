import SwiftUI

struct DevicesView: View {
    @ObservedObject var store: AudioRouterStore

    var body: some View {
        ConsoleFrame {
            VStack(alignment: .leading, spacing: 12) {
                DeviceOverviewHeader(store: store)
                DeviceStatsStrip(store: store)

                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .top, spacing: 12) {
                        CompactDeviceSection(
                            title: "Outputs",
                            devices: store.outputDevices,
                            fallbackIcon: "speaker.wave.2.fill",
                            tint: ConsolePalette.teal,
                            store: store
                        )
                        CompactDeviceSection(
                            title: "Inputs",
                            devices: store.inputDevices,
                            fallbackIcon: "mic.fill",
                            tint: .cyan,
                            store: store
                        )
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        CompactDeviceSection(
                            title: "Outputs",
                            devices: store.outputDevices,
                            fallbackIcon: "speaker.wave.2.fill",
                            tint: ConsolePalette.teal,
                            store: store
                        )
                        CompactDeviceSection(
                            title: "Inputs",
                            devices: store.inputDevices,
                            fallbackIcon: "mic.fill",
                            tint: .cyan,
                            store: store
                        )
                    }
                }

                CompactOutputGroupsSection(store: store)
            }
        }
    }
}

private struct DeviceOverviewHeader: View {
    @ObservedObject var store: AudioRouterStore

    var body: some View {
        ConsolePageHeader(
            title: "Devices",
            subtitle: "Macro view of every audio device AudioRouter can see.",
            systemImage: "waveform.path.badge.plus",
            tint: ConsolePalette.teal
        ) {
            Button {
                store.refresh()
            } label: {
                Label("Refresh", systemImage: "arrow.clockwise")
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .accessibilityHint("Reloads audio inputs, outputs, and output groups")
        }
    }
}

private struct DeviceStatsStrip: View {
    @ObservedObject var store: AudioRouterStore

    private var connectedCount: Int {
        (store.outputDevices + store.inputDevices).filter(\.isAlive).count
    }

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 8) {
                ConsoleMetricTile(title: "Outputs", value: "\(store.outputDevices.count)", systemImage: "speaker.wave.2.fill", tint: ConsolePalette.teal)
                ConsoleMetricTile(title: "Inputs", value: "\(store.inputDevices.count)", systemImage: "mic.fill", tint: .cyan)
                ConsoleMetricTile(title: "Connected", value: "\(connectedCount)", systemImage: "checkmark.circle.fill", tint: ConsolePalette.green)
                ConsoleMetricTile(title: "Groups", value: "\(store.outputGroups.count)", systemImage: "speaker.3.fill", tint: ConsolePalette.amber)
            }

            VStack(alignment: .leading, spacing: 8) {
                ConsoleMetricTile(title: "Outputs", value: "\(store.outputDevices.count)", systemImage: "speaker.wave.2.fill", tint: ConsolePalette.teal)
                ConsoleMetricTile(title: "Inputs", value: "\(store.inputDevices.count)", systemImage: "mic.fill", tint: .cyan)
                ConsoleMetricTile(title: "Connected", value: "\(connectedCount)", systemImage: "checkmark.circle.fill", tint: ConsolePalette.green)
                ConsoleMetricTile(title: "Groups", value: "\(store.outputGroups.count)", systemImage: "speaker.3.fill", tint: ConsolePalette.amber)
            }
        }
    }
}

private struct CompactDeviceSection: View {
    let title: String
    let devices: [AudioDevice]
    let fallbackIcon: String
    let tint: Color
    @ObservedObject var store: AudioRouterStore

    var body: some View {
        ConsolePanel(
            title: title,
            systemImage: devices.first?.kind.systemImage ?? fallbackIcon,
            trailing: "\(devices.count)",
            tint: tint
        ) {

            if devices.isEmpty {
                CompactEmptyDeviceRow(title: "No \(title.lowercased()) found", systemImage: fallbackIcon)
            } else {
                VStack(spacing: 6) {
                    ForEach(devices) { device in
                        CompactDeviceRow(device: device, tint: tint, store: store)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }
}

private struct CompactEmptyDeviceRow: View {
    let title: String
    let systemImage: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: systemImage)
                .frame(width: 24, height: 24)
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Spacer()
        }
        .padding(10)
        .background(ConsolePalette.inset.opacity(0.75), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityLabel(title)
    }
}

private struct CompactDeviceRow: View {
    let device: AudioDevice
    let tint: Color
    @ObservedObject var store: AudioRouterStore

    private var routedCount: Int {
        guard device.kind == .output else { return 0 }
        return store.routedSources(to: device).count
    }

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            DeviceIcon(device: device)
                .frame(width: 28, height: 28)

            VStack(alignment: .leading, spacing: 5) {
                HStack(alignment: .center, spacing: 7) {
                    Text(device.name)
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)

                    if device.isDefault {
                        CompactDeviceBadge(text: "System", tint: .green, isFilled: true)
                    }

                    if !device.isAlive {
                        CompactDeviceBadge(text: "Missing", tint: .red, isFilled: false)
                    }
                }

                HStack(alignment: .center, spacing: 6) {
                    Text(device.typeDescription)
                    Text(device.sampleRateDescription)
                    if let volume = device.volume {
                        Text("Vol \(volume.roundedPercentDescription)")
                    } else {
                        Text("Vol N/A")
                    }
                    if routedCount > 0 {
                        Text("\(routedCount) app\(routedCount == 1 ? "" : "s")")
                    }
                }
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)

                HStack(spacing: 5) {
                    CapabilityChip(title: "Volume", isAvailable: device.canSetVolume)
                    CapabilityChip(title: "Mute", isAvailable: device.canSetMute)
                    if device.kind == .output {
                        CapabilityChip(title: "Balance", isAvailable: device.canSetBalance)
                    }
                }
            }

            Spacer(minLength: 8)

            MeterView(
                level: store.deviceMeters[device.id] ?? 0,
                barCount: 8,
                height: 12,
                color: tint
            )
            .frame(width: 78)

            Button(device.isDefault ? "Default" : "Set") {
                store.setDefaultDevice(device)
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .disabled(device.isDefault || !device.isAlive)
            .accessibilityHint(device.isDefault ? "\(device.name) is already the system \(device.kind.title.lowercased())" : "Makes \(device.name) the system \(device.kind.title.lowercased())")
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background((device.isDefault ? tint.opacity(0.13) : ConsolePalette.inset.opacity(0.75)), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(device.isDefault ? tint.opacity(0.35) : Color.white.opacity(0.06), lineWidth: 1)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("\(device.name), \(device.kind.title), \(device.isAlive ? "connected" : "disconnected"), \(device.isDefault ? "system default" : "not default")")
    }
}

private struct CompactDeviceBadge: View {
    let text: String
    let tint: Color
    let isFilled: Bool

    var body: some View {
        Text(text.uppercased())
            .font(.system(size: 8, weight: .heavy, design: .monospaced))
            .foregroundStyle(isFilled ? .black : tint)
            .padding(.horizontal, 6)
            .frame(height: 18)
            .background(isFilled ? tint : tint.opacity(0.12), in: Capsule())
            .overlay {
                Capsule()
                    .stroke(tint.opacity(isFilled ? 0 : 0.30), lineWidth: 1)
            }
    }
}

private struct CapabilityChip: View {
    let title: String
    let isAvailable: Bool

    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(isAvailable ? Color.green : Color.secondary.opacity(0.45))
                .frame(width: 5, height: 5)
            Text(title)
                .lineLimit(1)
        }
        .font(.system(size: 8, weight: .semibold, design: .monospaced))
        .foregroundStyle(isAvailable ? .secondary : .tertiary)
        .padding(.horizontal, 6)
        .frame(height: 18)
        .background(.secondary.opacity(0.07), in: Capsule())
        .accessibilityLabel("\(title), \(isAvailable ? "available" : "unavailable")")
    }
}

private struct CompactOutputGroupsSection: View {
    @ObservedObject var store: AudioRouterStore

    var body: some View {
        ConsolePanel(
            title: "Groups",
            systemImage: "speaker.3.fill",
            trailing: store.outputGroups.isEmpty ? nil : "\(store.outputGroups.count)",
            tint: ConsolePalette.amber
        ) {
            HStack(alignment: .center, spacing: 10) {
                Text("Group Play destinations")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Button {
                    store.createOutputGroup()
                } label: {
                    Label("New", systemImage: "plus.circle.fill")
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .accessibilityHint("Creates a group play route target using all currently visible outputs")
            }

            if store.outputGroups.isEmpty {
                CompactEmptyDeviceRow(title: "No output groups saved", systemImage: "speaker.3.fill")
            } else {
                VStack(spacing: 6) {
                    ForEach(store.outputGroups) { group in
                        CompactOutputGroupRow(group: group, store: store)
                    }
                }
            }
        }
    }
}

private struct CompactOutputGroupRow: View {
    let group: OutputDeviceGroup
    @ObservedObject var store: AudioRouterStore

    private var connectedOutputs: [AudioDevice] {
        store.outputDevices(for: group)
    }

    private var routedSources: [AudioSource] {
        store.audioSources.filter { source in
            store.route(for: source).outputDeviceID == group.routeTargetID
        }
    }

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            Image(systemName: "speaker.3.fill")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.orange)
                .frame(width: 28, height: 28)
                .background(.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 8, style: .continuous))

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 7) {
                    Text(group.name)
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)
                    CompactDeviceBadge(
                        text: connectedOutputs.isEmpty ? "No Devices" : "Group",
                        tint: connectedOutputs.isEmpty ? .red : .orange,
                        isFilled: false
                    )
                }

                Text(groupDetail)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            Button(role: .destructive) {
                store.deleteOutputGroup(group)
            } label: {
                Image(systemName: "trash")
            }
            .buttonStyle(.borderless)
            .controlSize(.small)
            .accessibilityLabel("Delete \(group.name)")
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(ConsolePalette.inset.opacity(0.75), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color.white.opacity(0.06), lineWidth: 1)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("\(group.name), \(connectedOutputs.count) connected devices, \(routedSources.count) routed apps")
    }

    private var groupDetail: String {
        let deviceText = "\(connectedOutputs.count) speaker\(connectedOutputs.count == 1 ? "" : "s")"
        let routeText = "\(routedSources.count) routed app\(routedSources.count == 1 ? "" : "s")"
        if connectedOutputs.isEmpty {
            return "No connected speakers · \(routeText)"
        }
        return "\(deviceText) · \(routeText)"
    }
}
