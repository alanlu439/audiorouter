import AppKit
import SwiftUI

struct DockCard<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            content
        }
        .padding(14)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(.white.opacity(0.08))
        }
    }
}

struct SectionHeader: View {
    let title: String
    let systemImage: String
    var trailing: String?

    var body: some View {
        HStack(spacing: 8) {
            Label(title, systemImage: systemImage)
                .font(.headline)
            Spacer()
            if let trailing {
                Text(trailing)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(trailing.map { "\(title), \($0)" } ?? title)
    }
}

struct StatusBadge: View {
    let text: String
    var isActive: Bool = false

    var body: some View {
        Text(text)
            .font(.caption2.weight(.semibold))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .foregroundStyle(isActive ? .black : .secondary)
            .background(isActive ? .green : .secondary.opacity(0.12), in: Capsule())
            .accessibilityLabel("\(text) status")
    }
}

struct DeviceIcon: View {
    let device: AudioDevice

    var body: some View {
        Image(systemName: imageName)
            .font(.system(size: 16, weight: .semibold))
            .foregroundStyle(device.isDefault ? .teal : .secondary)
            .frame(width: 28, height: 28)
            .background(.secondary.opacity(0.12), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .accessibilityHidden(true)
    }

    private var imageName: String {
        switch (device.kind, device.transport) {
        case (.input, _): return "mic.fill"
        case (.output, .bluetooth), (.output, .bluetoothLE): return "headphones"
        case (.output, .airPlay): return "airplayaudio"
        case (.output, .usb): return "cable.connector"
        default: return "speaker.wave.2.fill"
        }
    }
}

struct AppSourceIcon: View {
    let source: AudioSource

    var body: some View {
        Group {
            if let path = iconPath {
                Image(nsImage: NSWorkspace.shared.icon(forFile: path))
                    .resizable()
                    .scaledToFit()
            } else {
                Image(systemName: "app.dashed")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: 30, height: 30)
        .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
        .accessibilityHidden(true)
    }

    private var iconPath: String? {
        if let icon = source.icon, !icon.isEmpty {
            return icon
        }
        if let bundleIdentifier = source.bundleIdentifier,
           let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier) {
            return url.path
        }
        return nil
    }
}

struct SupportNote: View {
    let note: String
    let onDismiss: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "info.circle.fill")
                .foregroundStyle(.blue)
            Text(note)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 8)
            Button {
                onDismiss()
            } label: {
                Image(systemName: "xmark")
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .accessibilityLabel("Dismiss note")
            .accessibilityHint("Hides this message")
        }
        .padding(10)
        .background(.blue.opacity(0.10), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .accessibilityElement(children: .contain)
        .accessibilityLabel("AudioRouter note")
    }
}

struct VolumeSlider: View {
    let title: String
    let value: Double?
    let isEnabled: Bool
    let systemImage: String
    let range: ClosedRange<Double>
    let accent: Color
    let showsStepButtons: Bool
    let onChange: (Double) -> Void

    @State private var draftValue: Double?
    @State private var isEditing = false

