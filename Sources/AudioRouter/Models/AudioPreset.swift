import Foundation

public struct AudioPreset: Identifiable, Codable, Hashable {
    public var id: UUID
    public var profileID: UUID
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

    private enum CodingKeys: String, CodingKey {
        case id
        case profileID
        case name
        case createdAt
        case outputDeviceUID
        case inputDeviceUID
        case systemVolume
        case inputVolume
        case systemMuted
        case appVolumes
        case mutedApps
        case appOutputAssignments
        case eqPreset
    }

    public init(
        id: UUID = UUID(),
        profileID: UUID = UserProfile.defaultProfileID,
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
        self.profileID = profileID
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

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        profileID = try container.decodeIfPresent(UUID.self, forKey: .profileID) ?? UserProfile.defaultProfileID
        name = try container.decode(String.self, forKey: .name)
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date()
        outputDeviceUID = try container.decodeIfPresent(String.self, forKey: .outputDeviceUID)
        inputDeviceUID = try container.decodeIfPresent(String.self, forKey: .inputDeviceUID)
        systemVolume = try container.decodeIfPresent(Double.self, forKey: .systemVolume)
        inputVolume = try container.decodeIfPresent(Double.self, forKey: .inputVolume)
        systemMuted = try container.decodeIfPresent(Bool.self, forKey: .systemMuted) ?? false
        appVolumes = try container.decodeIfPresent([String: Double].self, forKey: .appVolumes) ?? [:]
        mutedApps = try container.decodeIfPresent([String: Bool].self, forKey: .mutedApps) ?? [:]
        appOutputAssignments = try container.decodeIfPresent([String: String].self, forKey: .appOutputAssignments) ?? [:]
        eqPreset = try container.decodeIfPresent(EQPreset.self, forKey: .eqPreset) ?? .flat
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(profileID, forKey: .profileID)
        try container.encode(name, forKey: .name)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encodeIfPresent(outputDeviceUID, forKey: .outputDeviceUID)
        try container.encodeIfPresent(inputDeviceUID, forKey: .inputDeviceUID)
        try container.encodeIfPresent(systemVolume, forKey: .systemVolume)
        try container.encodeIfPresent(inputVolume, forKey: .inputVolume)
        try container.encode(systemMuted, forKey: .systemMuted)
        try container.encode(appVolumes, forKey: .appVolumes)
        try container.encode(mutedApps, forKey: .mutedApps)
        try container.encode(appOutputAssignments, forKey: .appOutputAssignments)
        try container.encode(eqPreset, forKey: .eqPreset)
    }
}
