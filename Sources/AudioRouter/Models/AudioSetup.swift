import Foundation

public struct AudioSetup: Identifiable, Codable, Hashable {
    public var id: UUID
    public var name: String
    public var systemOutputDeviceID: String?
    public var systemInputDeviceID: String?
    public var systemVolume: Double?
    public var appRoutes: [AudioRoute]
    public var eqPreset: EQPreset
    public var createdAt: Date
    public var updatedAt: Date

    public init(
        id: UUID = UUID(),
        name: String,
        systemOutputDeviceID: String? = nil,
        systemInputDeviceID: String? = nil,
        systemVolume: Double? = nil,
        appRoutes: [AudioRoute] = [],
        eqPreset: EQPreset = .flat,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.systemOutputDeviceID = systemOutputDeviceID
        self.systemInputDeviceID = systemInputDeviceID
        self.systemVolume = systemVolume
        self.appRoutes = appRoutes
        self.eqPreset = eqPreset
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
