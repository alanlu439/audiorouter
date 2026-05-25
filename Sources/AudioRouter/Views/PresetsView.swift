import AppKit
import SwiftUI

struct PresetsView: View {
    @ObservedObject var store: AudioRouterStore
    var compact: Bool = false
    @State private var renamingID: UUID?
    @State private var renameText = ""
    @State private var importText = ""
    @State private var showImport = false

    var body: some View {
        DockCard {
            SectionHeader(title: "Setups", systemImage: "square.stack.3d.up", trailing: "\(store.presetManager.presets.count)")

            HStack {
                Button {
                    store.saveCurrentSetup()
                } label: {
                    Label("Save Current Setup", systemImage: "plus.circle.fill")
                }
                .buttonStyle(.borderedProminent)
                Button {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(store.presetManager.exportJSON(), forType: .string)
                } label: {
                    Label("Export JSON", systemImage: "square.and.arrow.up")
                }
                Button {
                    showImport.toggle()
                } label: {
                    Label("Import JSON", systemImage: "square.and.arrow.down")
                }
            }

            if !compact {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Useful Scenes")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 170), spacing: 8)], spacing: 8) {
                        ForEach(SuggestedSetupKind.allCases) { kind in
                            Button {
                                store.saveSuggestedSetup(kind)
                            } label: {
                                Label(kind.rawValue, systemImage: kind.systemImage)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .buttonStyle(.bordered)
                            .help(kind.description)
                        }
                    }
                }
                .padding(10)
                .background(.secondary.opacity(0.06), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            }

            if showImport {
                TextEditor(text: $importText)
                    .frame(height: 90)
                    .background(.black.opacity(0.12), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                Button("Import Setups") {
                    store.presetManager.importJSON(importText)
                    showImport = false
                    importText = ""
                }
            }

            if store.presetManager.presets.isEmpty {
                Text("Saved setups will appear here.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 280), spacing: 12)], spacing: 12) {
                    ForEach(store.presetManager.presets.prefix(compact ? 3 : store.presetManager.presets.count)) { preset in
                        presetRow(preset)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func presetRow(_ preset: AudioPreset) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            if renamingID == preset.id {
                TextField("Name", text: $renameText)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit {
                        store.presetManager.rename(preset, to: renameText)
                        renamingID = nil
                    }
            } else {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(preset.name)
                            .font(.headline)
                            .lineLimit(1)
                        Text("EQ \(preset.eqPreset.rawValue)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    StatusLabel(text: "Saved", status: .working)
                }
            }

            VStack(alignment: .leading, spacing: 5) {
                Text("Output: \(name(for: preset.outputDeviceUID) ?? "Follow System")")
                Text("Input: \(name(for: preset.inputDeviceUID) ?? "Default Input")")
                Text("Routes: \(preset.appOutputAssignments.count) · Muted: \(preset.mutedApps.values.filter { $0 }.count)")
            }
            .font(.caption)
            .foregroundStyle(.secondary)

            HStack {
                Button("Apply") {
                    store.applyPreset(preset)
                }
                Button {
                    store.presetManager.duplicate(preset)
                } label: {
                    Image(systemName: "plus.square.on.square")
                }
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
                Button(role: .destructive) {
                    store.presetManager.delete(preset)
                } label: {
                    Image(systemName: "trash")
                }
            }
            .buttonStyle(.bordered)
        }
        .padding(12)
        .background(.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func name(for uid: String?) -> String? {
        guard let uid else { return nil }
        return store.devices.first { $0.uid == uid }?.name
    }
}
