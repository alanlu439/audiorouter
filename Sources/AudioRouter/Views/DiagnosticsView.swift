import SwiftUI

struct DiagnosticsView: View {
    @ObservedObject var store: AudioRouterStore

    var body: some View {
        List(store.diagnostics) { event in
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: event.level.systemImage)
                    .foregroundStyle(color(for: event.level))
                    .frame(width: 20)

                VStack(alignment: .leading, spacing: 4) {
                    Text(event.message)
                        .lineLimit(3)

                    Text("\(Formatters.eventTime.string(from: event.timestamp)) · \(event.level.rawValue)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.vertical, 4)
        }
        .navigationTitle("Diagnostics")
        .overlay {
            if store.diagnostics.isEmpty {
                ContentUnavailableView("No diagnostics", systemImage: "waveform.path.ecg")
            }
        }
    }

    private func color(for level: DiagnosticsLevel) -> Color {
        switch level {
        case .info:
            return .secondary
        case .warning:
            return .orange
        case .error:
            return .red
        }
    }
}
