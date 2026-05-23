import Foundation

public struct AppSoundSource: Identifiable, Codable, Hashable {
    public var id: String {
        bundleID.map { "bundle:\($0)" }
            ?? processObjectID.map { "process:\($0)" }
            ?? appURL.map { "url:\($0.path)" }
            ?? "name:\(displayName)"
    }

    public let displayName: String
    public let bundleID: String?
    public let appURL: URL?
    public let processObjectID: UInt32?
    public let pid: Int32?
    public let isRunning: Bool
    public let isRunningOutput: Bool
    public let deviceObjectIDs: [UInt32]

    public init(
        displayName: String,
        bundleID: String?,
        appURL: URL?,
        processObjectID: UInt32?,
        pid: Int32?,
        isRunning: Bool,
        isRunningOutput: Bool,
        deviceObjectIDs: [UInt32]
    ) {
        self.displayName = displayName
        self.bundleID = bundleID
        self.appURL = appURL
        self.processObjectID = processObjectID
        self.pid = pid
        self.isRunning = isRunning
        self.isRunningOutput = isRunningOutput
        self.deviceObjectIDs = deviceObjectIDs
    }

    public init(process: AudioProcessInfo) {
        self.init(
            displayName: process.displayName,
            bundleID: process.bundleID,
            appURL: nil,
            processObjectID: process.processObjectID,
            pid: process.pid,
            isRunning: true,
            isRunningOutput: process.isRunningOutput,
            deviceObjectIDs: process.deviceObjectIDs
        )
    }

    public var audioProcessInfo: AudioProcessInfo {
        AudioProcessInfo(
            processObjectID: processObjectID ?? 0,
            pid: pid ?? 0,
            bundleID: bundleID,
            displayName: displayName,
            isRunningOutput: isRunningOutput,
            deviceObjectIDs: deviceObjectIDs
        )
    }
}
