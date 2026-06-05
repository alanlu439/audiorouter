#!/usr/bin/env bash
set -euo pipefail

HAL_DIR="/Library/Audio/Plug-Ins/HAL"
DRIVER_NAME="AudioRouterHAL.driver"

echo "AudioRouter will remove $DRIVER_NAME from $HAL_DIR."
echo "Removing a HAL driver restarts Core Audio once."

sudo rm -rf "$HAL_DIR/$DRIVER_NAME"
sudo killall coreaudiod 2>/dev/null || true

echo "Removed $HAL_DIR/$DRIVER_NAME"
