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

struct AppSessionIcon: View {
    let session: AudioAppSession

    var body: some View {
        Group {
            if let path = session.iconPath {
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
        }
        .padding(10)
        .background(.blue.opacity(0.10), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

struct VolumeSlider: View {
    let title: String
    let value: Double?
    let isEnabled: Bool
    let systemImage: String
    let onChange: (Double) -> Void

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: systemImage)
                .foregroundStyle(isEnabled ? .primary : .secondary)
                .frame(width: 18)
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 48, alignment: .leading)
            Slider(
                value: Binding(
                    get: { value ?? 0 },
                    set: { onChange($0) }
                ),
                in: 0...1
            )
            .disabled(!isEnabled)
            Text(value.map { "\(($0 * 100).rounded().formatted(.number.precision(.fractionLength(0))))%" } ?? "N/A")
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(width: 42, alignment: .trailing)
        }
        .help(isEnabled ? "" : "\(title) is not exposed by this device.")
    }
}
