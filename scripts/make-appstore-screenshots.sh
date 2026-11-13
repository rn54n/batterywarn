#!/bin/bash
# Regenerates the Mac App Store screenshots from the real views with fixed sample data.
set -euo pipefail

cd "$(dirname "$0")/.."

APPSTORE_SCREENSHOT_DIR="$PWD/docs/store/screenshots" swift test --filter AppStoreScreenshotTests

# App Store Connect only takes exact sizes, and no alpha channel
for shot in docs/store/screenshots/*.jpg; do
    width="$(sips -g pixelWidth "$shot" | awk '/pixelWidth/ { print $2 }')"
    height="$(sips -g pixelHeight "$shot" | awk '/pixelHeight/ { print $2 }')"
    alpha="$(sips -g hasAlpha "$shot" | awk '/hasAlpha/ { print $2 }')"
    if [[ "$width" != 2880 || "$height" != 1800 || "$alpha" != no ]]; then
        echo "$shot is ${width}x${height} (alpha: $alpha), expected 2880x1800 without alpha" >&2
        exit 1
    fi
done

echo "Wrote docs/store/screenshots/"
