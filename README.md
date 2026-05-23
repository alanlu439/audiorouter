# AudioRouter

AudioRouter is an original SwiftUI macOS utility for controlling audio devices, system volume, app routing preferences, EQ presets, shortcuts, and quick audio setups. It is designed as a visual audio control center with a compact menu bar popover, a full Routing Dashboard, and a dark-mode-first macOS interface.

The app uses public macOS APIs only. Device discovery, default input/output switching, and supported device volume/mute/balance controls are backed by CoreAudio. Features macOS does not expose publicly, such as true arbitrary per-app output volume, independent per-app device routing, and system-wide EQ, are implemented as polished UI and persisted state with clear TODO notes for a future driver-backed audio engine.

## Features implemented

- Menu bar app with a rich SwiftUI popover.
- Opens as a normal macOS app with a Dock icon and main window, while also keeping a menu bar popover.
- Compact icon-only menu bar extra to reduce width and stay visible longer when the menu bar is crowded.
- Settings window with visual sections for routing, mixing, devices, EQ, setups, shortcuts, and advanced controls.
- Full visual main window with Dashboard, Mixer, Devices, EQ, Setups, Shortcuts, and Advanced screens.
- Routing Dashboard patch bay with source cards, output cards, visible route lines, drag-and-drop assignment, route controls, and follow-system reset.
- Live Mode for real CoreAudio-backed controls and Demo Mode for fully explorable mock sources, devices, routes, meters, and EQ behavior.
- Output and input device discovery through CoreAudio.
- Current output and input device display.
- Switch default output/input device.
- Output volume, input volume, mute, and balance controls where the device exposes them.
- Device list refresh with a lightweight polling loop for Bluetooth, AirPlay, USB, and built-in device changes.
- Central App Routing patch bay: Source App -> Output Device.
- `AudioSource`, `AudioRoute`, `AudioRoutingManager`, and `AudioRoutingBackend` abstractions for future real routing.
- Public API backend that detects audio-producing apps, lists output devices, saves routes, and clearly marks driver-required routing.
- Future virtual-driver backend stub for true per-app routing.
- Stateful per-app volume, mute, "Follow System Output", and specific output-device preference UI.
- Visual system, input, per-app, and per-device level meters. Live metering is simulated until a driver-backed engine owns the stream.
- 10-band EQ UI with visual sliders, curve preview, Before toggle, Reset, Custom, Flat, Bass Boost, Vocal, Podcast, Movie, and Music presets.
- Visual setup cards with save, apply, duplicate, rename, delete, JSON export, and JSON import.
- Visual shortcut editor for mute, app mute, volume up/down, next/previous output, opening the app path, and applying the first three saved setups.
- Debug audio device list and unsupported-feature notes.

## Stubbed or limited features

- True per-app volume, mute, and output routing for arbitrary apps require owning the audio stream through a virtual audio driver, AudioServerPlugIn, or similar system audio component.
- Public APIs can switch global default devices and inspect active audio processes, but they cannot reliably redirect Spotify, Safari, Zoom, or other arbitrary app audio to independent outputs on demand.
- System-wide real-time EQ requires a driver or audio plug-in. AudioRouter stores and displays EQ settings today.
- Global shortcut support and programmatic opening of the SwiftUI `MenuBarExtra` popover are marked TODO. The MVP includes local app commands first.
- Launch at login uses `SMAppService.mainApp` and may require a signed app bundle to work outside local development.
- macOS controls menu bar item ordering and overflow. AudioRouter uses the smallest practical icon-only item, but public APIs cannot force a third-party menu bar item to remain pinned above all other items.

## Run

```bash
./script/build_and_run.sh
```

The script builds the SwiftPM product, stages `dist/AudioRouter.app`, writes the app bundle `Info.plist`, copies `Resources/AppIcon.icns`, and launches the bundle.

## Verify

```bash
swift build
swift run AudioRouterChecks
./script/build_and_run.sh --verify
plutil -lint dist/AudioRouter.app/Contents/Info.plist
```

Regenerate the app logo/icon resources with:

```bash
swift script/generate_app_icon.swift Resources/AppIcon.iconset
```

This Command Line Tools install does not include `XCTest` or Swift's `Testing` module, so the package includes `AudioRouterChecks` as a small executable check suite for persistence, presets, shortcuts, and model behavior.

## macOS API notes

- Devices must already be connected in macOS; AudioRouter does not pair Bluetooth devices.
- Some devices do not expose settable input volume, mute, or balance controls.
- Public APIs are enough for a strong device-control and route-preference MVP, but not enough for a full SoundSource-style driverless clone.

## Future work

- Driver-backed per-app routing and per-app gain.
- Real-time EQ processing.
- Signed app bundle with robust launch-at-login behavior.
- AppKit status-item bridge for a true global "open popover" shortcut.
- More detailed audio activity metering.
