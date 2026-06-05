# AudioRouter HAL Driver

AudioRouter includes an experimental Core Audio HAL driver named `AudioRouterHAL.driver`.

The driver creates a real macOS input device:

```text
AudioRouter Virtual Input
```

Mixer apps such as Logic, Ableton, OBS, and DAWs should list this input after the driver is installed and Core Audio restarts.

## Install

From the AudioRouter project folder or release folder:

```bash
./script/install_hal_driver.sh
```

macOS will ask for an administrator password because HAL drivers live in:

```text
/Library/Audio/Plug-Ins/HAL
```

The installer restarts Core Audio once. Reopen your mixer app after installation.

## Uninstall

```bash
./script/uninstall_hal_driver.sh
```

## How audio reaches the driver

The driver is a real system input. AudioRouter feeds it from active live process-tap routes through a shared-memory bridge.

Use it like this:

1. Install the HAL driver.
2. Reopen AudioRouter.
3. Start playback in Spotify, Chrome, Music, or another configured app.
4. Create a live route in AudioRouter for that app.
5. In your mixer software, choose `AudioRouter Virtual Input`.

If no AudioRouter live route is active, the driver outputs silence. This is intentional.

## Current limitations

- This is an experimental first driver layer.
- The current driver exposes one stereo virtual input, not one separate input per app.
- If multiple live app routes are active, they may share the same virtual input feed.
- The driver uses a 48 kHz, stereo, 32-bit floating-point stream.
- A production release should replace this bridge with a signed/notarized installer and a more robust low-latency IPC service.
