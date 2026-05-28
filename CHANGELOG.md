# Changelog

## 1.0.2 - 2026-05-27

### Usability And Stability

- Reduced UI stalls by stopping passive refreshes from starting saved routes automatically.
- Shortened the process-tap route-start probe so failed route attempts return faster.
- Added a visual Route Builder for smoother source-app to output-device setup.
- Kept the dashboard routing area in a side-by-side input/output layout with clearer input and output labels, using horizontal scrolling instead of stacking when space is tight.
- Added first-run onboarding with visual routing steps, permission probing, and a Privacy Settings shortcut.
- Added source-app customization: hide default apps, restore defaults, add running apps, or browse for installed apps.
- Added persistent source-app ordering controls, drag-and-drop reordering, and clearer dashboard section dividers.
- Kept saved custom routes intact during Bluetooth/AirPods device-change bursts instead of immediately resetting them.
- Preserved the current system output when a newly connected device tries to become default, so adding AirPods does not interrupt existing playback.
- Smoothed meters with faster lightweight updates and refreshed Core Audio device changes less aggressively.
- Made release packaging warn clearly when a DMG is ad-hoc signed or not notarized.

## 1.0.1 - 2026-05-26

### Audio Quality

- Improved the experimental route renderer to keep routed audio in 32-bit floating-point PCM with the source tap sample rate whenever available.
- Preserved the highest practical channel count supported by both the process tap and the selected output device, instead of forcing the route format to stereo.
- Raised Core Audio sub-tap drift compensation to high quality for transient route devices.
- Added soft peak limiting for boosted per-app route volume to reduce hard clipping while keeping normal-volume audio untouched.
- Increased the route pipe buffer slightly to reduce dropouts during short scheduling hiccups.

## 1.0.0 - 2026-05-26

AudioRouter 1.0.0 is the first large public DMG release of the app.

### Highlights

- Native macOS menu-bar audio control app with a visual routing dashboard.
- Real Core Audio device discovery for input and output devices.
- System input/output switching, volume, mute, and balance where supported by the selected device.
- Visual app routing interface for Spotify, Apple Music, Chrome, and user-added apps.
- Experimental public Core Audio process-tap routing and metering path on supported macOS versions.
- Clear route health and backend status badges so users can see what is live, saved, simulated, or backend-required.
- DMG-only public release package.
- In-app GitHub updater that auto-fetches newer DMG builds and prompts the user to install.
- Dark, production-console-inspired interface with accessibility labels, hints, values, keyboard commands, and Reduce Motion-aware meters.

### Important Notes

- The current public build is ad-hoc signed and not notarized yet.
- Some protected streams, apps, and device formats may not route through public macOS APIs.
- Production-grade per-app routing across all apps and multiple outputs still requires a dedicated audio backend or virtual audio driver.
