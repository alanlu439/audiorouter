#!/usr/bin/env bash

# macOS 27 Command Line Tools can expose the SwiftUI SDK without shipping the
# matching SwiftUIMacros host plug-in. Prefer the newest installed pre-27 SDK
# in that specific configuration so SwiftPM remains usable.
audiorouter_configure_macos_sdk() {
  if [[ -n "${SDKROOT:-}" && -d "$SDKROOT" ]]; then
    return
  fi

  local developer_dir
  local default_sdk
  developer_dir="$(xcode-select -p 2>/dev/null || true)"
  default_sdk="$(xcrun --sdk macosx --show-sdk-path 2>/dev/null || true)"
  [[ -n "$developer_dir" && -n "$default_sdk" ]] || return
  default_sdk="$(realpath "$default_sdk" 2>/dev/null || echo "$default_sdk")"

  local sdk_name
  local sdk_major
  sdk_name="$(basename "$default_sdk")"
  if [[ "$sdk_name" =~ ^MacOSX([0-9]+) ]]; then
    sdk_major="${BASH_REMATCH[1]}"
  else
    return
  fi

  local swiftui_macro_plugin="$developer_dir/usr/lib/swift/host/plugins/libSwiftUIMacros.dylib"
  if (( sdk_major < 27 )) || [[ -f "$swiftui_macro_plugin" ]]; then
    return
  fi

  local candidate
  while IFS= read -r candidate; do
    local candidate_name
    local candidate_major
    candidate_name="$(basename "$candidate")"
    if [[ "$candidate_name" =~ ^MacOSX([0-9]+) ]]; then
      candidate_major="${BASH_REMATCH[1]}"
      if (( candidate_major < 27 )); then
        export SDKROOT="$candidate"
        export AUDIOROUTER_SDK_FALLBACK=1
        return
      fi
    fi
  done < <(
    find "$developer_dir/SDKs" -maxdepth 1 -type d -name 'MacOSX*.sdk' -print 2>/dev/null \
      | sort -r
  )
}

audiorouter_configure_macos_sdk
