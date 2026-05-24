# AudioRouter

AudioRouter is a native SwiftUI macOS menu-bar app for visual audio control. It manages real Core Audio devices today, saves app-to-output routing preferences, and keeps every unsupported routing feature clearly labeled instead of pretending it is live.

## What Works Now

- Menu bar popover, main visual dashboard, and AudioRouter Settings window.
- Real input and output device discovery through Core Audio.
- Current default input/output detection.
- Switching the system output device and system input device.
- Output volume, input volume, mute, and balance where a device exposes those controls.
- Core Audio hardware change observation plus a refresh fallback for Bluetooth, AirPlay, USB, HDMI, virtual, aggregate, and built-in device changes.
- Running audio-capable app discovery through Core Audio process objects, with a running-app fallback.
- Persistent route preferences, EQ settings, shortcuts, setup cards, and visual output groups.
- Live Mode for real device control, and Demo Mode for UI testing with mock apps/devices/meters.

## Live Versus Demo

Live Mode uses public macOS APIs for real device state and system controls. It does not animate fake meters. If process-tap metering is not active, the UI shows “Meter unavailable.”

Demo Mode is only for previews and visual testing. It uses mock apps, devices, routes, output groups, and animated meters, and it is always labeled as Demo.

## Backend Architecture

AudioRouter is split into layers:

- `AudioDeviceService`: real Core Audio device management.
- `RunningAppService` and `ProcessAudioMonitor`: running app detection and process-tap probing.
- `AudioRoutingManager`: route preference persistence and status calculation.
- `PublicAPIAudioRoutingBackend`: real public-API support for devices, app discovery, and saved route preferences.
- `FutureRoutingPluginBackend`: stub architecture for a future audio backend that could own streams and render them to chosen outputs.

## Core Audio APIs Used

- `AudioObjectGetPropertyData`
- `AudioObjectSetPropertyData`
- `AudioObjectAddPropertyListenerBlock`
- `kAudioHardwarePropertyDevices`
- `kAudioHardwarePropertyDefaultOutputDevice`
- `kAudioHardwarePropertyDefaultInputDevice`
- `kAudioHardwarePropertyProcessObjectList`
- `kAudioDevicePropertyVolumeScalar`
- `kAudioDevicePropertyMute`
- `kAudioDevicePropertyStreamConfiguration`
- `kAudioDevicePropertyDeviceNameCFString`
- `kAudioDevicePropertyDeviceUID`
- `AudioHardwareCreateProcessTap` and `AudioHardwareDestroyProcessTap` for the process-tap permission probe on macOS 14.2+

## What Requires A Real Audio Backend

True independent app routing, such as Spotify to one speaker while Safari stays on MacBook speakers, requires more than SwiftUI and simple device properties. A production implementation needs an audio routing backend such as:

- Audio Server Driver Plug-in or virtual audio device.
- Process audio capture.
- Audio processing graph.
- Per-device render outputs.
- Permission-aware capture helper.
- Low-latency buffer scheduling and cleanup.

AudioRouter currently saves those desired routes and marks them “Requires Audio Backend.” Output groups are also visual route targets today; actual simultaneous multi-output playback requires the same backend layer.

## EQ And Effects

The 10-band EQ UI, presets, curve preview, and Custom preset are saved settings. Public Core Audio device APIs do not apply arbitrary system-wide or per-app EQ. EQ is marked as UI-only until a backend processing graph exists.

## Permissions

The generated app bundle includes `NSAudioCaptureUsageDescription`. AudioRouter does not use private TCC APIs. The Advanced screen has a process-tap probe button that starts a public Core Audio tap attempt so macOS can handle permission naturally.

## Run

```bash
./script/build_and_run.sh
```

The script builds the SwiftPM product, stages `dist/AudioRouter.app`, writes the app bundle `Info.plist`, copies `Resources/AppIcon.icns`, and launches the app bundle.

## Verify

```bash
swift build
swift run AudioRouterChecks
./script/build_and_run.sh --verify
plutil -lint dist/AudioRouter.app/Contents/Info.plist
```

This Command Line Tools install does not include `XCTest` or Swift's `Testing` module, so the package includes `AudioRouterChecks` as a small executable check suite for persistence, routing status, shortcuts, and model behavior.

## Future Work

- Full process-tap aggregate-device IO pipeline for real level meters.
- Routing plugin or virtual audio device for true per-app output routing.
- Real per-app gain, mute, and EQ processing.
- Real simultaneous output groups.
- Signed and notarized app bundle with production launch-at-login behavior.
