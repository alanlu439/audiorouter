import AppKit
import Foundation

public enum PermissionsManager {
    public static func openSystemAudioRecordingSettings() {
        let candidateURLs = [
            "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture",
            "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension",
            "x-apple.systempreferences:com.apple.preference.security"
        ]

        for value in candidateURLs {
            guard let url = URL(string: value) else { continue }
            if NSWorkspace.shared.open(url) {
                return
            }
        }
    }
}
