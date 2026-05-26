# Changelog

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
