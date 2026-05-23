import Foundation

public final class EQManager: ObservableObject {
    @Published public private(set) var state: EQState
    private let defaults: UserDefaults
    private let key = "AudioRouter.EQState"

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let data = defaults.data(forKey: key),
           let decoded = try? JSONDecoder().decode(EQState.self, from: data) {
            state = decoded
        } else {
            state = EQState()
        }
    }

    public func applyPreset(_ preset: EQPreset) {
        state = EQState(selectedPreset: preset, bands: preset.bands)
        save()
        // TODO: Applying this EQ to all system audio requires owning the output stream through
        // a virtual audio device, AudioServerPlugIn, or app-specific audio engine.
    }

    public func setBand(index: Int, gain: Double) {
        guard state.bands.indices.contains(index) else { return }
        state.bands[index] = max(-12, min(12, gain))
        save()
    }

    private func save() {
        if let data = try? JSONEncoder().encode(state) {
            defaults.set(data, forKey: key)
        }
    }
}
