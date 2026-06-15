# AudioRouter User Manual

AudioRouter is a macOS menu-bar app for visual audio control. It lists real audio devices, lets you assign apps to output targets, saves setups, and shows what is live versus experimental.

## Quick Start Snapshot

- Dashboard is where you route an app to an output or Group Play target.
- Devices shows the real inputs and outputs macOS currently exposes.
- EQ changes active AudioRouter live routes when the route backend is running.
- Setups save your routes, device choices, mute states, and EQ preset.
- Advanced explains permissions, reliability tools, updates, and experimental backend features.

## Install From The ZIP

1. Download `AudioRouter-macOS.zip` from the latest GitHub Release.
2. Open the ZIP and then open the extracted `AudioRouter-macOS` folder.
3. Move `AudioRouter.app` to `/Applications`.
4. Control-click or right-click `AudioRouter.app`, choose `Open`, then confirm.
5. Approve macOS System Audio Recording permission when AudioRouter asks.

The public ZIP may not be Apple-notarized yet. If macOS says it cannot verify the app, use the Control-click `Open` flow. Do not disable Gatekeeper.

## First Run

Open AudioRouter from `/Applications`. The app appears in the macOS menu bar and can also show the main dashboard window.

Recommended first steps:

1. Connect your Bluetooth, USB, HDMI, or AirPlay audio devices in macOS System Settings.
2. Open AudioRouter.
3. Confirm the active output device appears in the output list.
4. Add or select a source app such as Spotify, Apple Music, or Chrome.
5. Choose a target output for that app.

## Appearance

AudioRouter supports `System`, `Light`, and `Dark` appearance modes. Open `Advanced`, then `System Controls`, and use the `Appearance` control to choose whether the app follows macOS or stays in a specific mode.

## Routing Apps To Outputs

The Dashboard is organized around Routes.

- Source apps are the apps that make sound.
- Outputs are speakers, headphones, or output groups.
- `Follow System Output` means the app uses the normal macOS output.
- A custom output means AudioRouter will try to route that app to the selected device.

Route badges are truth labels. `Working` means AudioRouter can control that route now. `Saved Only` means your choice is stored and will retry automatically. `Requires Audio Backend` means macOS public APIs could not complete that route reliably.

If a route shows `Saved Only`, AudioRouter has saved the preference and will retry when macOS exposes the app audio process. If a route shows `Requires Audio Backend`, the current public macOS APIs could not start that route reliably.

## Group Play

Group Play lets you create a visual multi-speaker target.

1. Open the Dashboard.
2. Create or select a Group Play target.
3. Add output devices to the group.
4. Assign a source app to the group.

Group Play is experimental. Bluetooth and AirPlay speakers can drift or add latency because each device has its own clock.

## Volume And Shortcuts

Click a source app or route row to select it.

- Press `Command =` to raise selected route gain by 1%.
- Press `Command -` to lower selected route gain by 1%.
- Use the gain slider for larger changes.
- Use mute buttons for quick silence without deleting the route.

Device volume controls only work when the output device exposes software volume to macOS.

For the smoothest adjustment, click the app or route row first, then use the keyboard shortcut for small 1% changes and the slider for larger moves.

## EQ

The EQ tab includes a 10-band equalizer and presets:

- Flat
- Bass Boost
- Vocal
- Podcast
- Movie
- Music
- Custom

EQ applies to AudioRouter's live process-tap routes when the route backend is active. It does not change untouched macOS system audio.

## Setups And Profiles

Setups save your preferred devices, routes, volume levels, mute states, and EQ selection.

Profiles let different users keep different setup collections. Use the profile control in the top-right area of the app to switch or rename profiles.

## Optional Mixer Input Driver

AudioRouter includes an experimental HAL driver for DAWs and mixer software that need a real macOS input device.

From the extracted download folder:

```bash
./script/install_hal_driver.sh
```

After installation, reopen your mixer app and look for:

```text
AudioRouter Virtual Input
```

To remove it:

```bash
./script/uninstall_hal_driver.sh
```

The driver is experimental and outputs silence unless AudioRouter is feeding it from an active live route.

## Updates

AudioRouter checks GitHub Releases, not every commit. When a new release is published, the app can show that an update is available and point you to the latest download.

Latest download:

https://github.com/alanlu439/audiorouter/releases/latest/download/AudioRouter-macOS.zip

Website:

https://alanlu439.github.io/audiorouter/

## Troubleshooting

If a route does not start:

1. Start playback in the source app.
2. Make sure the target output is connected in macOS.
3. Open Advanced, then Reliability.
4. Use Refresh, Probe Tap, or Retry Route.
5. Check the route badge for the reason.

If macOS blocks the app:

1. Open `System Settings`.
2. Go to `Privacy & Security`.
3. Find the AudioRouter warning.
4. Click `Open Anyway`.
5. Control-click `AudioRouter.app` and choose `Open`.

If Bluetooth audio pauses when AirPods are removed, AudioRouter can try to resume supported media apps, but AirPods ear-detection behavior is controlled by macOS and the source app.

## What Is Live Today

- Real macOS audio-device discovery.
- Default input/output detection and switching.
- Device volume and mute where supported.
- Running app discovery.
- Saved route preferences.
- Experimental process-tap routing and metering on supported macOS versions.
- Experimental Group Play and HAL virtual input support.

## What Is Experimental

- Reliable per-app routing for every app.
- Multi-speaker sync across Bluetooth or AirPlay.
- DAW-visible per-app virtual inputs.
- Windows support.

AudioRouter uses public APIs and does not require disabling SIP.
