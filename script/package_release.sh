#!/usr/bin/env bash
set -euo pipefail

APP_NAME="AudioRouter"
BUNDLE_ID="com.local.AudioRouter"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIST_DIR="$ROOT_DIR/dist"
APP_BUNDLE="$DIST_DIR/$APP_NAME.app"
DMG_PATH="$DIST_DIR/$APP_NAME-macOS.dmg"
LEGACY_ZIP_PATH="$DIST_DIR/$APP_NAME-macOS.zip"
STAGING_DIR="$DIST_DIR/dmg-staging"

cd "$ROOT_DIR"

./script/build_and_run.sh --bundle >/dev/null

SIGN_IDENTITY="${DEVELOPER_ID_APPLICATION:-}"
if [[ -n "$SIGN_IDENTITY" ]]; then
  echo "Signing app with Developer ID Application identity: $SIGN_IDENTITY"
  /usr/bin/codesign --force --deep --options runtime --timestamp --sign "$SIGN_IDENTITY" "$APP_BUNDLE"
else
  echo "DEVELOPER_ID_APPLICATION is not set; keeping ad-hoc app signature."
fi

/usr/bin/codesign --verify --deep --strict --verbose=2 "$APP_BUNDLE"

rm -f "$LEGACY_ZIP_PATH" "$DMG_PATH"

rm -rf "$STAGING_DIR"
mkdir -p "$STAGING_DIR"
cp -R "$APP_BUNDLE" "$STAGING_DIR/"
cp "$ROOT_DIR/LICENSE" "$STAGING_DIR/LICENSE"
cp "$ROOT_DIR/NOTICE" "$STAGING_DIR/NOTICE"
ln -s /Applications "$STAGING_DIR/Applications"

/usr/bin/hdiutil create \
  -volname "$APP_NAME" \
  -srcfolder "$STAGING_DIR" \
  -ov \
  -format UDZO \
  "$DMG_PATH" >/dev/null

rm -rf "$STAGING_DIR"

if [[ -n "${DEVELOPER_ID_INSTALLER:-}" ]]; then
  echo "Signing DMG with Developer ID Installer identity: $DEVELOPER_ID_INSTALLER"
  /usr/bin/codesign --force --timestamp --sign "$DEVELOPER_ID_INSTALLER" "$DMG_PATH"
fi

if [[ "${NOTARIZE:-0}" == "1" ]]; then
  if [[ -n "${NOTARYTOOL_PROFILE:-}" ]]; then
    echo "Submitting DMG for notarization with keychain profile: $NOTARYTOOL_PROFILE"
    /usr/bin/xcrun notarytool submit "$DMG_PATH" --keychain-profile "$NOTARYTOOL_PROFILE" --wait
    /usr/bin/xcrun stapler staple "$DMG_PATH"
  elif [[ -n "${APPLE_ID:-}" && -n "${APPLE_TEAM_ID:-}" && -n "${APPLE_APP_PASSWORD:-}" ]]; then
    echo "Submitting DMG for notarization with Apple ID credentials."
    /usr/bin/xcrun notarytool submit "$DMG_PATH" \
      --apple-id "$APPLE_ID" \
      --team-id "$APPLE_TEAM_ID" \
      --password "$APPLE_APP_PASSWORD" \
      --wait
    /usr/bin/xcrun stapler staple "$DMG_PATH"
  else
    echo "NOTARIZE=1 was set, but no notary credentials were provided." >&2
    echo "Set NOTARYTOOL_PROFILE or APPLE_ID, APPLE_TEAM_ID, and APPLE_APP_PASSWORD." >&2
    exit 2
  fi
else
  echo "Skipping notarization. Set NOTARIZE=1 with notary credentials to notarize."
fi

echo "$DMG_PATH"
