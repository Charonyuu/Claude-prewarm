#!/bin/bash
# Installs the latest Claude Prewarm release into /Applications.
#
#   curl -fsSL https://raw.githubusercontent.com/Charonyuu/Claude-prewarm/main/install.sh | bash
set -euo pipefail

REPO="Charonyuu/Claude-prewarm"
APP_NAME="Claude Prewarm.app"
TMP="$(mktemp -d)"
MOUNT=""

cleanup() {
    [[ -n "$MOUNT" ]] && hdiutil detach "$MOUNT" -quiet 2>/dev/null || true
    rm -rf "$TMP"
}
trap cleanup EXIT

if [[ "$(uname -s)" != "Darwin" ]]; then
    echo "✗ Claude Prewarm is macOS only." >&2
    exit 1
fi

MAJOR="$(sw_vers -productVersion | cut -d. -f1)"
if (( MAJOR < 14 )); then
    echo "✗ Needs macOS 14 or later (you have $(sw_vers -productVersion))." >&2
    exit 1
fi

echo "→ Looking up the latest release…"
URL="$(curl -fsSL "https://api.github.com/repos/$REPO/releases/latest" \
    | grep -o '"browser_download_url"[^,]*\.dmg"' \
    | head -1 | cut -d'"' -f4)"
if [[ -z "$URL" ]]; then
    echo "✗ No dmg found in the latest release." >&2
    exit 1
fi

echo "→ Downloading…"
curl -fL --progress-bar "$URL" -o "$TMP/prewarm.dmg"

echo "→ Verifying Apple notarization…"
if ! spctl -a -t open --context context:primary-signature "$TMP/prewarm.dmg" >/dev/null 2>&1; then
    echo "✗ The download is not notarized by Apple. Stopping." >&2
    exit 1
fi

echo "→ Mounting…"
MOUNT="$(hdiutil attach "$TMP/prewarm.dmg" -nobrowse -readonly | grep -o '/Volumes/.*$' | head -1)"
if [[ -z "$MOUNT" || ! -d "$MOUNT/$APP_NAME" ]]; then
    echo "✗ Could not read the disk image." >&2
    exit 1
fi

echo "→ Installing to /Applications…"
pkill -f "ClaudePrewarm" 2>/dev/null || true
sleep 1
rm -rf "/Applications/$APP_NAME"
cp -R "$MOUNT/$APP_NAME" "/Applications/$APP_NAME"

echo "→ Launching…"
open "/Applications/$APP_NAME"

cat <<'DONE'

✓ Installed.

Look for the bolt in your menu bar. Open it, choose Settings…, and set the days
and time you start work. Claude Prewarm does the rest.

Needs Claude Code installed and signed in: https://docs.claude.com/en/docs/claude-code/setup
DONE
