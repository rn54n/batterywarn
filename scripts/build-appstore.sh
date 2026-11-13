#!/bin/bash
# Builds the sandboxed Mac App Store variant from project.yml.
#
#   ./scripts/build-appstore.sh            build/BatteryWarn.xcarchive
#   ./scripts/build-appstore.sh --upload   also upload it to App Store Connect (TestFlight)
#
# Needs XcodeGen. Signing and upload use an App Store Connect API key from the environment:
# ASC_KEY_ID, ASC_ISSUER and optionally ASC_KEY (default ~/.private_keys/AuthKey_<ASC_KEY_ID>.p8).
set -euo pipefail

cd "$(dirname "$0")/.."

: "${ASC_KEY_ID:?Set ASC_KEY_ID and ASC_ISSUER}" "${ASC_ISSUER:?Set ASC_KEY_ID and ASC_ISSUER}"
AUTH=(
    -allowProvisioningUpdates
    -authenticationKeyPath "${ASC_KEY:-$HOME/.private_keys/AuthKey_$ASC_KEY_ID.p8}"
    -authenticationKeyID "$ASC_KEY_ID"
    -authenticationKeyIssuerID "$ASC_ISSUER"
)
ARCHIVE="build/BatteryWarn.xcarchive"

xcodegen generate --quiet

rm -rf "$ARCHIVE"
xcodebuild -project BatteryWarn.xcodeproj -scheme BatteryWarn -configuration Release \
    -derivedDataPath build/DerivedData -archivePath "$ARCHIVE" "${AUTH[@]}" archive

echo "Built $ARCHIVE"

if [[ "${1:-}" == "--upload" ]]; then
    # The app record has to exist in App Store Connect before the first upload
    rm -rf build/appstore
    xcodebuild -exportArchive -archivePath "$ARCHIVE" \
        -exportOptionsPlist scripts/appstore-export.plist \
        -exportPath build/appstore "${AUTH[@]}"

    echo "Uploaded to App Store Connect"
fi
