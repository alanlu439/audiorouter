import SwiftUI

struct EQView: View {
    @ObservedObject var eqManager: EQManager
    var compact: Bool = false

    var body: some View {
        DockCard {
            SectionHeader(title: "Equalizer", systemImage: "waveform")

            Picker("Preset", selection: presetSelection) {
                ForEach(EQPreset.allCases) { preset in
                    Text(preset.rawValue).tag(preset)
                }
            }
            .pickerStyle(.menu)

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

            Text("EQ settings are saved. Real-time system-wide EQ requires a driver-backed audio engine.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var presetSelection: Binding<EQPreset> {
        Binding(
            get: { eqManager.state.selectedPreset },
            set: { eqManager.applyPreset($0) }
        )
    }
}
