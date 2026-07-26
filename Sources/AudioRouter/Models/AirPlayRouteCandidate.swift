import Foundation

public struct AirPlayRouteCandidate: Identifiable, Codable, Hashable {
    public static let routeTargetPrefix = "airplay-route:"

    public let id: String
    public let name: String
    public let serviceType: String
    public let domain: String
    public let hostName: String?
    public let port: Int?
    public let discoveredAt: Date

    public init(
        id: String,
        name: String,
        serviceType: String,
        domain: String,
        hostName: String? = nil,
        port: Int? = nil,
        discoveredAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.serviceType = serviceType
        self.domain = domain
        self.hostName = hostName
        self.port = port
        self.discoveredAt = discoveredAt
    }

    public var routeTargetID: String {
        Self.routeTargetPrefix + id
    }

    public var kindDescription: String {
        if serviceType.localizedCaseInsensitiveContains("_raop") {
            return "AirPlay audio"
        }
        return "AirPlay route"
    }

    public static func isRouteTargetID(_ id: String) -> Bool {
        id.hasPrefix(routeTargetPrefix)
    }

    public static func displayName(from serviceName: String) -> String {
        let trimmed = serviceName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let separator = trimmed.firstIndex(of: "@") else {
            return trimmed
        }
        let suffix = trimmed[trimmed.index(after: separator)...]
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return suffix.isEmpty ? trimmed : suffix
    }

    public static func stableID(name: String, serviceType: String, domain: String) -> String {
        normalizedKey(for: name)
    }

    public static func normalizedTargetKey(forRouteTargetID routeTargetID: String) -> String? {
        guard isRouteTargetID(routeTargetID) else { return nil }
        let rawID = String(routeTargetID.dropFirst(routeTargetPrefix.count))
        guard let nameComponent = rawID.split(separator: "|", maxSplits: 1, omittingEmptySubsequences: false).first,
              !nameComponent.isEmpty else {
            return nil
        }
        return normalizedKey(for: String(nameComponent))
    }

    public static func normalizedKey(for name: String) -> String {
        name
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .lowercased()
    }
}
