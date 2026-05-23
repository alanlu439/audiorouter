import Foundation

public struct OutputGroup: Identifiable, Codable, Hashable {
    public var id: UUID
    public var name: String
    public var deviceUIDs: [String]

    public init(id: UUID = UUID(), name: String, deviceUIDs: [String]) {
        self.id = id
        self.name = name
        self.deviceUIDs = deviceUIDs
    }
}
