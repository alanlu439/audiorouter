import AppKit
import SwiftUI

public struct MenuBarContentView: View {
    @ObservedObject var store: AudioRouterStore
    @Environment(\.openWindow) private var openWindow

    public init(store: AudioRouterStore) {
        self.store = store
    }

    public var body: some View {
        Button {
            openWindow(id: "main")
            NSApp.activate(ignoringOtherApps: true)
        } label: {
            Label("Open AudioRouter", systemImage: "macwindow")
        }

        HStack(spacing: 8) {
            AudioRouterLogo(size: .compact)
            VStack(alignment: .leading, spacing: 1) {
                Text("AudioRouter")
                Text("\(store.routes.filter(\.isEnabled).count) active")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }

        Divider()

        Button {
            store.refresh()
        } label: {
            Label("Refresh", systemImage: "arrow.clockwise")
        }

        if let defaultOutput = store.devices.first(where: \.isDefaultOutput) {
            Divider()
            Text("System Output")
                .font(.caption)
                .foregroundStyle(.secondary)

            MenuBarDeviceControl(store: store, device: defaultOutput)
        }

        if store.routes.isEmpty {
            Divider()
            Label("No routes", systemImage: "point.3.connected.trianglepath.dotted")
        } else {
            Divider()
            Text("Applications")
                .font(.caption)
                .foregroundStyle(.secondary)

            ForEach(store.routes) { route in
                MenuBarRouteControl(store: store, route: route)
            }
        }

        Divider()

        Button(role: .destructive) {
            store.stopAllRoutes()
        } label: {
            Label("Stop All", systemImage: "stop.circle")
        }
    }

}

private struct MenuBarRouteControl: View {
    @ObservedObject var store: AudioRouterStore
    let route: RouteRule

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Toggle(isOn: enabledBinding) {
                Text("\(route.processDisplayName) → \(store.deviceName(for: route.deviceUID))")
                    .lineLimit(1)
            }

            HStack(spacing: 8) {
                Image(systemName: "speaker.wave.2.fill")
                    .foregroundStyle(.secondary)
                Slider(value: volumeBinding, in: 0...1.5)
                    .frame(width: 150)
                Text("\(Int(currentRoute.volume * 100))%")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .frame(width: 42, alignment: .trailing)
            }
        }
        .padding(.vertical, 3)
    }

    private var currentRoute: RouteRule {
        store.routes.first { $0.id == route.id } ?? route
    }

    private var enabledBinding: Binding<Bool> {
        Binding(
            get: {
                store.routes.first(where: { $0.id == route.id })?.isEnabled ?? false
            },
            set: { newValue in
                store.setRouteEnabled(route, isEnabled: newValue)
            }
        )
    }

    private var volumeBinding: Binding<Double> {
        Binding(
            get: {
                currentRoute.volume
            },
            set: { newValue in
                store.setRouteVolume(currentRoute, volume: newValue)
            }
        )
    }
}

private struct MenuBarDeviceControl: View {
    @ObservedObject var store: AudioRouterStore
    let device: AudioDeviceInfo

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Text(currentDevice.name)
                    .lineLimit(1)
                Spacer()
                if currentDevice.canSetMute {
                    Toggle("Mute", isOn: muteBinding)
                        .labelsHidden()
                }
            }

            if currentDevice.outputVolume != nil {
                HStack(spacing: 8) {
                    Image(systemName: currentDevice.isMuted == true ? "speaker.slash.fill" : "speaker.wave.2.fill")
                        .foregroundStyle(.secondary)
                    Slider(value: volumeBinding, in: 0...1)
                        .frame(width: 150)
                        .disabled(!currentDevice.canSetVolume)
                    Text("\(Int((currentDevice.outputVolume ?? 0) * 100))%")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                        .frame(width: 42, alignment: .trailing)
                }
            }
        }
        .padding(.vertical, 3)
    }

    private var currentDevice: AudioDeviceInfo {
        store.devices.first { $0.uid == device.uid } ?? device
    }

    private var volumeBinding: Binding<Double> {
        Binding(
            get: {
                currentDevice.outputVolume ?? 0
            },
            set: { newValue in
                store.setDeviceVolume(currentDevice, volume: newValue)
            }
        )
    }

    private var muteBinding: Binding<Bool> {
        Binding(
            get: {
                currentDevice.isMuted ?? false
            },
            set: { newValue in
                store.setDeviceMuted(currentDevice, isMuted: newValue)
            }
        )
    }
}
