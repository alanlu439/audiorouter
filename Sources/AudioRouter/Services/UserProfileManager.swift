import Foundation

public final class UserProfileManager: ObservableObject {
    private struct ProfileStore: Codable {
        var profiles: [UserProfile]
        var activeProfileID: UUID
    }

    @Published public private(set) var profiles: [UserProfile] = []
    @Published public private(set) var activeProfileID: UUID

    private let fileURL: URL

    public convenience init() {
        let profileURL = try! AppSupport.fileURL(named: "user-profiles.json")
        self.init(fileURL: profileURL)
    }

    public init(
        fileURL: URL,
        activeProfileID: UUID = UserProfile.defaultProfileID
    ) {
        self.fileURL = fileURL
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
        profiles = [profile] + profiles
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
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        updateProfile(profile.id) { profile in
            profile.displayName = trimmed
            profile.updatedAt = Date()
        }
        save()
    }

    public func delete(_ profile: UserProfile) {
        guard profiles.count > 1 else { return }
        profiles = profiles.filter { $0.id != profile.id }
        if activeProfileID == profile.id {
            activeProfileID = profiles.first?.id ?? UserProfile.defaultProfileID
        }
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

    private func updateProfile(_ profileID: UUID, mutate: (inout UserProfile) -> Void) {
        guard let index = profiles.firstIndex(where: { $0.id == profileID }) else { return }
        var updatedProfiles = profiles
        mutate(&updatedProfiles[index])
        profiles = updatedProfiles
    }
}
