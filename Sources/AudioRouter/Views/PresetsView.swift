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
        ConsoleFrame {
            VStack(alignment: .leading, spacing: 12) {
                ConsolePageHeader(
                    title: "Setups",
                    subtitle: "Saved routing scenes for \(store.activeUserProfile.displayName).",
                    systemImage: "square.stack.3d.up",
                    tint: ConsolePalette.amber
                ) {
                    StatusLabel(text: "\(store.presetManager.presets.count) saved", status: store.presetManager.presets.isEmpty ? .savedOnly : .working)
                }

                ConsolePanel(
                    title: "Saved Setups",
                    systemImage: "square.stack.3d.up",
                    trailing: "\(store.presetManager.presets.count)",
                    tint: ConsolePalette.amber
                ) {
                    VStack(alignment: .leading, spacing: 12) {
                        actionBar

                        if showImport {
                            TextEditor(text: $importText)
                                .frame(height: 90)
                                .background(ConsolePalette.inset.opacity(0.86), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                            Button("Import Setups") {
                                store.presetManager.importJSON(importText)
                                showImport = false
                                importText = ""
                            }
                            .controlSize(.small)
                        }

                        ConsoleSectionMarker(
                            title: "Scenes",
                            detail: "\(store.presetManager.presets.count) available",
                            tint: ConsolePalette.amber
                        )

                        if store.presetManager.presets.isEmpty {
                            emptyState
                        } else {
                            LazyVGrid(columns: [GridItem(.adaptive(minimum: 280), spacing: 12)], spacing: 12) {
                                ForEach(store.presetManager.presets.prefix(compact ? 3 : store.presetManager.presets.count)) { preset in
                                    presetRow(preset)
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    private var actionBar: some View {
        HStack(spacing: 8) {
            Button {
                store.saveCurrentSetup()
            } label: {
                Label("Save Current Setup", systemImage: "plus.circle.fill")
            }
            .buttonStyle(.borderedProminent)
            .tint(ConsolePalette.teal)
            Button {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(store.presetManager.exportJSON(), forType: .string)
            } label: {
                Label("Export JSON", systemImage: "square.and.arrow.up")
            }
            Button {
                showImport.toggle()
            } label: {
                Label(showImport ? "Hide Import" : "Import JSON", systemImage: "square.and.arrow.down")
            }
            Spacer()
        }
        .controlSize(.small)
        .padding(.horizontal, 11)
        .padding(.vertical, 8)
        .background(ConsolePalette.inset.opacity(0.72), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .stroke(ConsolePalette.stroke, lineWidth: 1)
        }
    }

    private var emptyState: some View {
        HStack(spacing: 10) {
            Image(systemName: "tray")
                .foregroundStyle(ConsolePalette.amber)
            Text("Saved setups will appear here.")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Spacer()
        }
        .padding(12)
        .background(ConsolePalette.inset.opacity(0.72), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
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
        .background(ConsolePalette.inset.opacity(0.78), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color.white.opacity(0.07), lineWidth: 1)
        }
    }

    private func name(for uid: String?) -> String? {
        guard let uid else { return nil }
        return store.devices.first { $0.uid == uid }?.name
    }
}
