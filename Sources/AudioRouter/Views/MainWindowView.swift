import AppKit
import SwiftUI
import UniformTypeIdentifiers

public struct MainWindowView: View {
    @ObservedObject private var store: AudioRouterStore
    @State private var offeredInitialOnboarding = false
    @State private var profileSheetMode: ProfileNameSheet.Mode?

    public init(store: AudioRouterStore) {
        self.store = store
    }

    public var body: some View {
        NavigationSplitView {
            List(selection: $store.selectedSettingsSection) {
                ForEach(SettingsSection.allCases) { section in
                    Label(section.rawValue, systemImage: section.systemImage)
                        .tag(section)
                }
            }
            .listStyle(.sidebar)
            .navigationTitle("AudioRouter")
        } detail: {
            SettingsDetailView(section: store.selectedSettingsSection, store: store)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .overlay(alignment: .bottomLeading) {
            AudioRouterWatermarkBanner()
                .padding(.leading, 24)
                .padding(.bottom, 22)
                .allowsHitTesting(false)
                .zIndex(20)
        }
        .preferredColorScheme(store.settings.effectiveColorScheme)
        .sheet(isPresented: $store.isOnboardingPresented) {
            GuidedOnboardingSheet(store: store)
                .frame(minWidth: 760, idealWidth: 860, minHeight: 540, idealHeight: 620)
                .preferredColorScheme(store.settings.effectiveColorScheme)
        }
        .sheet(item: $profileSheetMode) { mode in
            ProfileNameSheet(mode: mode, store: store)
                .frame(width: 360)
                .preferredColorScheme(store.settings.effectiveColorScheme)
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                UserProfileMenu(store: store, style: .toolbar) { mode in
                    profileSheetMode = mode
                }
            }
        }
        .onAppear {
            presentInitialOnboardingIfNeeded()
        }
        .alert("AudioRouter Update Available", isPresented: updatePromptBinding) {
            if store.updateManager.availableUpdate?.isDownloadable == true {
                Button("Install ZIP") {
                    store.installDownloadedUpdate()
                }
            } else {
                Button("View Commit") {
                    store.openLatestRelease()
                    store.dismissUpdatePrompt()
                }
            }
            Button("Later", role: .cancel) {
                store.dismissUpdatePrompt()
            }
        } message: {
            Text(updatePromptMessage)
        }
    }

    private func presentInitialOnboardingIfNeeded() {
        guard !offeredInitialOnboarding, !store.settings.hasCompletedOnboarding else { return }
        offeredInitialOnboarding = true
        store.showOnboarding()
    }

    private var updatePromptBinding: Binding<Bool> {
        Binding(
            get: { store.updateManager.shouldPromptToInstall },
            set: { isPresented in
                if !isPresented {
                    store.dismissUpdatePrompt()
                }
            }
        )
    }

    private var updatePromptMessage: String {
        if let update = store.updateManager.availableUpdate {
            if update.isDownloadable {
                return "AudioRouter \(update.version) has been downloaded. Open the ZIP and move AudioRouter.app to Applications to finish installing."
            }
            let commitLabel = update.commitSHA.map(UpdateManager.shortCommit) ?? update.version
            return "A newer AudioRouter commit \(commitLabel) is available on GitHub. Open the commit to review the update; packaged app ZIPs are still published from GitHub Releases."
        }
        return store.updateManager.message
    }
}

private struct UserProfileMenu: View {
    enum Style {
        case full
        case toolbar
    }

    @ObservedObject var store: AudioRouterStore
    let style: Style
    let openSheet: (ProfileNameSheet.Mode) -> Void

    init(
        store: AudioRouterStore,
        style: Style = .full,
        openSheet: @escaping (ProfileNameSheet.Mode) -> Void
    ) {
        self.store = store
        self.style = style
        self.openSheet = openSheet
    }

