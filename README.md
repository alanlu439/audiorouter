# AudioRouter

AudioRouter is a native SwiftUI macOS menu-bar app for visual audio control. It manages real Core Audio devices, attempts live app-to-output routing through public process taps on supported macOS versions, and keeps unsupported routing features clearly labeled instead of pretending they are live.

## What Works Now

- Menu bar popover, main visual dashboard, and AudioRouter Settings window.
- Real input and output device discovery through Core Audio.
- Current default input/output detection.
- Switching the system output device and system input device.
- Output volume, input volume, mute, and balance where a device exposes those controls.
- Core Audio hardware change observation plus a refresh fallback for Bluetooth, AirPlay, USB, HDMI, virtual, aggregate, and built-in device changes.
- Running audio-capable app discovery through Core Audio process objects, with a running-app fallback.
- Experimental live per-app routes on macOS 14.2+ using public Core Audio process taps, transient aggregate devices, and an IO callback.
- Per-route volume, mute, and live meters while an experimental process-tap route is active.
- Backend readiness panel in the popover, dashboard, and Advanced settings so the app shows whether routes are ready, live, saved, or waiting for playback.
- Persistent route preferences, EQ settings, shortcuts, setup cards, and visual output groups.
- Live Mode for real device control, and Demo Mode for UI testing with mock apps/devices/meters.

## Live Versus Demo

Live Mode uses public macOS APIs for real device state, system controls, and experimental process-tap routes. It does not animate fake meters. If no live process-tap route is active, the UI shows “Meter unavailable.”

Demo Mode is only for previews and visual testing. It uses mock apps, devices, routes, output groups, and animated meters, and it is always labeled as Demo.

## Backend Architecture

AudioRouter is split into layers:

- `AudioDeviceService`: real Core Audio device management.
- `RunningAppService` and `ProcessAudioMonitor`: running app detection and process-tap probing.
- `ProcessTapRoutingEngine`: experimental public-API routing path using `CATapDescription`, a private process tap, a transient aggregate capture device, a PCM ring buffer, and an `AudioQueue` renderer pinned to the selected output device.
- `AudioRoutingManager`: route preference persistence and status calculation.
- `PublicAPIAudioRoutingBackend`: real public-API support for devices, app discovery, system controls, and experimental process-tap routing.
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
- `AudioHardwareCreateProcessTap` and `AudioHardwareDestroyProcessTap` on macOS 14.2+
- `AudioHardwareCreateAggregateDevice` and `AudioHardwareDestroyAggregateDevice`
- `AudioDeviceCreateIOProcIDWithBlock`, `AudioDeviceStart`, and `AudioDeviceStop`
- `AudioQueueNewOutputWithDispatchQueue`, `kAudioQueueProperty_CurrentDevice`, `AudioQueueStart`, and `AudioQueueStop`

## What Requires A Real Audio Backend

AudioRouter now has an experimental public-API route path. It can attempt a selected app route such as Spotify to a selected Bluetooth speaker when macOS exposes a process object, grants System Audio Recording permission, and the selected device can be used in the transient aggregate device.

A production-grade version still needs a dedicated audio backend for reliability across all apps/devices, low latency, effects, and multi-output groups:

- Audio Server Driver Plug-in or virtual audio device.
- Process audio capture.
- Audio processing graph.
- Per-device render outputs.
- Permission-aware capture helper.
- Low-latency buffer scheduling and cleanup.

When the experimental route starts successfully, the UI marks it “Live.” If macOS denies capture, the app is not producing a tap-able stream, or the aggregate route cannot start, AudioRouter saves the desired route and marks it “Requires Audio Backend.” Output groups are also visual route targets today; actual simultaneous multi-output playback requires the same backend layer.

The backend readiness panel is the fastest way to see what to do next:

