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
        HStack(alignment: .center, spacing: 8) {
            Image(systemName: systemImage)
                .font(.headline.weight(.semibold))
                .frame(width: 20, height: 20, alignment: .center)
            Text(title)
                .font(.headline)
                .lineLimit(1)
            Spacer()
            if let trailing {
                Text(trailing)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(height: 20, alignment: .center)
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

struct SourceQualityPill: View {
    let label: String
    let isLive: Bool

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: isLive ? "waveform.circle.fill" : "waveform.circle")
                .font(.system(size: 8, weight: .bold))
                .accessibilityHidden(true)
            Text(label)
                .font(.system(size: 9, weight: .heavy, design: .monospaced))
                .lineLimit(1)
        }
        .foregroundStyle(isLive ? .cyan : .secondary)
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background((isLive ? Color.cyan : Color.secondary).opacity(0.10), in: Capsule())
        .overlay {
            Capsule()
                .stroke((isLive ? Color.cyan : Color.secondary).opacity(isLive ? 0.28 : 0.16), lineWidth: 1)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(isLive ? "Fetched source audio quality \(label)" : "Source audio quality \(label)")
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
    let step: Double
    let accent: Color
    let showsStepButtons: Bool
    let nudgeStep: Double
    let onChange: (Double) -> Void

    @State private var draftValue: Double?
    @State private var isEditing = false

    init(
        title: String,
        value: Double?,
        isEnabled: Bool,
        systemImage: String,
        range: ClosedRange<Double> = 0...1,
        step: Double = 0.01,
        accent: Color = .teal,
        showsStepButtons: Bool = false,
        nudgeStep: Double = 0.05,
        onChange: @escaping (Double) -> Void
    ) {
        self.title = title
        self.value = value
        self.isEnabled = isEnabled
        self.systemImage = systemImage
        self.range = range
        self.step = step
        self.accent = accent
        self.showsStepButtons = showsStepButtons
        self.nudgeStep = nudgeStep
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
            SmoothVolumeFader(
                value: displayedValue,
                isEnabled: isEnabled,
                range: range,
                step: step,
                accent: accent,
                accessibilityLabel: "\(title) volume",
                accessibilityValue: accessibilityValue,
                accessibilityHint: isEnabled ? "Adjusts \(title.lowercased()) volume" : "\(title) volume is not exposed by this device",
                onEditingChanged: updateEditingState,
                onChange: updateValue
            )
            if showsStepButtons {
                nudgeButton(systemImage: "plus", delta: stepSize)
            }
            percentPill
        }
        .help(isEnabled ? "\(title) volume" : "\(title) volume is not exposed by this device.")
    }

    private var displayedValue: Double {
        steppedValue(draftValue ?? value ?? range.lowerBound)
    }

    private var accessibilityValue: String {
        value == nil ? "Not available" : displayedValue.roundedPercentDescription
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
        let adjusted = steppedValue(newValue)
        draftValue = adjusted
        onChange(adjusted)
    }

    private func updateEditingState(_ editing: Bool) {
        isEditing = editing
        if !editing {
            onChange(displayedValue)
            draftValue = nil
        }
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

    private var stepSize: Double {
        nudgeStep
    }

    private func steppedValue(_ value: Double) -> Double {
        range.snapped(value, to: step)
    }
}

struct InlineVolumeSlider: View {
    let value: Double?
    let isEnabled: Bool
    let systemImage: String
    let range: ClosedRange<Double>
    let step: Double
    let accent: Color
    let showsStepButtons: Bool
    let nudgeStep: Double
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
        step: Double = 0.01,
        accent: Color = .teal,
        showsStepButtons: Bool = false,
        nudgeStep: Double = 0.05,
        accessibilityLabel: String,
        accessibilityHint: String,
        onChange: @escaping (Double) -> Void
    ) {
        self.value = value
        self.isEnabled = isEnabled
        self.systemImage = systemImage
        self.range = range
        self.step = step
        self.accent = accent
        self.showsStepButtons = showsStepButtons
        self.nudgeStep = nudgeStep
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

            if showsStepButtons {
                nudgeButton(systemImage: "minus", delta: -nudgeStep)
            }

            SmoothVolumeFader(
                value: displayedValue,
                isEnabled: isEnabled,
                range: range,
                step: step,
                accent: accent,
                accessibilityLabel: accessibilityLabel,
                accessibilityValue: value == nil ? "Not available" : displayedValue.roundedPercentDescription,
                accessibilityHint: accessibilityHint,
                onEditingChanged: updateEditingState,
                onChange: updateValue
            )
            .frame(minWidth: showsStepButtons ? 96 : 80)

            if showsStepButtons {
                nudgeButton(systemImage: "plus", delta: nudgeStep)
            }

            percentPill
        }
        .help(accessibilityHint)
        .transaction { transaction in
            transaction.animation = isEditing ? nil : .easeOut(duration: 0.08)
        }
    }

    private var displayedValue: Double {
        range.snapped(draftValue ?? value ?? range.lowerBound, to: step)
    }

    private func updateValue(_ newValue: Double) {
        let adjusted = range.snapped(newValue, to: step)
        draftValue = adjusted
        onChange(adjusted)
    }

    private func updateEditingState(_ editing: Bool) {
        isEditing = editing
        if !editing {
            onChange(displayedValue)
            draftValue = nil
        }
    }

    private var percentPill: some View {
        Text(value == nil ? "N/A" : displayedValue.roundedPercentDescription)
            .font(.caption2.monospacedDigit().weight(.bold))
            .foregroundStyle(isEnabled ? accent : .secondary)
            .frame(width: 48, alignment: .trailing)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(
                Capsule(style: .continuous)
                    .fill(isEnabled ? accent.opacity(isEditing ? 0.24 : 0.13) : Color.secondary.opacity(0.08))
            )
    }

    private func nudgeButton(systemImage: String, delta: Double) -> some View {
        Button {
            updateValue(displayedValue + delta)
            draftValue = nil
        } label: {
            Image(systemName: systemImage)
                .font(.system(size: 10, weight: .bold))
                .frame(width: 16, height: 16)
        }
        .buttonStyle(.borderless)
        .foregroundStyle(isEnabled ? .secondary : .tertiary)
        .disabled(!isEnabled || value == nil)
        .accessibilityLabel(delta < 0 ? "Decrease volume" : "Increase volume")
    }
}

