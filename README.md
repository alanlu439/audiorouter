# AudioRouter

AudioRouter is a native SwiftUI macOS menu-bar app for visual audio control. It manages real Core Audio devices, attempts live app-to-output routing through public process taps on supported macOS versions, and keeps unsupported routing features clearly labeled instead of pretending they are live.

## Download

Download the latest stable build from GitHub Releases:

[Download AudioRouter ZIP](https://github.com/alanlu439/audiorouter/releases/latest/download/AudioRouter-macOS.zip)

After downloading:

1. Open `AudioRouter-macOS.zip`.
2. Open the extracted `AudioRouter-macOS` folder.
3. Read `DOWNLOAD_AND_USE.md` for install, first-run, routing, and shortcut instructions.
4. Move `AudioRouter.app` to `/Applications`.
5. Control-click or right-click `AudioRouter.app`, choose `Open`, then confirm.

The current public ZIP is not Apple-notarized yet. On first launch, macOS can show a verification warning. Use the Control-click/right-click `Open` flow above, or open `System Settings` -> `Privacy & Security` -> `Open Anyway` if macOS still blocks it. Keep Gatekeeper enabled.

Local development bundles in `dist/AudioRouter.app` are also ad-hoc signed for testing and can trigger the same first-launch warning.

## How To Run AudioRouter

### Run the GitHub download

1. Download `AudioRouter-macOS.zip` from the latest GitHub Release.
2. Open the ZIP.
3. Open the extracted `AudioRouter-macOS` folder.
4. Read `DOWNLOAD_AND_USE.md`.
5. Move `AudioRouter.app` to `/Applications`.
6. Control-click or right-click `AudioRouter.app`.
7. Choose `Open`, then confirm.
8. Approve the macOS System Audio Recording prompt when AudioRouter asks for routing or meter access.

If macOS still blocks the app, open `System Settings` -> `Privacy & Security`, click `Open Anyway` beside the AudioRouter warning, then Control-click `AudioRouter.app` and choose `Open` again.

### Run from source

Requirements:

- macOS 14.2 or newer
- Xcode command line tools
- Swift 5.10 or newer

Build and open the app bundle:

```bash
./script/build_and_run.sh
```

Build the app bundle without opening it:

```bash
./script/build_and_run.sh --bundle
```

The local app bundle is created at:

```text
dist/AudioRouter.app
```

Run validation checks:

```bash
swift build --disable-sandbox
swift run --disable-sandbox AudioRouterChecks
plutil -lint dist/AudioRouter.app/Contents/Info.plist
```

## License

AudioRouter source code is available under the custom [AudioRouter Noncommercial License 1.0](LICENSE) with required attribution to Alan Lu.

You may use, copy, modify, publish, and distribute AudioRouter for noncommercial purposes only, provided that the license and required notices are preserved. Commercial use is not permitted without prior written permission from Alan Lu.

Because commercial use is restricted, AudioRouter is source-available rather than OSI open source.

The AudioRouter name, logo, app icon, and branding assets are not licensed for commercial use and may not be used in a way that suggests endorsement without prior written permission.

## What Works Now

- Menu bar popover, main visual dashboard, and AudioRouter Settings window.
- Real input and output device discovery through Core Audio.
- Current default input/output detection.
- Switching the system output device and system input device.
- Output volume, input volume, mute, and balance where a device exposes those controls.
- Core Audio hardware change observation plus a refresh fallback for Bluetooth, AirPlay, USB, HDMI, virtual, aggregate, and built-in device changes.
- Running audio-capable app discovery through Core Audio process objects, with a running-app fallback.
- Experimental live per-app routes on macOS 14.2+ using public Core Audio process taps, transient aggregate devices, and an IO callback.
- High-quality experimental route rendering using 32-bit floating-point PCM, source-rate-first AudioQueue client formats, Core Audio output conversion, high-quality drift compensation, and clean unity-gain snapping to avoid accidental limiting near 100%.
- Source-quality badges beside route app names, dynamically refreshed from the real Core Audio process-tap format when macOS exposes the source, with `Pending` shown only until a tap probe or live route can read the format.
- Experimental group play: route one app to an output group so the captured source is rendered to multiple connected speakers through separate `AudioQueue` outputs.
- Per-route volume, mute, and live meters while an experimental process-tap route is active.
- Live 10-band EQ processing for AudioRouter process-tap routes, with dynamic slider updates and a saved Custom preset.
- Smoother fader-style volume controls with clean 1% steps, visible percent readouts, and selected-track keyboard gain control with `Command =` and `Command -`.
- Backend readiness panel in the popover, dashboard, and Advanced settings so the app shows whether routes are ready, live, saved, or waiting for playback.
- Custom route apps: add running apps from the visual picker or browse for an installed `.app`, then assign that app to an output.
- Customizable source-app dashboard: hide default source apps, restore defaults, drag to reorder the app list, or add your own route apps visually.
- Top-right user profiles with full display names, so saved setups can be separated by person.
- First-run visual onboarding with a route setup walkthrough, permission probe, and Privacy Settings shortcut.
- Smoother device-change handling that waits through Bluetooth/AirPods re-enumeration bursts before marking a route missing, without forcing another system-output switch during connect or disconnect events.
- Menu bar mini mixer for quick system and app volume/mute controls.
- Route health diagnostics showing app detection, playback activity, output availability, backend readiness, and exact failure reasons.
- VoiceOver-friendly labels, values, hints, keyboard commands, and Reduce Motion-aware meters across the main audio controls.
- Built-in GitHub release update checking with a persistent latest-download link.
- Persistent route preferences, EQ settings, shortcuts, setup cards, and visual output groups.
- Live Mode for real device control, and Demo Mode for UI testing with mock apps/devices/meters.

## Profiles And Setups

Use the profile button in the top-right corner of the main window to switch users, add a profile, rename it, or delete the current profile. The control displays the active profile's full name so the current setup owner is always visible.

Saved setups in the Setups tab belong to the active profile. Existing setups from older builds are kept under `Default Profile`, and new profiles start with an empty setup list so each user can keep their own preferred routing, EQ, volume, and mute presets.

## Live Versus Demo

Live Mode uses public macOS APIs for real device state, system controls, and experimental process-tap routes. It does not animate fake meters. If no live process-tap route is active, the UI shows “Meter unavailable.”

Demo Mode is only for previews and visual testing. It uses mock apps, devices, routes, output groups, and animated meters, and it is always labeled as Demo.

## Backend Architecture

AudioRouter is split into layers:

- `AudioDeviceService`: real Core Audio device management.
- `RunningAppService` and `ProcessAudioMonitor`: running app detection and process-tap probing.
- `ProcessTapRoutingEngine`: experimental public-API routing path using `CATapDescription`, a private process tap, a transient aggregate capture device, PCM ring buffers, and one or more `AudioQueue` renderers pinned to selected output devices.
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
- `kAudioDevicePropertyAvailableNominalSampleRates`
- `kAudioDevicePropertyDeviceNameCFString`
- `kAudioDevicePropertyDeviceUID`
- `AudioHardwareCreateProcessTap` and `AudioHardwareDestroyProcessTap` on macOS 14.2+
- `AudioHardwareCreateAggregateDevice` and `AudioHardwareDestroyAggregateDevice`
- `AudioDeviceCreateIOProcIDWithBlock`, `AudioDeviceStart`, and `AudioDeviceStop`
- `AudioQueueNewOutputWithDispatchQueue`, `kAudioQueueProperty_CurrentDevice`, `AudioQueueStart`, and `AudioQueueStop`

## What Requires A Real Audio Backend

AudioRouter now has an experimental public-API route path. It can attempt a selected app route such as Spotify to a selected Bluetooth speaker when macOS exposes a process object, grants System Audio Recording permission, and the selected device can be used in the transient aggregate device.

A production-grade version still needs a dedicated audio backend for reliability across all apps/devices, lower latency, effects, and sample-locked multi-output groups:

- Audio Server Driver Plug-in or virtual audio device.
- Process audio capture.
- Audio processing graph.
- Per-device render outputs.
- Permission-aware capture helper.
- Low-latency buffer scheduling and cleanup.

When the experimental route starts successfully, the UI marks it “Live.” If macOS denies capture, the app is not producing a tap-able stream, or the aggregate route cannot start, AudioRouter saves the desired route and marks it “Requires Audio Backend.” Output groups can fan out one live route to multiple devices, but independent Bluetooth/AirPlay/USB devices may have latency differences or drift without a production routing backend.

AudioRouter keeps its internal live route path lossless where public APIs allow it: captured audio is rendered as 32-bit floating-point PCM, the source tap sample rate is preserved as the AudioQueue client format, and Core Audio performs any device-side conversion required by the selected output. Bluetooth, AirPlay, and some USB devices can still apply their own codec, firmware, latency, or hardware sample-rate limits outside AudioRouter.

The backend readiness panel is the fastest way to see what to do next:

- `Devices`: confirms connected Bluetooth outputs and the system speaker are available.
- `Route Apps`: confirms configured route apps have Core Audio process objects while playing audio.
- `Process Taps`: shows whether the public capture path is available on this macOS version.
- `Custom Routes`: shows whether any selected app-to-output route is live or saved for retry.

## EQ And Effects

The 10-band EQ UI, presets, curve preview, and Custom preset are saved settings. When a source is routed through AudioRouter's live process-tap route engine, EQ bands are applied to the captured 32-bit floating-point PCM stream before it is rendered to the selected output device. EQ changes are dynamic, so moving a slider updates active routes without restarting playback.

Public Core Audio device APIs still do not apply arbitrary EQ to system audio that is not routed through AudioRouter. Full system-wide EQ remains future backend work.

## Permissions

The generated app bundle includes `NSAudioCaptureUsageDescription`. AudioRouter does not use private TCC APIs. The Advanced screen has a process-tap probe button, and choosing a custom output now starts a public Core Audio global tap probe immediately so macOS can ask for System Audio Recording permission before the selected app has started playback. If the app process is not visible yet, AudioRouter saves the route and retries automatically when Core Audio exposes the process.

macOS system prompts cannot be auto-approved by AudioRouter or any normal app. AudioRouter instead shows visual instructions, opens Privacy & Security when requested, and keeps routes saved while you approve the prompt yourself.

## Updates And Releases

AudioRouter can check GitHub Releases and the latest GitHub commit from the app. Release updates auto-fetch the newest ZIP when a newer version is available and prompt you to install once the download is ready. Commit updates are shown as source update notices, so every pushed commit can inform installed apps that newer work is available on GitHub. Automatic checks run at launch and continue about every 15 minutes while AudioRouter is open when enabled, and the last check time is saved across app launches. The Updates card and Advanced settings both include a visual auto-check toggle. The updater uses the latest release API plus the latest `main` commit API, follows `v`-prefixed semantic version tags, times out quickly on network problems, and shows readable errors if GitHub cannot be reached.

This is a lightweight public-release updater, not a silent in-place installer. The Install button opens the downloaded ZIP so you can move the app to Applications. Future work can replace it with Sparkle once a Developer ID signing and update-feed workflow is ready.

Public release builds produce a ZIP only. The recommended path is Developer ID signing and Apple notarization:

```bash
export DEVELOPER_ID_APPLICATION="Developer ID Application: Your Name (TEAMID)"
export NOTARYTOOL_PROFILE="AudioRouterNotary"
export NOTARIZE=1
./script/package_release.sh
```

`NOTARYTOOL_PROFILE` should be created with `xcrun notarytool store-credentials`. The script signs the app with `DEVELOPER_ID_APPLICATION`, submits a ZIP to Apple's notary service, staples the notarization ticket to the app, validates the staple, runs Gatekeeper assessment with `spctl`, then recreates the final ZIP with the stapled app inside.

To intentionally publish the current unnotarized ZIP, use:

```bash
ALLOW_UNNOTARIZED_PUBLIC_ZIP=1 ./script/package_release.sh
```

That creates `dist/AudioRouter-macOS.zip` and includes `DOWNLOAD_AND_USE.md` with the first-launch Control-click/Open instructions. Users can run it, but macOS can show an Apple verification warning because the app is not notarized yet.

For a local-only test image that is expected to be blocked after download, use:

```bash
LOCAL_TEST_ZIP=1 ./script/package_release.sh
```

That creates `dist/AudioRouter-macOS-local-untrusted.zip`. Do not upload that file to GitHub Releases. The updater and README download link use only `AudioRouter-macOS.zip`.

Each release ZIP extracts to an `AudioRouter-macOS` folder containing `AudioRouter.app` and `DOWNLOAD_AND_USE.md` so users have install and first-run instructions directly inside the download.

## Build From Source

Use this path if you want to build AudioRouter locally instead of using the release download.

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
4. Start playback in Spotify, Apple Music, Chrome, or another app you added.
5. To customize sources, open the Routing Dashboard, click `Add App`, pick a running app, browse for an installed `.app`, drag input rows to reorder them, or hide apps you do not want from the source row menu.
6. Use the Route Builder, pick an output from an app row, or drag the app card onto an output device card.
7. When macOS asks for System Audio Recording permission, allow AudioRouter.
8. If a route starts successfully, the route badge changes to `Live` and the meter begins moving.
9. Select a route/app row, then press `Command =` or `Command -` to adjust that track's gain by exactly 1% per press. The source card fader and mute button also work when the route backend supports per-app control.
10. Use `Follow System Output` to remove a custom route and send the app back to the normal system output.

If the backend panel says `Saved Only`, leave the source app playing and click `Retry Route`. If it says `Requires Backend`, the chosen app/device pair could not be made live through public Core Audio process taps, but the route preference is saved for a future routing backend.

AudioRouter starts with Spotify, Apple Music, and Chrome as source apps. You can add more apps from the Routing Dashboard. Output choices are connected Bluetooth devices plus the built-in/system speaker.

## Status Badges

- `Live`: AudioRouter started a process-tap route and is rendering it to the selected output.
- `Working`: The source is following the normal macOS system output.
- `Saved Only`: AudioRouter saved the route and will try to restore it when the app/device is available.
- `Requires Audio Backend`: macOS public APIs could not start that route. The route choice is saved, but a production audio backend is needed for reliable routing.
- `Device Missing`: The selected output is disconnected.

## Troubleshooting

- If the route does not start, make sure the source app is actively playing audio, then click `Retry Route`.
- If permission was denied, open System Settings, grant AudioRouter System Audio Recording permission, then quit and reopen AudioRouter.
- If the selected Bluetooth speaker is missing, connect it in macOS System Settings first.
- If the app still plays through the original output, remove the route with `Follow System Output`, start playback again, and reassign the output.
- Some protected streams and device formats may not be routable through public macOS APIs.

## Verify

```bash
swift build
swift run AudioRouterChecks
./script/build_and_run.sh --verify
LOCAL_TEST_ZIP=1 ./script/package_release.sh
plutil -lint dist/AudioRouter.app/Contents/Info.plist
codesign --verify --deep --strict dist/AudioRouter.app
```

This Command Line Tools install does not include `XCTest` or Swift's `Testing` module, so the package includes `AudioRouterChecks` as a small executable check suite for persistence, routing status, shortcuts, and model behavior.

## Future Work

- Harden the experimental process-tap aggregate-device IO pipeline across more devices and formats.
- Sparkle-based automatic in-place updates after the notarized Developer ID release workflow is in place.
- Routing plugin or virtual audio device for production-grade per-app output routing.
- Broader EQ processing through a future backend for audio that is not routed through AudioRouter.
- Sample-locked output group sync across independent devices.
- Production launch-at-login behavior.