- `Devices`: confirms connected Bluetooth outputs and the system speaker are available.
- `Focused Apps`: confirms Spotify, Apple Music, or Chrome has a Core Audio process object while playing audio.
- `Process Taps`: shows whether the public capture path is available on this macOS version.
- `Custom Routes`: shows whether any selected app-to-output route is live or saved for retry.

## EQ And Effects

The 10-band EQ UI, presets, curve preview, and Custom preset are saved settings. Public Core Audio device APIs do not apply arbitrary system-wide or per-app EQ. EQ is marked as UI-only until a backend processing graph exists.

## Permissions

The generated app bundle includes `NSAudioCaptureUsageDescription`. AudioRouter does not use private TCC APIs. The Advanced screen has a process-tap probe button, and assigning an app to an output can also start a public Core Audio tap attempt so macOS can handle permission naturally.

## Quick Start

AudioRouter is currently distributed from source.

Requirements:

- macOS 14.2 or newer for process-tap capture.
- Xcode Command Line Tools or Xcode with SwiftPM support.
- Bluetooth speakers or headphones already paired and connected in macOS System Settings.

Build and open the app:

```bash
./script/build_and_run.sh
```

The script builds the SwiftPM product, stages `dist/AudioRouter.app`, writes the app bundle `Info.plist`, copies `Resources/AppIcon.icns`, and launches the app bundle.

## How To Use

1. Connect your Bluetooth speaker, AirPods, or other output device in macOS first.
2. Open AudioRouter from the menu bar.
3. Keep the app in Live Mode.
4. Start playback in Spotify, Apple Music, or Chrome.
5. In the Routing Dashboard, pick an output from that app's output dropdown, or drag the app card onto an output device card.
6. When macOS asks for System Audio Recording permission, allow AudioRouter.
7. If a route starts successfully, the route badge changes to `Live` and the meter begins moving.
8. Use the per-app volume and mute controls on the source card to adjust that route.
9. Use `Follow System Output` to remove a custom route and send the app back to the normal system output.

If the backend panel says `Saved Only`, leave the source app playing, click Refresh, then assign the output again. If it says `Requires Backend`, the chosen app/device pair could not be made live through public Core Audio process taps, but the route preference is saved for a future routing backend.

AudioRouter only shows Spotify, Apple Music, and Chrome as source apps in this MVP. Output choices are connected Bluetooth devices plus the built-in/system speaker.

## Status Badges

- `Live`: AudioRouter started a process-tap route and is rendering it to the selected output.
- `Working`: The source is following the normal macOS system output.
- `Saved Only`: AudioRouter saved the route and will try to restore it when the app/device is available.
- `Requires Audio Backend`: macOS public APIs could not start that route. The route choice is saved, but a production audio backend is needed for reliable routing.
- `Device Missing`: The selected output is disconnected.

## Troubleshooting

- If the route does not start, make sure the source app is actively playing audio, then refresh AudioRouter and assign the output again.
- If permission was denied, open System Settings, grant AudioRouter System Audio Recording permission, then quit and reopen AudioRouter.
- If the selected Bluetooth speaker is missing, connect it in macOS System Settings first.
- If the app still plays through the original output, remove the route with `Follow System Output`, start playback again, and reassign the output.
- Some protected streams and device formats may not be routable through public macOS APIs.

## Verify

```bash
swift build
swift run AudioRouterChecks
./script/build_and_run.sh --verify
plutil -lint dist/AudioRouter.app/Contents/Info.plist
```

This Command Line Tools install does not include `XCTest` or Swift's `Testing` module, so the package includes `AudioRouterChecks` as a small executable check suite for persistence, routing status, shortcuts, and model behavior.

## Future Work

- Harden the experimental process-tap aggregate-device IO pipeline across more devices and formats.
- Routing plugin or virtual audio device for production-grade per-app output routing.
- Real EQ processing in the backend audio graph.
- Real simultaneous output groups.
- Signed and notarized app bundle with production launch-at-login behavior.
