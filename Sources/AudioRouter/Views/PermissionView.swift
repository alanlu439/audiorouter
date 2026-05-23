import AppKit
import SwiftUI

struct PermissionView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                DashboardHeader(
                    title: "Capture Permission",
                    subtitle: "AudioRouter uses Apple’s system audio capture permission before it can read selected app output.",
                    primaryMetric: "14.2+",
                    primaryLabel: "macOS",
                    secondaryMetric: "TCC",
                    secondaryLabel: "Permission",
                    tertiaryMetric: "CoreAudio",
                    tertiaryLabel: "Public API"
                )

                VStack(alignment: .leading, spacing: 12) {
                    DetailSectionHeader(
                        title: "Privacy & Security",
                        detail: "macOS controls whether AudioRouter can capture app audio.",
                        systemImage: "lock.shield"
                    )

                    VStack(alignment: .leading, spacing: 10) {
                        Label("The prompt appears when a route starts for the first time.", systemImage: "1.circle")
                        Label("Denied access can be changed in Privacy & Security.", systemImage: "2.circle")
                        Label("Some protected streams may remain unavailable.", systemImage: "3.circle")
                    }
                    .foregroundStyle(.secondary)

                    Button {
                        openPrivacySettings()
                    } label: {
                        Label("Open Privacy Settings", systemImage: "gear")
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding(16)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
            }
            .padding(24)
        }
        .navigationTitle("Permission")
    }

    private func openPrivacySettings() {
        let candidates = [
            "x-apple.systempreferences:com.apple.preference.security?Privacy_AudioCapture",
            "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture"
        ]

        for candidate in candidates {
            guard let url = URL(string: candidate), NSWorkspace.shared.open(url) else { continue }
            break
        }
    }
}
