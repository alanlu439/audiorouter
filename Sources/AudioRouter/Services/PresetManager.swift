import Foundation

public final class PresetManager: ObservableObject {
    @Published public private(set) var presets: [AudioPreset] = []
    private let fileURL: URL
    private var allPresets: [AudioPreset] = []
    private var activeProfileID: UUID

    public convenience init() {
        self.init(fileURL: try! AppSupport.fileURL(named: "presets.json"))
    }

    public init(
        fileURL: URL,
        activeProfileID: UUID = UserProfile.defaultProfileID
    ) {
        self.fileURL = fileURL
        self.activeProfileID = activeProfileID
        load()
    }

    public func setActiveProfileID(_ profileID: UUID) {
        guard activeProfileID != profileID else { return }
        activeProfileID = profileID
        publishActivePresets()
    }

    public func savePreset(_ preset: AudioPreset) {
        var scopedPreset = preset
        scopedPreset.profileID = activeProfileID
        allPresets.insert(scopedPreset, at: 0)
        publishActivePresets()
        save()
    }

    public func rename(_ preset: AudioPreset, to name: String) {
        guard let index = allPresets.firstIndex(where: { $0.id == preset.id }) else { return }
        allPresets[index].name = name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? preset.name : name
        publishActivePresets()
        save()
    }

    public func delete(_ preset: AudioPreset) {
        allPresets.removeAll { $0.id == preset.id }
        publishActivePresets()
        save()
    }

    public func duplicate(_ preset: AudioPreset) {
        var copy = preset
        copy.id = UUID()
        copy.profileID = activeProfileID
        copy.name = "\(preset.name) Copy"
        copy.createdAt = Date()
        allPresets.insert(copy, at: 0)
        publishActivePresets()
        save()
    }

    public func exportJSON() -> String {
        guard let data = try? JSONEncoder().encode(presets),
              let text = String(data: data, encoding: .utf8) else {
            return "[]"
        }
        return text
    }

    public func importJSON(_ text: String) {
        guard let data = text.data(using: .utf8),
              let decoded = try? JSONDecoder().decode([AudioPreset].self, from: data) else {
            return
        }
        let scopedPresets = decoded.map { preset in
            var scopedPreset = preset
            scopedPreset.profileID = activeProfileID
            return scopedPreset
        }
        allPresets.removeAll { $0.profileID == activeProfileID }
        allPresets.append(contentsOf: scopedPresets)
        publishActivePresets()
        save()
    }

    public func reset() {
        allPresets.removeAll()
        publishActivePresets()
        save()
    }

    private func load() {
        guard let data = try? Data(contentsOf: fileURL),
              let decoded = try? JSONDecoder().decode([AudioPreset].self, from: data) else {
            allPresets = []
            publishActivePresets()
            return
        }
        allPresets = decoded.sorted { $0.createdAt > $1.createdAt }
        publishActivePresets()
    }

    private func save() {
        do {
            let data = try JSONEncoder().encode(allPresets)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            assertionFailure("Could not save AudioRouter presets: \(error)")
        }
    }

    private func publishActivePresets() {
        presets = allPresets
            .filter { $0.profileID == activeProfileID }
            .sorted { $0.createdAt > $1.createdAt }
    }
}
