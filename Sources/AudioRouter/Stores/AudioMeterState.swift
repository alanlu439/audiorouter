import Combine
import Foundation

@MainActor
public final class AudioMeterState: ObservableObject {
    public struct Snapshot: Equatable {
        public var sourceMeters: [String: Double]
        public var deviceMeters: [String: Double]
        public var systemOutputMeter: Double
        public var inputMeter: Double

        public init(
            sourceMeters: [String: Double] = [:],
            deviceMeters: [String: Double] = [:],
            systemOutputMeter: Double = 0,
            inputMeter: Double = 0
        ) {
            self.sourceMeters = sourceMeters
            self.deviceMeters = deviceMeters
            self.systemOutputMeter = systemOutputMeter
            self.inputMeter = inputMeter
        }
    }

    @Published public private(set) var snapshot = Snapshot()

    public func update(
        systemOutput: Double,
        input: Double,
        sources: [String: Double],
        devices: [String: Double]
    ) {
        let next = Snapshot(
            sourceMeters: sources,
            deviceMeters: devices,
            systemOutputMeter: systemOutput,
            inputMeter: input
        )
        guard next != snapshot else { return }
        snapshot = next
    }

    public func removeSource(_ sourceID: String) {
        guard snapshot.sourceMeters[sourceID] != nil else { return }
        var sources = snapshot.sourceMeters
        sources.removeValue(forKey: sourceID)
        update(
            systemOutput: snapshot.systemOutputMeter,
            input: snapshot.inputMeter,
            sources: sources,
            devices: snapshot.deviceMeters
        )
    }
}
