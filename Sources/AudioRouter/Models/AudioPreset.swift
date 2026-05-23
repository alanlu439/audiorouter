import Foundation

public struct AudioPreset: Identifiable, Codable, Hashable {
    public var id: UUID
    public var name: String
    public var createdAt: Date
    public var outputDeviceUID: String?
    public var inputDeviceUID: String?
    public var systemVolume: Double?
    public var inputVolume: Double?
    public var systemMuted: Bool
    public var appVolumes: [String: Double]
    public var mutedApps: [String: Bool]
    public var appOutputAssignments: [String: String]
    public var eqPreset: EQPreset

    public init(
        id: UUID = UUID(),
        name: String,
        createdAt: Date = Date(),
        outputDeviceUID: String?,
        inputDeviceUID: String?,
        systemVolume: Double?,
        inputVolume: Double?,
        systemMuted: Bool,
        appVolumes: [String: Double],
        mutedApps: [String: Bool],
        appOutputAssignments: [String: String],
        eqPreset: EQPreset
    ) {
        self.id = id
        self.name = name
        self.createdAt = createdAt
        self.outputDeviceUID = outputDeviceUID
        self.inputDeviceUID = inputDeviceUID
        self.systemVolume = systemVolume
        self.inputVolume = inputVolume
        self.systemMuted = systemMuted
        self.appVolumes = appVolumes
        self.mutedApps = mutedApps
        self.appOutputAssignments = appOutputAssignments
        self.eqPreset = eqPreset
    }
}
