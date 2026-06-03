# Changelog

## Unreleased

## 1.1.1 - 2026-06-03

### Profiles

- Added a top-right user profile menu in the main AudioRouter window with full-name display, profile switching, profile creation, renaming, and deletion.
- Scoped saved setups to the active profile so different users can keep separate preferred presets on the same Mac.
- Added a quit confirmation warning so users do not accidentally stop active routing controls.
- Changed the in-app updater so only published GitHub Releases count as app updates; ordinary commits no longer trigger update prompts.
- Refreshed Devices, EQ, Setups, Shortcuts, and Advanced with the same dark studio-console styling used by the Dashboard.

### EQ

- Added live 10-band EQ processing to AudioRouter process-tap routes, applying band changes to routed 32-bit floating-point PCM before output rendering.
- Made EQ slider changes dynamic for active routes.
- Fixed Custom EQ so Save Custom stores the current curve and selecting Custom recalls the saved bands.

### Audio Quality

- Kept live route AudioQueue client formats at the source tap sample rate, letting Core Audio handle device-side conversion instead of relabeling source frames as a different hardware rate.
- Reworked the live route pipe to buffer Float32 samples directly, reducing CPU churn that could cause routed playback dropouts.
- Added live source-quality refreshes so active route badges update when Core Audio reports a changed process-tap format.
- Snapped tiny persisted gain drift around 100% back to clean unity gain to avoid accidental limiting on normal playback.
- Source-quality badges now fetch the real Core Audio process-tap format through a lightweight unmuted tap probe when a live route is not already running.
- Simplified source-quality badges beside route app names to show only the live process-tap sample rate, such as `48k`, while keeping detailed format info in the tooltip.
- Added Core Audio nominal sample-rate range discovery for output devices.
- Centralized experimental route format selection so live routes keep 32-bit floating-point PCM, prefer the source tap sample rate when every selected output supports it, and otherwise choose the nearest shared hardware-supported rate.
- Added regression checks for route sample-rate, channel-count, and float-PCM quality decisions.
- Increased the route pipe and output queue guard depth to reduce short scheduling dropouts during live per-app and Group Play routes.

## 1.1.0 - 2026-06-02

### Selected Track Control

- Added selected-track gain control: click an app or route row, then press Command-= or Command-- to adjust that source by exactly 1% per press.
- Reworked app, device, and group gain controls into smoother fader-style controls with cleaner percent readouts.
- Removed the extra native slider track artifact under gain controls for a quieter pro-audio layout.
- Snapped saved volume values to clean 1% steps to avoid noisy decimal drift.

### Performance And Device Stability

- Debounced app-route volume saves and throttled Core Audio device-volume writes to reduce UI lag while dragging.
- Stopped bundle/package builds from quitting a running AudioRouter instance unless the script is explicitly launching or verifying the app.
- Prevented AudioRouter from forcing the old system output back when Bluetooth devices such as AirPods connect or disconnect.
- Added a short device-topology settling window so automatic route retries do not interrupt audio during Bluetooth, AirPlay, or USB device changes.

### Download And Onboarding

- Added `DOWNLOAD_AND_USE.md` to the release ZIP with install, first-run, routing, shortcut, and troubleshooting instructions.
- Updated release packaging so ZIP downloads extract into an `AudioRouter-macOS` folder containing both `AudioRouter.app` and the manual.
- Added regression checks for selected-source volume keyboard commands and non-disruptive device-change handling.

## 1.0.3 - 2026-06-01

### Routing And Group Play

- Added proactive System Audio Recording permission probing when a custom output is chosen, so macOS can prompt before the selected app starts playback.
- Added live experimental Group Play routing, allowing one process-tap route to fan out to multiple connected output devices.
- Redesigned the dashboard around a simpler Routes view with a prominent Group Play patch flow and secondary individual output rows.
- Added persistent real app icons, smoother gain controls, compact route rows, and clearer output sections under the main route list.
- Added automatic retry handling for saved routes and group routes when Core Audio exposes the source process.

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
- Switched release packaging and updates from DMG to ZIP, while still refusing unsafe public archives unless Developer ID signing and Apple notarization are configured.

## 1.0.1 - 2026-05-26

### Audio Quality

- Improved the experimental route renderer to keep routed audio in 32-bit floating-point PCM with the source tap sample rate whenever available.
- Preserved the highest practical channel count supported by both the process tap and the selected output device, instead of forcing the route format to stereo.
- Raised Core Audio sub-tap drift compensation to high quality for transient route devices.
- Added soft peak limiting for boosted per-app route volume to reduce hard clipping while keeping normal-volume audio untouched.
- Increased the route pipe buffer slightly to reduce dropouts during short scheduling hiccups.

## 1.0.0 - 2026-05-26

AudioRouter 1.0.0 is the first large public release of the app.

### Highlights

- Native macOS menu-bar audio control app with a visual routing dashboard.
- Real Core Audio device discovery for input and output devices.
- System input/output switching, volume, mute, and balance where supported by the selected device.
- Visual app routing interface for Spotify, Apple Music, Chrome, and user-added apps.
- Experimental public Core Audio process-tap routing and metering path on supported macOS versions.
- Clear route health and backend status badges so users can see what is live, saved, simulated, or backend-required.
- Public release package.
- In-app GitHub updater that auto-fetches newer builds and prompts the user to install.
- Dark, production-console-inspired interface with accessibility labels, hints, values, keyboard commands, and Reduce Motion-aware meters.

### Important Notes

- The current public build is ad-hoc signed and not notarized yet.
- Some protected streams, apps, and device formats may not route through public macOS APIs.
- Production-grade per-app routing across all apps and multiple outputs still requires a dedicated audio backend or virtual audio driver.
