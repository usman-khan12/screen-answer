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
# across rebuilds (the signature is tied to that certificate). Otherwise use a plain ad-hoc
# signature, which matches only this exact build, so permissions may need re-granting after a rebuild.
IDENTITY=$(security find-identity -v -p codesigning | awk '/ScreenAnswer Local Signing/{print $2; exit}')
if [ -n "$IDENTITY" ]; then
  codesign --force --sign "$IDENTITY" "$APP"
else
  codesign --force --sign - "$APP"
fi
echo "Built $APP"
