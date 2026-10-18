#!/bin/bash
# One-step installer: builds ScreenAnswer, puts it in Applications, and opens it.
set -euo pipefail
cd "$(dirname "$0")"

if ! xcrun --find swiftc >/dev/null 2>&1; then
  echo "Apple's Command Line Tools are needed to build the app."
  echo "A window will pop up — click Install, wait for it to finish, then run ./install.sh again."
  xcode-select --install || true
  exit 1
fi

# One-time: a local signing certificate so permissions survive updates (asks for your Mac password once).
./setup-signing.sh || echo "Continuing without the signing certificate."

echo "Building ScreenAnswer…"
./build.sh

# Use /Applications if we can write to it, otherwise ~/Applications.
DEST="/Applications"
[ -w "$DEST" ] || { DEST="$HOME/Applications"; mkdir -p "$DEST"; }

pkill -x ScreenAnswer 2>/dev/null || true
rm -rf "$DEST/ScreenAnswer.app"
cp -R build/ScreenAnswer.app "$DEST/"
open "$DEST/ScreenAnswer.app"

cat <<MSG

✅ Installed to $DEST/ScreenAnswer.app and launched.

Next:
  1. Look for the new icon in the menu bar (top right) → Settings… to paste your OpenAI API key.
  2. When macOS asks, allow Screen Recording for ScreenAnswer
     (System Settings → Privacy & Security → Screen Recording), then quit and reopen it from the menu bar icon.
  3. Press ⌥⇧Space (Option+Shift+Space) with a question on screen.
MSG
