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
            state = Self.normalized(decoded)
        } else {
            state = EQState()
        }
    }

    deinit {
        save()
    }

    public func applyPreset(_ preset: EQPreset) {
        if preset == .custom {
            state = EQState(
                selectedPreset: .custom,
                bands: Self.normalizedBands(state.customBands),
                customBands: Self.normalizedBands(state.customBands)
            )
        } else {
            state = EQState(
                selectedPreset: preset,
                bands: preset.bands,
                customBands: Self.normalizedBands(state.customBands)
            )
        }
        save()
    }

    public func setBand(index: Int, gain: Double) {
        guard state.bands.indices.contains(index) else { return }
        state.bands[index] = max(-12, min(12, gain))
        state.selectedPreset = .custom
        state.customBands = state.bands
        scheduleSave()
    }

    public func reset() {
        applyPreset(.flat)
    }

    public func saveCustomPreset() {
        state.selectedPreset = .custom
        state.customBands = Self.normalizedBands(state.bands)
        save()
    }

    private static func normalized(_ state: EQState) -> EQState {
        EQState(
            selectedPreset: state.selectedPreset,
            bands: normalizedBands(state.bands),
            customBands: normalizedBands(state.customBands)
        )
    }

    private static func normalizedBands(_ bands: [Double]) -> [Double] {
        var normalized = Array(bands.prefix(10)).map { max(-12, min(12, $0)) }
        while normalized.count < 10 {
            normalized.append(0)
        }
        return normalized
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
