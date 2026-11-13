#!/bin/bash
# Builds build/BatteryWarn.app from the Swift package.
#
#   ./scripts/build-app.sh          build/BatteryWarn.app
#   ./scripts/build-app.sh --dmg    also build/BatteryWarn.dmg
set -euo pipefail

cd "$(dirname "$0")/.."

APP="build/BatteryWarn.app"

swift build -c release
BIN_DIR="$(swift build -c release --show-bin-path)"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

cp "$BIN_DIR/BatteryWarn" "$APP/Contents/MacOS/BatteryWarn"
cp BatteryWarn/Info.plist "$APP/Contents/Info.plist"
cp AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"
cp -R "$BIN_DIR/BatteryWarn_BatteryWarn.bundle" "$APP/Contents/Resources/"
printf 'APPL????' > "$APP/Contents/PkgInfo"

# Ad-hoc signature: enough to run on this Mac. Re-sign with a Developer ID
# and notarize before handing the app to other people.
codesign --force --sign - --entitlements BatteryWarn/BatteryWarn.entitlements "$APP"

echo "Built $APP"

if [[ "${1:-}" == "--dmg" ]]; then
    DMG="build/BatteryWarn.dmg"
    STAGING="$(mktemp -d)"

    cp -R "$APP" "$STAGING/"
    ln -s /Applications "$STAGING/Applications"

    rm -f "$DMG"
    hdiutil create -volname "BatteryWarn" -srcfolder "$STAGING" -ov -format UDZO "$DMG" > /dev/null
    rm -rf "$STAGING"

    echo "Built $DMG"
fi
