import SwiftUI

struct DashboardHeader: View {
    let title: String
    let subtitle: String
    let primaryMetric: String
    let primaryLabel: String
    let secondaryMetric: String
    let secondaryLabel: String
    let tertiaryMetric: String
    let tertiaryLabel: String

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 14) {
                AudioRouterLogo()

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: 26, weight: .semibold))
                        .lineLimit(1)

                    Text(subtitle)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                Spacer()
            }

            ViewThatFits(in: .horizontal) {
                HStack(spacing: 10) {
                    MetricTile(value: primaryMetric, label: primaryLabel, systemImage: "point.3.connected.trianglepath.dotted")
                    MetricTile(value: secondaryMetric, label: secondaryLabel, systemImage: "speaker.wave.2")
                    MetricTile(value: tertiaryMetric, label: tertiaryLabel, systemImage: "app.connected.to.app.below.fill")
                }

                VStack(spacing: 10) {
                    MetricTile(value: primaryMetric, label: primaryLabel, systemImage: "point.3.connected.trianglepath.dotted")
                    MetricTile(value: secondaryMetric, label: secondaryLabel, systemImage: "speaker.wave.2")
                    MetricTile(value: tertiaryMetric, label: tertiaryLabel, systemImage: "app.connected.to.app.below.fill")
                }
            }
        }
    }
}

struct MetricTile: View {
    let value: String
    let label: String
    let systemImage: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: systemImage)
                .font(.title3)
                .foregroundStyle(.secondary)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 1) {
                Text(value)
                    .font(.title3.weight(.semibold))
                    .monospacedDigit()
                Text(label)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)
        }
        .padding(12)
        .frame(minWidth: 0, maxWidth: .infinity, minHeight: 64)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

struct DetailSectionHeader: View {
    let title: String
    let detail: String
    let systemImage: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: systemImage)
                .foregroundStyle(.secondary)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()
        }
    }
}
