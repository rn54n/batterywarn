#!/bin/bash
# Regenerates the README screenshots from the real views with fixed sample data.
set -euo pipefail

cd "$(dirname "$0")/.."

SCREENSHOT_DIR="$PWD/screenshots" swift test --filter ScreenshotTests

# Retina renders of the full-screen overlay are large: cap them at 1920 px wide
# and store them as JPEG (the gradient compresses badly as PNG)
for shot in screenshots/overlay-*.png; do
    width="$(sips -g pixelWidth "$shot" | awk '/pixelWidth/ { print $2 }')"
    if (( width > 1920 )); then
        sips --resampleWidth 1920 "$shot" > /dev/null
    fi
    sips -s format jpeg -s formatOptions 88 "$shot" --out "${shot%.png}.jpg" > /dev/null
    rm "$shot"
done

echo "Wrote screenshots/"
