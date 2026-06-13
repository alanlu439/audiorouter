# AudioRouter Download And Use Guide

This file is included with the AudioRouter download ZIP. The ZIP also includes `AudioRouter-User-Manual.pdf` for a more visual, printable guide.

This guide currently applies to the macOS public ZIP. A Windows implementation has been scaffolded in `windows/AudioRouter.Windows`, but there is not a public Windows download yet.

## Install

1. Open `AudioRouter-macOS.zip`.
2. Open the extracted folder.
3. Open `AudioRouter-User-Manual.pdf` if you want the guided walkthrough.
4. Move `AudioRouter.app` to `/Applications`.
5. Control-click or right-click `AudioRouter.app`.
6. Choose `Open`.
7. Click `Open` again when macOS asks whether you want to open it.
8. If macOS asks for System Audio Recording permission, approve AudioRouter.

AudioRouter's current public ZIP is not Apple-notarized yet. That means double-clicking the app the first time can show an Apple verification warning. Use the Control-click/right-click `Open` flow above for the first launch. Do not disable Gatekeeper.

If macOS still blocks the app:

1. Open `System Settings`.
2. Go to `Privacy & Security`.
3. Scroll to the Security message for AudioRouter.
4. Click `Open Anyway`.
5. Return to `/Applications`, Control-click `AudioRouter.app`, and choose `Open`.

## Quick Start

1. Connect Bluetooth speakers, AirPods, or other outputs in macOS System Settings first.
2. Open AudioRouter.
3. Select a route/app row such as Spotify, Apple Music, or Chrome.
4. Choose an output device or output group.
5. Press `Command =` to raise the selected track by exactly 1%.
6. Press `Command -` to lower the selected track by exactly 1%.
7. Use `Follow System Output` to send that app back to the normal macOS output.

AudioRouter cannot approve macOS privacy prompts automatically. If macOS asks for permission, the user has to approve it manually.

## Optional Mixer Input Driver

If you want AudioRouter to appear in DAWs or mixer software as a real input, install the experimental HAL driver:

```bash
./script/install_hal_driver.sh
```

macOS will ask for an administrator password, install `AudioRouterHAL.driver`, and restart Core Audio once. Reopen your mixer app after that and choose:

```text
AudioRouter Virtual Input
```

The driver is fed by active live AudioRouter routes. If no live route is running, the virtual input outputs silence.

To remove the driver:

```bash
./script/uninstall_hal_driver.sh
```

## What The Badges Mean

- `Live`: AudioRouter is actively routing the selected app through the process-tap backend.
- `Working`: The app is following the normal system output.
- `Saved Only`: AudioRouter saved the route and will retry when the app/device is ready.
- `Requires Audio Backend`: macOS public APIs could not start that route reliably.
- `Device Missing`: The selected output is disconnected.

## Notes

- AudioRouter can only use devices macOS already sees.
- Some apps or protected streams may not expose routeable audio through public APIs.
- Bluetooth and AirPlay devices can have latency or drift, especially in multi-speaker groups.
- The current public ZIP can require the first-launch right-click flow because it is not Apple-notarized yet.

## More Help

Open the project README for full setup, troubleshooting, permissions, update, and packaging notes:

https://github.com/alanlu439/audiorouter
