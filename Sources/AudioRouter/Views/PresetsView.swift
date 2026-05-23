import SwiftUI

struct PresetsView: View {
    @ObservedObject var store: AudioRouterStore
    var compact: Bool = false
    @State private var renamingID: UUID?
    @State private var renameText = ""

    var body: some View {
        DockCard {
            SectionHeader(title: "Setups", systemImage: "square.stack.3d.up", trailing: "\(store.presetManager.presets.count)")

            Button {
                store.saveCurrentSetup()
            } label: {
                Label("Save Current Setup", systemImage: "plus.circle.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)

            if store.presetManager.presets.isEmpty {
                Text("Saved setups will appear here.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                VStack(spacing: 8) {
                    ForEach(store.presetManager.presets.prefix(compact ? 3 : store.presetManager.presets.count)) { preset in
                        presetRow(preset)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func presetRow(_ preset: AudioPreset) -> some View {
        HStack(spacing: 8) {
            if renamingID == preset.id {
                TextField("Name", text: $renameText)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit {
                        store.presetManager.rename(preset, to: renameText)
                        renamingID = nil
                    }
            } else {
                VStack(alignment: .leading, spacing: 2) {
                    Text(preset.name)
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)
                    Text(preset.eqPreset.rawValue)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            Button("Apply") {
                store.applyPreset(preset)
            }
            .buttonStyle(.borderless)
            Button {
                if renamingID == preset.id {
                    store.presetManager.rename(preset, to: renameText)
                    renamingID = nil
                } else {
                    renameText = preset.name
                    renamingID = preset.id
                }
            } label: {
                Image(systemName: renamingID == preset.id ? "checkmark" : "pencil")
            }
            .buttonStyle(.borderless)
            Button {
                store.presetManager.delete(preset)
            } label: {
                Image(systemName: "trash")
            }
            .buttonStyle(.borderless)
            .foregroundStyle(.red)
        }
        .padding(.vertical, 3)
    }
}
