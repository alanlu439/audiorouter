#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
HAL_DIR="/Library/Audio/Plug-Ins/HAL"
DRIVER_NAME="AudioRouterHAL.driver"

if [[ -d "$ROOT_DIR/$DRIVER_NAME" ]]; then
  BUILT_DRIVER="$ROOT_DIR/$DRIVER_NAME"
elif [[ -x "$ROOT_DIR/script/build_hal_driver.sh" ]]; then
  "$ROOT_DIR/script/build_hal_driver.sh" >/dev/null
  BUILT_DRIVER="$ROOT_DIR/dist/$DRIVER_NAME"
else
  echo "Cannot find $DRIVER_NAME or script/build_hal_driver.sh." >&2
  exit 2
fi

echo "AudioRouter will install $DRIVER_NAME into $HAL_DIR."
echo "macOS requires administrator permission for HAL audio drivers."
echo "Installing or updating a HAL driver restarts Core Audio once."

sudo mkdir -p "$HAL_DIR"
sudo rm -rf "$HAL_DIR/$DRIVER_NAME"
sudo cp -R "$BUILT_DRIVER" "$HAL_DIR/$DRIVER_NAME"
sudo chown -R root:wheel "$HAL_DIR/$DRIVER_NAME"
sudo chmod -R go-w "$HAL_DIR/$DRIVER_NAME"
sudo killall coreaudiod 2>/dev/null || true

echo "Installed $HAL_DIR/$DRIVER_NAME"
echo "Reopen your mixer app and look for: AudioRouter Virtual Input"
