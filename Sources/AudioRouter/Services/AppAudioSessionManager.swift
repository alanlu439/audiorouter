import AppKit
import Foundation

public final class AppAudioSessionManager {
    private let client: CoreAudioClient
    private var recentSessions: [String: AudioAppSession] = [:]
    private let recentWindow: TimeInterval = 120

    public convenience init() {
        self.init(client: CoreAudioClient())
    }

    init(client: CoreAudioClient) {
        self.client = client
    }

    public func refreshSessions(existing: [AudioAppSession]) -> [AudioAppSession] {
        let persistedByID = Dictionary(uniqueKeysWithValues: existing.map { ($0.id, $0) })
        let now = Date()
        let current = (try? client.audioAppSessions()) ?? fallbackSessions()

        for var session in current {
            if let persisted = persistedByID[session.id] {
                session.volume = persisted.volume
                session.isMuted = persisted.isMuted
                session.assignedOutputUID = persisted.assignedOutputUID
            }
            session.lastActivity = now
            recentSessions[session.id] = session
        }

        let cutoff = now.addingTimeInterval(-recentWindow)
        recentSessions = recentSessions.filter { $0.value.lastActivity >= cutoff }

        return recentSessions.values
            .sorted {
                if $0.isProducingAudio != $1.isProducingAudio {
                    return $0.isProducingAudio
                }
                return $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending
            }
    }

    public func setVolume(_ volume: Double, for session: AudioAppSession) -> AudioAppSession {
        // TODO: Public macOS APIs do not expose direct per-app output volume for arbitrary apps.
        // A production implementation needs a virtual audio driver or system audio plug-in that owns the render stream.
        var updated = session
        updated.volume = max(0, min(1.5, volume))
        recentSessions[session.id] = updated
        return updated
    }

    public func setMuted(_ isMuted: Bool, for session: AudioAppSession) -> AudioAppSession {
        // TODO: Same platform limitation as per-app volume. This is a persisted UI-level setting for the MVP.
        var updated = session
        updated.isMuted = isMuted
        recentSessions[session.id] = updated
        return updated
    }

    public func assignOutput(_ uid: String?, for session: AudioAppSession) -> AudioAppSession {
        // TODO: Public APIs can switch global default devices, but not redirect arbitrary app output independently.
        var updated = session
        updated.assignedOutputUID = uid
        recentSessions[session.id] = updated
        return updated
    }

    private func fallbackSessions() -> [AudioAppSession] {
        NSWorkspace.shared.runningApplications
            .filter { $0.activationPolicy == .regular }
            .prefix(5)
            .map { app in
                AudioAppSession(
                    id: app.bundleIdentifier ?? "pid-\(app.processIdentifier)",
                    pid: app.processIdentifier,
                    bundleID: app.bundleIdentifier,
                    displayName: app.localizedName ?? "App \(app.processIdentifier)",
                    iconPath: app.bundleURL?.path,
                    isProducingAudio: false
                )
            }
    }
}
