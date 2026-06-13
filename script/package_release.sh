#!/usr/bin/env bash
set -euo pipefail

APP_NAME="AudioRouter"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIST_DIR="$ROOT_DIR/dist"
APP_BUNDLE="$DIST_DIR/$APP_NAME.app"
STAGING_DIR="$DIST_DIR/$APP_NAME-macOS"
MANUAL_SOURCE="$ROOT_DIR/DOWNLOAD_AND_USE.md"
MANUAL_NAME="DOWNLOAD_AND_USE.md"
USER_MANUAL_PDF_SOURCE="$ROOT_DIR/docs/assets/AudioRouter-User-Manual.pdf"
USER_MANUAL_PDF_NAME="AudioRouter-User-Manual.pdf"
DRIVER_MANUAL_SOURCE="$ROOT_DIR/DRIVER_INSTALL.md"
DRIVER_MANUAL_NAME="DRIVER_INSTALL.md"
DRIVER_BUNDLE="$DIST_DIR/AudioRouterHAL.driver"
PUBLIC_ZIP_PATH="$DIST_DIR/$APP_NAME-macOS.zip"
LOCAL_ZIP_PATH="$DIST_DIR/$APP_NAME-macOS-local-untrusted.zip"
LEGACY_DMG_PATH="$DIST_DIR/$APP_NAME-macOS.dmg"
LEGACY_LOCAL_DMG_PATH="$DIST_DIR/$APP_NAME-macOS-local-untrusted.dmg"
LOCAL_TEST_ZIP="${LOCAL_TEST_ZIP:-${LOCAL_TEST_DMG:-0}}"
NOTARIZE="${NOTARIZE:-1}"
ALLOW_UNNOTARIZED_PUBLIC_ZIP="${ALLOW_UNNOTARIZED_PUBLIC_ZIP:-0}"

if [[ "$LOCAL_TEST_ZIP" == "1" ]]; then
  ZIP_PATH="$LOCAL_ZIP_PATH"
else
  ZIP_PATH="$PUBLIC_ZIP_PATH"
fi

cd "$ROOT_DIR"

SIGN_IDENTITY="${DEVELOPER_ID_APPLICATION:-}"
if [[ "$LOCAL_TEST_ZIP" != "1" && "$ALLOW_UNNOTARIZED_PUBLIC_ZIP" != "1" && -z "$SIGN_IDENTITY" ]]; then
  echo "Refusing to create $PUBLIC_ZIP_PATH without Developer ID signing." >&2
  echo "Set DEVELOPER_ID_APPLICATION=\"Developer ID Application: Your Name (TEAMID)\"." >&2
  echo "To intentionally publish an unnotarized ZIP with first-launch instructions, run ALLOW_UNNOTARIZED_PUBLIC_ZIP=1 ./script/package_release.sh." >&2
  echo "For a local-only unsafe test archive, run LOCAL_TEST_ZIP=1 ./script/package_release.sh." >&2
  exit 2
fi

if [[ "$LOCAL_TEST_ZIP" != "1" && "$ALLOW_UNNOTARIZED_PUBLIC_ZIP" != "1" && "$NOTARIZE" != "1" ]]; then
  echo "Refusing to create $PUBLIC_ZIP_PATH without notarization." >&2
  echo "Public downloads must be notarized so Gatekeeper can open them normally." >&2
  echo "Set NOTARIZE=1 plus NOTARYTOOL_PROFILE, or use LOCAL_TEST_ZIP=1 for local-only testing." >&2
  exit 2
fi

if [[ "$LOCAL_TEST_ZIP" != "1"
      && "$ALLOW_UNNOTARIZED_PUBLIC_ZIP" != "1"
      && -z "${NOTARYTOOL_PROFILE:-}"
      && ( -z "${APPLE_ID:-}" || -z "${APPLE_TEAM_ID:-}" || -z "${APPLE_APP_PASSWORD:-}" ) ]]; then
  echo "Refusing to create $PUBLIC_ZIP_PATH without complete notary credentials." >&2
  echo "Set NOTARYTOOL_PROFILE, or APPLE_ID + APPLE_TEAM_ID + APPLE_APP_PASSWORD." >&2
  exit 2
fi

if [[ -n "${DEVELOPER_ID_INSTALLER:-}" ]]; then
  echo "Note: DEVELOPER_ID_INSTALLER is for .pkg installers. ZIP releases use DEVELOPER_ID_APPLICATION for the app."
fi

