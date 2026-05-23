# AudioRouter

AudioRouter is an original SwiftUI macOS utility for controlling audio devices, system volume, app routing preferences, EQ presets, and quick audio setups. It is designed as a compact, dark-mode-first app with a main window, menu bar popover, and separate Settings window.

The app uses public macOS APIs only. Device discovery, default input/output switching, and supported device volume/mute/balance controls are backed by CoreAudio. Features macOS does not expose publicly, such as true arbitrary per-app output volume, independent per-app device routing, and system-wide EQ, are implemented as polished UI and persisted state with clear TODO notes for a future driver-backed audio engine.

## Features implemented

- Menu bar app with a rich SwiftUI popover.
- Opens as a normal macOS app with a Dock icon and main window, while also keeping a menu bar popover.
- Compact icon-only menu bar extra to reduce width and stay visible longer when the menu bar is crowded.
- Settings window with General, Devices, Shortcuts, Presets, and Advanced sections.
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
- 10-band EQ UI with Flat, Bass Boost, Vocal, Podcast, Movie, and Music presets.
- Save, apply, rename, and delete audio setups.
- Local keyboard shortcuts for mute, volume up/down, and next output device.
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
