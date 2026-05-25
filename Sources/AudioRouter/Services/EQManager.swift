import Foundation

public final class EQManager: ObservableObject {
    @Published public private(set) var state: EQState
    private let defaults: UserDefaults
    private let key = "AudioRouter.EQState"
    private var pendingSaveWorkItem: DispatchWorkItem?

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let data = defaults.data(forKey: key),
           let decoded = try? JSONDecoder().decode(EQState.self, from: data) {
            state = decoded
        } else {
            state = EQState()
        }
    }

    deinit {
        save()
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
        state.selectedPreset = .custom
        scheduleSave()
    }

    public func reset() {
        applyPreset(.flat)
    }

    public func saveCustomPreset() {
        state.selectedPreset = .custom
        save()
    }

    private func save() {
        pendingSaveWorkItem?.cancel()
        pendingSaveWorkItem = nil
        if let data = try? JSONEncoder().encode(state) {
            defaults.set(data, forKey: key)
        }
    }

    private func scheduleSave() {
        pendingSaveWorkItem?.cancel()
        let workItem = DispatchWorkItem { [weak self] in
            self?.save()
        }
        pendingSaveWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25, execute: workItem)
    }
}