./script/build_and_run.sh --bundle >/dev/null
./script/build_hal_driver.sh >/dev/null

if [[ -n "$SIGN_IDENTITY" ]]; then
  echo "Signing app with Developer ID Application identity: $SIGN_IDENTITY"
  /usr/bin/codesign --force --deep --options runtime --timestamp --sign "$SIGN_IDENTITY" "$APP_BUNDLE"
elif [[ "$ALLOW_UNNOTARIZED_PUBLIC_ZIP" == "1" && "$LOCAL_TEST_ZIP" != "1" ]]; then
  echo "Creating explicitly unnotarized public ZIP."
  echo "WARNING: Users must use the first-launch Control-click Open flow documented in DOWNLOAD_AND_USE.md."
else
  echo "Creating local-only ad-hoc test archive."
  echo "WARNING: $LOCAL_ZIP_PATH is intentionally untrusted and must not be uploaded as a public release asset."
fi
/usr/bin/codesign --verify --deep --strict --verbose=2 "$APP_BUNDLE"

rm -f "$PUBLIC_ZIP_PATH" "$LOCAL_ZIP_PATH" "$LEGACY_DMG_PATH" "$LEGACY_LOCAL_DMG_PATH"

create_zip() {
  local output_path="$1"
  rm -f "$output_path"
  rm -rf "$STAGING_DIR"
  mkdir -p "$STAGING_DIR"
  /usr/bin/ditto "$APP_BUNDLE" "$STAGING_DIR/$APP_NAME.app"
  /usr/bin/ditto "$DRIVER_BUNDLE" "$STAGING_DIR/AudioRouterHAL.driver"
  cp "$MANUAL_SOURCE" "$STAGING_DIR/$MANUAL_NAME"
  cp "$USER_MANUAL_PDF_SOURCE" "$STAGING_DIR/$USER_MANUAL_PDF_NAME"
  cp "$DRIVER_MANUAL_SOURCE" "$STAGING_DIR/$DRIVER_MANUAL_NAME"
  mkdir -p "$STAGING_DIR/script"
  cp "$ROOT_DIR/script/install_hal_driver.sh" "$STAGING_DIR/script/install_hal_driver.sh"
  cp "$ROOT_DIR/script/uninstall_hal_driver.sh" "$STAGING_DIR/script/uninstall_hal_driver.sh"
  chmod +x "$STAGING_DIR/script/install_hal_driver.sh" "$STAGING_DIR/script/uninstall_hal_driver.sh"
  (cd "$DIST_DIR" && /usr/bin/ditto -c -k --sequesterRsrc --keepParent "$APP_NAME-macOS" "$output_path")
  /usr/bin/unzip -tq "$output_path" >/dev/null
}

create_zip "$ZIP_PATH"

if [[ "$NOTARIZE" == "1" && "$LOCAL_TEST_ZIP" != "1" && "$ALLOW_UNNOTARIZED_PUBLIC_ZIP" != "1" ]]; then
  if [[ -n "${NOTARYTOOL_PROFILE:-}" ]]; then
    echo "Submitting ZIP for notarization with keychain profile: $NOTARYTOOL_PROFILE"
    /usr/bin/xcrun notarytool submit "$ZIP_PATH" --keychain-profile "$NOTARYTOOL_PROFILE" --wait
  else
    echo "Submitting ZIP for notarization with Apple ID credentials."
    /usr/bin/xcrun notarytool submit "$ZIP_PATH" \
      --apple-id "$APPLE_ID" \
      --team-id "$APPLE_TEAM_ID" \
      --password "$APPLE_APP_PASSWORD" \
      --wait
  fi

  /usr/bin/xcrun stapler staple "$APP_BUNDLE"
  /usr/bin/xcrun stapler validate "$APP_BUNDLE"
  /usr/sbin/spctl -a -t exec -vv "$APP_BUNDLE"

  # Recreate the public ZIP after stapling so the archived app contains the ticket.
  create_zip "$ZIP_PATH"
else
  if [[ "$ALLOW_UNNOTARIZED_PUBLIC_ZIP" == "1" && "$LOCAL_TEST_ZIP" != "1" ]]; then
    echo "Skipping notarization by explicit request."
    echo "WARNING: $ZIP_PATH can show Apple verification warnings until first launched with Control-click Open."
  else
    echo "Skipping notarization for local-only test ZIP."
    echo "WARNING: $ZIP_PATH can show 'cannot be opened' or 'not safe' after download and must not be published."
  fi
fi

echo "$ZIP_PATH"