    var body: some View {
        Menu {
            Section("Profiles") {
                ForEach(store.userProfileManager.profiles) { profile in
                    Button {
                        store.selectUserProfile(profile)
                    } label: {
                        Label(profile.displayName, systemImage: profile.id == store.activeUserProfile.id ? "checkmark.circle.fill" : "person.circle")
                    }
                }
            }

            Divider()

            Button {
                openSheet(.add)
            } label: {
                Label("Add Profile", systemImage: "person.badge.plus")
            }

            Button {
                openSheet(.rename(store.activeUserProfile))
            } label: {
                Label("Rename Profile", systemImage: "pencil")
            }

            Button {
                choosePhoto()
            } label: {
                Label("Upload Photo", systemImage: "photo.badge.plus")
            }

            if store.activeUserProfile.photoPath != nil {
                Button {
                    store.removePhoto(for: store.activeUserProfile)
                } label: {
                    Label("Remove Photo", systemImage: "photo.badge.minus")
                }
            }

            if store.userProfileManager.profiles.count > 1 {
                Divider()
                Button(role: .destructive) {
                    store.deleteUserProfile(store.activeUserProfile)
                } label: {
                    Label("Delete Current Profile", systemImage: "trash")
                }
            }
        } label: {
            profileLabel
        }
        .menuStyle(.button)
        .help("AudioRouter profile: \(store.activeUserProfile.displayName)")
        .accessibilityLabel("AudioRouter profile \(store.activeUserProfile.displayName)")
    }

    @ViewBuilder
    private var profileLabel: some View {
        switch style {
        case .full:
            HStack(spacing: 7) {
                ProfileAvatar(profile: store.activeUserProfile, size: 28)
                Text(store.activeUserProfile.displayName)
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)
            }
            .padding(.leading, 5)
            .padding(.trailing, 10)
            .padding(.vertical, 5)
            .background(.ultraThinMaterial, in: Capsule())
            .overlay {
                Capsule()
                    .stroke(.white.opacity(0.16), lineWidth: 1)
            }
            .shadow(color: .black.opacity(0.18), radius: 10, y: 4)
        case .toolbar:
            HStack(spacing: 6) {
                ProfileAvatar(profile: store.activeUserProfile, size: 20)
                    .frame(width: 20, height: 20)
                Text(store.activeUserProfile.displayName)
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)
                    .frame(maxWidth: 120, alignment: .leading)
            }
            .frame(height: 24)
            .fixedSize(horizontal: true, vertical: true)
            .padding(.leading, 4)
            .padding(.trailing, 8)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 7, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .stroke(.white.opacity(0.16), lineWidth: 1)
            }
            .contentShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
        }
    }

    private func choosePhoto() {
        let panel = NSOpenPanel()
        panel.title = "Choose Profile Photo"
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [.image]
        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            Task { @MainActor in
                store.setPhoto(for: store.activeUserProfile, sourceURL: url)
            }
        }
    }
}

private struct ProfileNameSheet: View {
    enum Mode: Identifiable {
        case add
        case rename(UserProfile)

        var id: String {
            switch self {
            case .add: return "add"
            case let .rename(profile): return "rename-\(profile.id.uuidString)"
            }
        }
    }

    let mode: Mode
    @ObservedObject var store: AudioRouterStore
    @Environment(\.dismiss) private var dismiss
    @State private var name: String

    init(mode: Mode, store: AudioRouterStore) {
        self.mode = mode
        self.store = store
        switch mode {
        case .add:
            _name = State(initialValue: "")
        case let .rename(profile):
            _name = State(initialValue: profile.displayName)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                Image(systemName: modeIcon)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(.teal)
                    .frame(width: 34, height: 34)
                    .background(.teal.opacity(0.12), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
                VStack(alignment: .leading, spacing: 2) {
                    Text(modeTitle)
                        .font(.headline)
                    Text("Profiles keep setup presets separated by user.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            TextField("Profile name", text: $name)
                .textFieldStyle(.roundedBorder)
                .onSubmit(save)

            HStack {
                Spacer()
                Button("Cancel") {
                    dismiss()
                }
                Button(modeButtonTitle) {
                    save()
                }
                .buttonStyle(.borderedProminent)
                .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(18)
    }

    private var modeTitle: String {
        switch mode {
        case .add: return "Add Profile"
        case .rename: return "Rename Profile"
        }
    }

    private var modeButtonTitle: String {
        switch mode {
        case .add: return "Create"
        case .rename: return "Save"
        }
    }

    private var modeIcon: String {
        switch mode {
        case .add: return "person.badge.plus"
        case .rename: return "pencil"
        }
    }

    private func save() {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        switch mode {
        case .add:
            store.addUserProfile(named: trimmed)
        case let .rename(profile):
            store.renameUserProfile(profile, to: trimmed)
        }
        dismiss()
    }
}

#if DEBUG
struct MainWindowView_Previews: PreviewProvider {
    @MainActor
    static var previews: some View {
        MainWindowView(store: PreviewSupport.demoStore())
            .frame(width: 1100, height: 760)
    }
}
#endif
