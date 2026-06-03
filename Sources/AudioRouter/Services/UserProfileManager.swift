import Foundation

public final class UserProfileManager: ObservableObject {
    private struct ProfileStore: Codable {
        var profiles: [UserProfile]
        var activeProfileID: UUID
    }

    @Published public private(set) var profiles: [UserProfile] = []
    @Published public private(set) var activeProfileID: UUID

    private let fileURL: URL
    private let photosDirectoryURL: URL

    public convenience init() {
        let profileURL = try! AppSupport.fileURL(named: "user-profiles.json")
        self.init(
            fileURL: profileURL,
            photosDirectoryURL: profileURL.deletingLastPathComponent().appendingPathComponent("Profile Photos", isDirectory: true)
        )
    }

    public init(
        fileURL: URL,
        photosDirectoryURL: URL,
        activeProfileID: UUID = UserProfile.defaultProfileID
    ) {
        self.fileURL = fileURL
        self.photosDirectoryURL = photosDirectoryURL
        self.activeProfileID = activeProfileID
        load()
    }

    public var activeProfile: UserProfile {
        profiles.first { $0.id == activeProfileID } ?? profiles.first ?? .defaultProfile
    }

    @discardableResult
    public func addProfile(named name: String) -> UserProfile {
        let baseName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let profile = UserProfile(displayName: baseName.isEmpty ? "New Profile" : baseName)
        profiles.insert(profile, at: 0)
        activeProfileID = profile.id
        save()
        return profile
    }

    public func selectProfile(_ profile: UserProfile) {
        guard profiles.contains(where: { $0.id == profile.id }) else { return }
        activeProfileID = profile.id
        save()
    }

    public func rename(_ profile: UserProfile, to name: String) {
        guard let index = profiles.firstIndex(where: { $0.id == profile.id }) else { return }
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        profiles[index].displayName = trimmed
        profiles[index].updatedAt = Date()
        save()
    }

    public func delete(_ profile: UserProfile) {
        guard profiles.count > 1 else { return }
        profiles.removeAll { $0.id == profile.id }
        if activeProfileID == profile.id {
            activeProfileID = profiles.first?.id ?? UserProfile.defaultProfileID
        }
        save()
    }

    public func setPhoto(for profile: UserProfile, sourceURL: URL) throws {
        guard let index = profiles.firstIndex(where: { $0.id == profile.id }) else { return }
        try FileManager.default.createDirectory(
            at: photosDirectoryURL,
            withIntermediateDirectories: true
        )

        let ext = sourceURL.pathExtension.isEmpty ? "png" : sourceURL.pathExtension
        let destinationURL = photosDirectoryURL.appendingPathComponent("\(profile.id.uuidString).\(ext)")
        if FileManager.default.fileExists(atPath: destinationURL.path) {
            try FileManager.default.removeItem(at: destinationURL)
        }
        try FileManager.default.copyItem(at: sourceURL, to: destinationURL)

        profiles[index].photoPath = destinationURL.path
        profiles[index].updatedAt = Date()
        save()
    }

    public func removePhoto(for profile: UserProfile) {
        guard let index = profiles.firstIndex(where: { $0.id == profile.id }) else { return }
        profiles[index].photoPath = nil
        profiles[index].updatedAt = Date()
        save()
    }

    private func load() {
        if let data = try? Data(contentsOf: fileURL),
           let decoded = try? JSONDecoder().decode(ProfileStore.self, from: data),
           !decoded.profiles.isEmpty {
            profiles = decoded.profiles.sorted { $0.createdAt < $1.createdAt }
            activeProfileID = decoded.activeProfileID
        } else if let data = try? Data(contentsOf: fileURL),
                  let decoded = try? JSONDecoder().decode([UserProfile].self, from: data),
                  !decoded.isEmpty {
            profiles = decoded.sorted { $0.createdAt < $1.createdAt }
        } else {
            profiles = [.defaultProfile]
        }

        if !profiles.contains(where: { $0.id == UserProfile.defaultProfileID }) {
            profiles.append(.defaultProfile)
        }
        if !profiles.contains(where: { $0.id == activeProfileID }) {
            activeProfileID = profiles.first?.id ?? UserProfile.defaultProfileID
        }
    }

    private func save() {
        do {
            let data = try JSONEncoder().encode(ProfileStore(
                profiles: profiles,
                activeProfileID: activeProfileID
            ))
            try data.write(to: fileURL, options: .atomic)
        } catch {
            assertionFailure("Could not save AudioRouter profiles: \(error)")
        }
    }
}
