#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT_DIR/script/macos_sdk_env.sh"

# Requires a logged-in macOS graphical session; does not launch the audio engine.
CHECK_DIR="$(mktemp -d "${TMPDIR:-/tmp}/audiorouter-window-checks.XXXXXX")"
trap 'rm -rf "$CHECK_DIR"' EXIT
export CLANG_MODULE_CACHE_PATH="${CLANG_MODULE_CACHE_PATH:-$ROOT_DIR/.build/module-cache}"
mkdir -p "$CLANG_MODULE_CACHE_PATH"
xcrun swiftc -parse-as-library \
  -sdk "${SDKROOT:-$(xcrun --sdk macosx --show-sdk-path)}" \
  -module-cache-path "$CLANG_MODULE_CACHE_PATH" \
  "$ROOT_DIR/Sources/AudioRouterApp/MainWindowCoordinator.swift" \
  "$ROOT_DIR/Tests/AudioRouterWindowChecks/WindowChecks.swift" \
  -o "$CHECK_DIR/AudioRouterWindowChecks"
"$CHECK_DIR/AudioRouterWindowChecks"
