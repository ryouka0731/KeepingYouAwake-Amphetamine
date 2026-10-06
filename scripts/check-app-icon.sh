#!/usr/bin/env bash
# Fails if a built KeepingYouAwake.app ships no icon.
#
#   scripts/check-app-icon.sh path/to/KeepingYouAwake.app
#
# AppIcon.icon (Icon Composer) only compiles with Xcode 26, so builds made
# with older Xcode (release.yml uses Xcode 16) rely on the bundled
# AppIcon.icns referenced by CFBundleIconFile. Used by ci.yml (E2E) and
# release.yml so the check can't drift between them.
set -euo pipefail

APP="${1:?usage: $0 path/to/KeepingYouAwake.app}"
ICON_FILE="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIconFile' "$APP/Contents/Info.plist" 2>/dev/null || true)"
if [ "$ICON_FILE" != "AppIcon" ]; then
  echo "::error::Built app's Info.plist has CFBundleIconFile='$ICON_FILE' (expected 'AppIcon')"
  exit 1
fi
if [ ! -s "$APP/Contents/Resources/AppIcon.icns" ]; then
  echo "::error::Built app has no Contents/Resources/AppIcon.icns (missing or empty)"
  exit 1
fi
echo "PASS: app bundle ships AppIcon.icns"
