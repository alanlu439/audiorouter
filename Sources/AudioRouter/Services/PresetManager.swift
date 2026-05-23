import Foundation

public final class PresetManager: ObservableObject {
    @Published public private(set) var presets: [AudioPreset] = []
    private let fileURL: URL

    public convenience init() {
        self.init(fileURL: try! AppSupport.fileURL(named: "presets.json"))
    }

    public init(fileURL: URL) {
        self.fileURL = fileURL
        load()
    }

    public func savePreset(_ preset: AudioPreset) {
        presets.insert(preset, at: 0)
        save()
    }

    public func rename(_ preset: AudioPreset, to name: String) {
        guard let index = presets.firstIndex(where: { $0.id == preset.id }) else { return }
        presets[index].name = name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? preset.name : name
        save()
    }

    public func delete(_ preset: AudioPreset) {
        presets.removeAll { $0.id == preset.id }
        save()
    }

    public func duplicate(_ preset: AudioPreset) {
        var copy = preset
        copy.id = UUID()
        copy.name = "\(preset.name) Copy"
        copy.createdAt = Date()
        presets.insert(copy, at: 0)
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
        presets = decoded.sorted { $0.createdAt > $1.createdAt }
        save()
    }

    public func reset() {
        presets.removeAll()
        save()
    }

    private func load() {
        guard let data = try? Data(contentsOf: fileURL),
              let decoded = try? JSONDecoder().decode([AudioPreset].self, from: data) else {
            presets = []
            return
        }
        presets = decoded.sorted { $0.createdAt > $1.createdAt }
    }

    private func save() {
        do {
            let data = try JSONEncoder().encode(presets)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            assertionFailure("Could not save AudioRouter presets: \(error)")
        }
    }
}
