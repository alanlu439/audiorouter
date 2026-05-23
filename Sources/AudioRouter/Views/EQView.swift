import SwiftUI

struct EQView: View {
    @ObservedObject var eqManager: EQManager
    var compact: Bool = false
    @State private var showBefore = false

    var body: some View {
        DockCard {
            SectionHeader(title: "Equalizer", systemImage: "waveform")

            HStack {
                ForEach(EQPreset.allCases) { preset in
                    Button(preset.rawValue) {
                        eqManager.applyPreset(preset)
                    }
                    .buttonStyle(.bordered)
                    .tint(eqManager.state.selectedPreset == preset ? .teal : .secondary)
                }
                Spacer()
                Toggle("Before", isOn: $showBefore)
                    .toggleStyle(.switch)
            }

            EQCurveView(bands: showBefore ? EQPreset.flat.bands : eqManager.state.bands)
                .frame(height: compact ? 54 : 90)

            HStack(alignment: .bottom, spacing: compact ? 6 : 10) {
                ForEach(EQPreset.bandLabels.indices, id: \.self) { index in
                    VStack(spacing: 6) {
                        Slider(
                            value: Binding(
                                get: { eqManager.state.bands[index] },
                                set: { eqManager.setBand(index: index, gain: $0) }
                            ),
                            in: -12...12
                        )
                        .rotationEffect(.degrees(-90))
                        .frame(width: compact ? 26 : 34, height: compact ? 92 : 120)
                        Text(EQPreset.bandLabels[index])
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .frame(width: compact ? 28 : 36)
                    }
                }
            }
            .frame(maxWidth: .infinity)

            HStack {
                Button {
                    eqManager.reset()
                } label: {
                    Label("Reset", systemImage: "arrow.counterclockwise")
                }
                Button {
                    eqManager.saveCustomPreset()
                } label: {
                    Label("Save Custom EQ", systemImage: "square.and.arrow.down")
                }
                Spacer()
                StatusLabel(text: showBefore ? "Before" : eqManager.state.selectedPreset.rawValue, status: showBefore ? .simulated : .working)
            }

            Text("EQ settings are saved. Real-time system-wide EQ requires a driver-backed audio engine.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

private struct EQCurveView: View {
    let bands: [Double]

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(.black.opacity(0.16))
                Path { path in
                    guard !bands.isEmpty else { return }
                    for index in bands.indices {
                        let x = geometry.size.width * CGFloat(index) / CGFloat(max(1, bands.count - 1))
                        let normalized = CGFloat((bands[index] + 12) / 24)
                        let y = geometry.size.height * (1 - normalized)
                        if index == bands.startIndex {
                            path.move(to: CGPoint(x: x, y: y))
                        } else {
                            path.addLine(to: CGPoint(x: x, y: y))
                        }
                    }
                }
                .stroke(.teal, style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
            }
        }
    }
}