    init(
        title: String,
        value: Double?,
        isEnabled: Bool,
        systemImage: String,
        range: ClosedRange<Double> = 0...1,
        accent: Color = .teal,
        showsStepButtons: Bool = false,
        onChange: @escaping (Double) -> Void
    ) {
        self.title = title
        self.value = value
        self.isEnabled = isEnabled
        self.systemImage = systemImage
        self.range = range
        self.accent = accent
        self.showsStepButtons = showsStepButtons
        self.onChange = onChange
    }

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: systemImage)
                .foregroundStyle(isEnabled ? accent : .secondary)
                .frame(width: 18)
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 52, alignment: .leading)
            if showsStepButtons {
                nudgeButton(systemImage: "minus", delta: -stepSize)
            }
            Slider(
                value: Binding(
                    get: { displayedValue },
                    set: { updateValue($0) }
                ),
                in: range,
                onEditingChanged: { editing in
                    isEditing = editing
                    if !editing {
                        onChange(displayedValue)
                        draftValue = nil
                    }
                }
            )
            .disabled(!isEnabled)
            .tint(accent)
            .accessibilityLabel("\(title) volume")
            .accessibilityValue(accessibilityValue)
            .accessibilityHint(isEnabled ? "Adjusts \(title.lowercased()) volume" : "\(title) volume is not exposed by this device")
            if showsStepButtons {
                nudgeButton(systemImage: "plus", delta: stepSize)
            }
            percentPill
        }
        .help(isEnabled ? "\(title) volume" : "\(title) volume is not exposed by this device.")
        .animation(.easeOut(duration: 0.12), value: displayedValue)
    }

    private var displayedValue: Double {
        range.clamped(draftValue ?? value ?? range.lowerBound)
    }

    private var accessibilityValue: String {
        value == nil ? "Not available" : displayedValue.roundedPercentDescription
    }

    private var stepSize: Double {
        range.upperBound > 1 ? 0.05 : 0.02
    }

    private var percentPill: some View {
        Text(value == nil ? "N/A" : displayedValue.roundedPercentDescription)
            .font(.caption.monospacedDigit().weight(.semibold))
            .foregroundStyle(isEnabled ? accent : .secondary)
            .frame(minWidth: 46, alignment: .trailing)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(
                Capsule(style: .continuous)
                    .fill(isEnabled ? accent.opacity(isEditing ? 0.22 : 0.12) : Color.secondary.opacity(0.08))
            )
    }

    private func updateValue(_ newValue: Double) {
        let clamped = range.clamped(newValue)
        draftValue = clamped
        onChange(clamped)
    }

    private func nudgeButton(systemImage: String, delta: Double) -> some View {
        Button {
            updateValue(displayedValue + delta)
            draftValue = nil
        } label: {
            Image(systemName: systemImage)
                .font(.caption.weight(.bold))
                .frame(width: 18, height: 18)
        }
        .buttonStyle(.borderless)
        .foregroundStyle(isEnabled ? .secondary : .tertiary)
        .disabled(!isEnabled || value == nil)
        .accessibilityLabel(delta < 0 ? "Decrease \(title) volume" : "Increase \(title) volume")
    }
}

struct InlineVolumeSlider: View {
    let value: Double?
    let isEnabled: Bool
    let systemImage: String
    let range: ClosedRange<Double>
    let accent: Color
    let accessibilityLabel: String
    let accessibilityHint: String
    let onChange: (Double) -> Void

    @State private var draftValue: Double?
    @State private var isEditing = false

    init(
        value: Double?,
        isEnabled: Bool,
        systemImage: String = "speaker.wave.2.fill",
        range: ClosedRange<Double> = 0...1,
        accent: Color = .teal,
        accessibilityLabel: String,
        accessibilityHint: String,
        onChange: @escaping (Double) -> Void
    ) {
        self.value = value
        self.isEnabled = isEnabled
        self.systemImage = systemImage
        self.range = range
        self.accent = accent
        self.accessibilityLabel = accessibilityLabel
        self.accessibilityHint = accessibilityHint
        self.onChange = onChange
    }

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: systemImage)
                .font(.caption.weight(.semibold))
                .foregroundStyle(isEnabled ? accent : .secondary)
                .frame(width: 16)

            Slider(
                value: Binding(
                    get: { displayedValue },
                    set: { updateValue($0) }
                ),
                in: range,
                onEditingChanged: { editing in
                    isEditing = editing
                    if !editing {
                        onChange(displayedValue)
                        draftValue = nil
                    }
                }
            )
            .tint(accent)
            .disabled(!isEnabled)
            .accessibilityLabel(accessibilityLabel)
            .accessibilityValue(value == nil ? "Not available" : displayedValue.roundedPercentDescription)
            .accessibilityHint(accessibilityHint)

            Text(value == nil ? "N/A" : displayedValue.roundedPercentDescription)
                .font(.caption2.monospacedDigit().weight(.bold))
                .foregroundStyle(isEnabled ? accent : .secondary)
                .frame(width: 44, alignment: .trailing)
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(
                    Capsule(style: .continuous)
                        .fill(isEnabled ? accent.opacity(isEditing ? 0.22 : 0.12) : Color.secondary.opacity(0.08))
                )
        }
        .transaction { transaction in
            transaction.animation = isEditing ? nil : .easeOut(duration: 0.08)
        }
    }

    private var displayedValue: Double {
        range.clamped(draftValue ?? value ?? range.lowerBound)
    }

    private func updateValue(_ newValue: Double) {
        let clamped = range.clamped(newValue)
        draftValue = clamped
        onChange(clamped)
    }
}

private extension ClosedRange where Bound == Double {
    func clamped(_ value: Double) -> Double {
        Swift.min(Swift.max(value, lowerBound), upperBound)
    }
}
