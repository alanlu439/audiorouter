import Foundation

public struct OutputDeviceGroup: Identifiable, Codable, Hashable {
    public var id: UUID
    public var name: String
    public var deviceUIDs: [String]
    public var perDeviceVolumes: [String: Double]
    public var createdAt: Date

    public init(
        id: UUID = UUID(),
        name: String,
        deviceUIDs: [String] = [],
        perDeviceVolumes: [String: Double] = [:],
        createdAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.deviceUIDs = deviceUIDs
        self.perDeviceVolumes = perDeviceVolumes
        self.createdAt = createdAt
    }

    public var routeTargetID: String {
        "group:\(id.uuidString)"
    }
}