private struct SmoothVolumeFader: View {
    let value: Double
    let isEnabled: Bool
    let range: ClosedRange<Double>
    let step: Double
    let accent: Color
    let accessibilityLabel: String
    let accessibilityValue: String
    let accessibilityHint: String
    let onEditingChanged: (Bool) -> Void
    let onChange: (Double) -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isDragging = false

    private let knobSize: CGFloat = 17
    private let trackHeight: CGFloat = 8

    var body: some View {
        GeometryReader { proxy in
            let width = max(proxy.size.width, knobSize)
            let trackWidth = max(1, width - knobSize)
            let normalized = normalizedValue(value)
            let fillWidth = trackWidth * normalized

            ZStack(alignment: .leading) {
                Capsule(style: .continuous)
                    .fill(Color.white.opacity(isEnabled ? 0.09 : 0.055))
                    .frame(width: trackWidth, height: trackHeight)
                    .offset(x: knobSize / 2)

                Capsule(style: .continuous)
                    .fill(accent.opacity(isEnabled ? 0.92 : 0.35))
                    .frame(width: fillWidth, height: trackHeight)
                    .offset(x: knobSize / 2)

                Circle()
                    .fill(isEnabled ? Color.white.opacity(0.90) : Color.secondary.opacity(0.55))
                    .overlay {
                        Circle()
                            .stroke(accent.opacity(isEnabled ? (isDragging ? 0.92 : 0.62) : 0.28), lineWidth: isDragging ? 2 : 1)
                    }
                    .shadow(color: accent.opacity(isEnabled && isDragging ? 0.42 : 0.22), radius: isDragging ? 7 : 3, x: 0, y: 1)
                    .frame(width: knobSize, height: knobSize)
                    .offset(x: fillWidth)
            }
            .frame(height: 24, alignment: .center)
            .contentShape(Rectangle())
            .gesture(dragGesture(trackWidth: trackWidth))
            .allowsHitTesting(isEnabled)
            .animation(faderAnimation, value: value)
            .animation(faderAnimation, value: isDragging)
        }
        .frame(height: 24)
        .opacity(isEnabled ? 1 : 0.58)
        .accessibilityElement()
        .accessibilityLabel(accessibilityLabel)
        .accessibilityValue(accessibilityValue)
        .accessibilityHint(accessibilityHint)
        .accessibilityAdjustableAction { direction in
            guard isEnabled else { return }
            switch direction {
            case .increment:
                onChange(range.snapped(value + step, to: step))
            case .decrement:
                onChange(range.snapped(value - step, to: step))
            @unknown default:
                break
            }
        }
    }

    private var faderAnimation: Animation? {
        guard !reduceMotion, !isDragging else { return nil }
        return .interpolatingSpring(stiffness: 320, damping: 30)
    }

    private func dragGesture(trackWidth: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                guard isEnabled else { return }
                if !isDragging {
                    isDragging = true
                    onEditingChanged(true)
                }
                onChange(valueForDragLocation(value.location.x, trackWidth: trackWidth))
            }
            .onEnded { value in
                guard isEnabled else { return }
                onChange(valueForDragLocation(value.location.x, trackWidth: trackWidth))
                isDragging = false
                onEditingChanged(false)
            }
    }

    private func valueForDragLocation(_ x: CGFloat, trackWidth: CGFloat) -> Double {
        guard trackWidth > 0 else { return range.lowerBound }
        let adjustedX = min(max(x - knobSize / 2, 0), trackWidth)
        let normalized = Double(adjustedX / trackWidth)
        let rawValue = range.lowerBound + (range.upperBound - range.lowerBound) * normalized
        return range.snapped(rawValue, to: step)
    }

    private func normalizedValue(_ value: Double) -> CGFloat {
        let clampedValue = range.clamped(value)
        let span = range.upperBound - range.lowerBound
        guard span > 0 else { return 0 }
        return CGFloat((clampedValue - range.lowerBound) / span)
    }
}

private extension ClosedRange where Bound == Double {
    func clamped(_ value: Double) -> Double {
        Swift.min(Swift.max(value, lowerBound), upperBound)
    }

    func snapped(_ value: Double, to step: Double) -> Double {
        let clampedValue = clamped(value)
        guard step > 0 else { return clampedValue }
        let snappedValue = lowerBound + ((clampedValue - lowerBound) / step).rounded() * step
        return clamped((snappedValue * 1_000).rounded() / 1_000)
    }
}
