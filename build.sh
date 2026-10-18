#!/bin/bash
# Builds ScreenAnswer.app into ./build
set -euo pipefail
cd "$(dirname "$0")"

APP="build/ScreenAnswer.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
cp Info.plist "$APP/Contents/Info.plist"

swiftc -O -swift-version 5 -parse-as-library \
  -target "$(uname -m)-apple-macos14.0" \
  Sources/*.swift \
  -o "$APP/Contents/MacOS/ScreenAnswer"

# Sign with the local certificate from setup-signing.sh if it exists, so macOS keeps permissions
# across rebuilds. Otherwise fall back to an ad-hoc signature with a fixed identity.
IDENTITY=$(security find-identity -v -p codesigning | awk '/ScreenAnswer Local Signing/{print $2; exit}')
if [ -n "$IDENTITY" ]; then
  codesign --force --sign "$IDENTITY" "$APP"
else
  codesign --force --sign - -r='designated => identifier "local.screenanswer.app"' "$APP"
fi
echo "Built $APP"
