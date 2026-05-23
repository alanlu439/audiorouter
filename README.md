# AudioRouter

AudioRouter is a SwiftUI macOS utility for routing Apple Music, Spotify, or Chrome audio to already-connected Bluetooth/CoreAudio output devices. The home screen is a visual connection board: application tile -> speaker tile. Routes are app-only: they capture the designated app and send it to the selected speaker without intentionally including system sound. You can select multiple inputs and outputs to create every app-to-output route, save multi-device output groups, then adjust each connection's volume independently. The Devices screen exposes default-output, volume, and mute controls when the hardware supports them, and the menu bar item provides quick route and output controls. It uses public CoreAudio process taps on macOS 14.2+ and does not manage Bluetooth pairing.

## Run

```bash
./script/build_and_run.sh
```

The script builds the SwiftPM product, stages `dist/AudioRouter.app`, writes the app bundle `Info.plist` with `NSAudioCaptureUsageDescription`, copies `Resources/AppIcon.icns`, and launches the bundle as a foreground macOS app.

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

This Command Line Tools install does not include `XCTest` or Swift's `Testing` module, so the package includes `AudioRouterChecks` as a small executable check suite for persistence, route restoration, and store cleanup behavior.

## Notes

- Output devices must already be connected in macOS.
- Starting a route may trigger the system audio-capture permission prompt.
- Protected or restricted streams may remain unavailable if macOS or the source app blocks capture.
