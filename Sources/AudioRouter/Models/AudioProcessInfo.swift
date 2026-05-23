import Foundation

public struct AudioProcessInfo: Identifiable, Codable, Hashable {
    public var id: UInt32 { processObjectID }

    public let processObjectID: UInt32
    public let pid: Int32
    public let bundleID: String?
    public let displayName: String
    public let isRunningOutput: Bool
    public let deviceObjectIDs: [UInt32]

    public init(
        processObjectID: UInt32,
        pid: Int32,
        bundleID: String?,
        displayName: String,
        isRunningOutput: Bool,
        deviceObjectIDs: [UInt32]
    ) {
        self.processObjectID = processObjectID
        self.pid = pid
        self.bundleID = bundleID
        self.displayName = displayName
        self.isRunningOutput = isRunningOutput
        self.deviceObjectIDs = deviceObjectIDs
    }

    public var stableMatchKey: String {
        if let bundleID, !bundleID.isEmpty {
            return "bundle:\(bundleID)"
        }
        return "pid:\(pid)"
    }
}
