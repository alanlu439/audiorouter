import Foundation

public protocol RoutePersisting {
    func loadRoutes() throws -> [RouteRule]
    func saveRoutes(_ routes: [RouteRule]) throws
    func loadOutputGroups() throws -> [OutputGroup]
    func saveOutputGroups(_ groups: [OutputGroup]) throws
}

public final class RoutePersistence: RoutePersisting {
    private let fileURL: URL
    private let groupsFileURL: URL
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    public init(fileManager: FileManager = .default) {
        let supportDirectory = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? fileManager.temporaryDirectory
        let appDirectory = supportDirectory.appendingPathComponent("AudioRouter", isDirectory: true)
        self.fileURL = appDirectory.appendingPathComponent("routes.json")
        self.groupsFileURL = appDirectory.appendingPathComponent("output-groups.json")
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    }

    public init(fileURL: URL) {
        self.fileURL = fileURL
        self.groupsFileURL = fileURL
            .deletingLastPathComponent()
            .appendingPathComponent("output-groups.json")
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    }

    public func loadRoutes() throws -> [RouteRule] {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return [] }
        let data = try Data(contentsOf: fileURL)
        return try decoder.decode([RouteRule].self, from: data)
    }

    public func saveRoutes(_ routes: [RouteRule]) throws {
        try FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let data = try encoder.encode(routes)
        try data.write(to: fileURL, options: .atomic)
    }

    public func loadOutputGroups() throws -> [OutputGroup] {
        guard FileManager.default.fileExists(atPath: groupsFileURL.path) else { return [] }
        let data = try Data(contentsOf: groupsFileURL)
        return try decoder.decode([OutputGroup].self, from: data)
    }

    public func saveOutputGroups(_ groups: [OutputGroup]) throws {
        try FileManager.default.createDirectory(
            at: groupsFileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let data = try encoder.encode(groups)
        try data.write(to: groupsFileURL, options: .atomic)
    }
}
