import Foundation

public struct UserProfile: Identifiable, Codable, Hashable {
    public static let defaultProfileID = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!

    public var id: UUID
    public var displayName: String
    public var photoPath: String?
    public var createdAt: Date
    public var updatedAt: Date

    public init(
        id: UUID = UUID(),
        displayName: String,
        photoPath: String? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        let trimmedName = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        self.id = id
        self.displayName = trimmedName.isEmpty ? "Profile" : trimmedName
        self.photoPath = photoPath
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    public static var defaultProfile: UserProfile {
        UserProfile(
            id: defaultProfileID,
            displayName: "Default Profile",
            createdAt: Date(timeIntervalSince1970: 0),
            updatedAt: Date(timeIntervalSince1970: 0)
        )
    }

    public var initials: String {
        let words = displayName
            .split { $0.isWhitespace || $0 == "-" || $0 == "_" }
            .map(String.init)
        let letters = words.prefix(2).compactMap { $0.first }.map(String.init)
        let fallback = displayName.first.map(String.init) ?? "A"
        return (letters.isEmpty ? fallback : letters.joined()).uppercased()
    }
}
