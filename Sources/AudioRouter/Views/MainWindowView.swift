import SwiftUI

public struct MainWindowView: View {
    @ObservedObject private var store: AudioRouterStore
    @State private var offeredInitialOnboarding = false
    @State private var profileSheetMode: ProfileNameSheet.Mode?

    public init(store: AudioRouterStore) {
        self.store = store
    }

    public var body: some View {
        NavigationSplitView {
            AudioRouterSidebar(selection: $store.selectedSettingsSection, showsWatermark: true)
        } detail: {
            SettingsDetailView(section: store.selectedSettingsSection, store: store)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .navigationTitle("AudioRouter")
        .navigationSplitViewStyle(.balanced)
        .toolbarBackground(ConsolePalette.windowChrome, for: .windowToolbar)
        .toolbarBackground(.visible, for: .windowToolbar)
        .buttonStyle(.audioRouter)
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
                .padding(.trailing, 16)
            }
        }
        .background(AudioRouterToolbarStyler())
        .onAppear {
            AudioRouterToolbarStyler.scheduleStyling()
            presentInitialOnboardingIfNeeded()
        }
        .alert("AudioRouter Update Available", isPresented: updatePromptBinding) {
            Button("Install ZIP") {
                store.installDownloadedUpdate()
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
            return "AudioRouter \(update.version) has been downloaded. Open the ZIP and move AudioRouter.app to Applications to finish installing."
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
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize(horizontal: true, vertical: true)
        .help("AudioRouter profile: \(store.activeUserProfile.displayName)")
        .accessibilityLabel("AudioRouter profile \(store.activeUserProfile.displayName)")
    }

    @ViewBuilder
    private var profileLabel: some View {
        switch style {
        case .full:
            profileNameRow(height: 32, horizontalPadding: 12)
                .background(ConsolePalette.strip, in: Capsule())
                .overlay {
                    Capsule()
                        .stroke(ConsolePalette.strongStroke, lineWidth: 1)
                }
                .shadow(color: .black.opacity(0.16), radius: 8, y: 3)
        case .toolbar:
            profileNameRow(height: 28, horizontalPadding: 10)
                .background(ConsolePalette.strip, in: RoundedRectangle(cornerRadius: 7, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .stroke(ConsolePalette.strongStroke, lineWidth: 1)
                }
                .contentShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
        }
    }

    private func profileNameRow(height: CGFloat, horizontalPadding: CGFloat) -> some View {
        HStack(alignment: .center, spacing: 7) {
            Text(store.activeUserProfile.displayName)
                .font(.system(size: style == .toolbar ? 13 : 14, weight: .semibold))
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
            Image(systemName: "chevron.down")
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(.secondary)
                .frame(width: 10, height: 18, alignment: .center)
                .accessibilityHidden(true)
        }
        .frame(height: height, alignment: .center)
        .padding(.horizontal, horizontalPadding)
        .fixedSize(horizontal: true, vertical: true)
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
                .buttonStyle(.audioRouterPrimary)
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
