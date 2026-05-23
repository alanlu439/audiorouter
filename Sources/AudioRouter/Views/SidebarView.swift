import SwiftUI

struct SidebarView: View {
    @ObservedObject var store: AudioRouterStore

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                AudioRouterLogo(size: .compact)

                VStack(alignment: .leading, spacing: 1) {
                    Text("AudioRouter")
                        .font(.headline)
                        .lineLimit(1)
                    Text("\(store.routes.filter(\.isEnabled).count) active routes")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 12)

            List(selection: $store.selectedSection) {
                Section {
                    ForEach(AppSection.allCases) { section in
                        HStack(spacing: 10) {
                            Image(systemName: section.systemImage)
                                .foregroundStyle(.secondary)
                                .frame(width: 16)

                            Text(section.rawValue)
                                .lineLimit(1)

                            Spacer()

                            if badgeCount(for: section) > 0 {
                                Text("\(badgeCount(for: section))")
                                    .font(.caption2.weight(.semibold))
                                    .foregroundStyle(.secondary)
                                    .monospacedDigit()
                            }
                        }
                        .tag(section)
                    }
                }
            }
            .listStyle(.sidebar)
        }
        .navigationTitle("AudioRouter")
    }

    private func badgeCount(for section: AppSection) -> Int {
        switch section {
        case .devices:
            return store.devices.count
        case .processes:
            return store.applications.count
        case .routes:
            return store.routes.count
        case .permissions, .diagnostics:
            return 0
        }
    }
}
