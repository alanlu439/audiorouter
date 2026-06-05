#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
DRIVER_DIR="$ROOT_DIR/Driver"
BUILD_DIR="$ROOT_DIR/dist/AudioRouterHAL.driver"
CONTENTS_DIR="$BUILD_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"

rm -rf "$BUILD_DIR"
mkdir -p "$MACOS_DIR"

xcrun clang \
  -std=c11 \
  -Wall \
  -Wextra \
  -Wno-unused-parameter \
  -fvisibility=hidden \
  -bundle \
  -framework CoreAudio \
  -framework CoreFoundation \
  -o "$MACOS_DIR/AudioRouterHAL" \
  "$DRIVER_DIR/AudioRouterHALDriver.c" \
  -Wl,-exported_symbols_list,"$DRIVER_DIR/AudioRouterHAL.exp"

cp "$DRIVER_DIR/Info.plist" "$CONTENTS_DIR/Info.plist"

codesign --force --sign - "$BUILD_DIR" >/dev/null
plutil -lint "$CONTENTS_DIR/Info.plist" >/dev/null

echo "$BUILD_DIR"
