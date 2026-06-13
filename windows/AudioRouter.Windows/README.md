# AudioRouter for Windows

AudioRouter for Windows is the Windows 11 sibling app for AudioRouter. It keeps the same product model as the macOS app, but uses native Windows audio APIs instead of AppKit, SwiftUI, Core Audio, HAL, and AudioQueue.

## Current Scope

This scaffold implements the first Windows compatibility layer:

- WinUI 3 shell with a dashboard-style window.
- Native C++ audio backend seams.
- MMDevice endpoint enumeration for output and input devices.
- Endpoint volume and mute via `IAudioEndpointVolume`.
- Audio session discovery via `IAudioSessionManager2`.
- Per-session volume and mute via `ISimpleAudioVolume`.
- Honest capability flags for unsupported routing features.
- Shared JSON contract documentation for settings, routes, EQ, profiles, and shortcuts.

## What Is Not Claimed Yet

True production per-app output routing on Windows is not marked as fully supported by this scaffold. The Windows backend has a process-loopback capture seam for future WASAPI routing work, but reliable app-to-device routing and app-as-input support may require a signed Windows audio service or virtual endpoint driver.

The Windows MVP does not use undocumented default-device switching APIs. If direct default switching is needed later, choose a supported Windows mechanism or keep the app opening Windows Sound Settings.

## Build On Windows

Requirements:

- Windows 11
- Visual Studio 2022 with Desktop development with C++
- Windows App SDK workload support
- Windows 10/11 SDK

Build:

```powershell
msbuild .\AudioRouter.Windows.sln /restore /p:Configuration=Release /p:Platform=x64
```

The macOS SwiftPM app remains the production app today. This Windows project is a sibling implementation path and should be built on Windows runners or a Windows development machine.
