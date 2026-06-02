# AudioRouter Download And Use Guide

This file is included with the AudioRouter download ZIP.

## Install

1. Open `AudioRouter-macOS.zip`.
2. Open the extracted folder.
3. Move `AudioRouter.app` to `/Applications`.
4. Open `AudioRouter.app`.
5. If macOS asks for System Audio Recording permission, approve AudioRouter.

If macOS says it cannot verify AudioRouter is free of malware, the downloaded app was not Developer ID signed and notarized. Use the newest GitHub Release with a notarized `AudioRouter-macOS.zip`, or build locally from source for development.

## Quick Start

1. Connect Bluetooth speakers, AirPods, or other outputs in macOS System Settings first.
2. Open AudioRouter.
3. Select a route/app row such as Spotify, Apple Music, or Chrome.
4. Choose an output device or output group.
5. Press `Command =` to raise the selected track by exactly 1%.
6. Press `Command -` to lower the selected track by exactly 1%.
7. Use `Follow System Output` to send that app back to the normal macOS output.

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
- For reliable public downloads, the ZIP must contain a Developer ID signed and Apple-notarized app.

## More Help

Open the project README for full setup, troubleshooting, permissions, update, and packaging notes:

https://github.com/alanlu439/audiorouter
