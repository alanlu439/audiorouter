#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

source "$ROOT_DIR/script/macos_sdk_env.sh"
if [[ "${AUDIOROUTER_SDK_FALLBACK:-0}" == "1" ]]; then
  echo "Using compatible macOS SDK: $SDKROOT" >&2
fi

export CLANG_MODULE_CACHE_PATH="${CLANG_MODULE_CACHE_PATH:-$ROOT_DIR/.build/module-cache}"
export SWIFTPM_CACHE_PATH="${SWIFTPM_CACHE_PATH:-$ROOT_DIR/.build/swiftpm-cache}"
mkdir -p "$CLANG_MODULE_CACHE_PATH" "$SWIFTPM_CACHE_PATH"

swift run --disable-sandbox AudioRouterChecks "$@"
