#!/bin/bash
# Builds Riffle and installs it to /Applications, then launches it.
set -euo pipefail
cd "$(dirname "$0")"

./build.sh

BUNDLE_ID="com.amin.riffle"

echo "==> Stopping any running instance…"
pkill -x Riffle 2>/dev/null || true

# The ad-hoc signature changes on every build, so macOS treats the reinstalled
# app as a different binary while the old Accessibility grant lingers — the
# toggle looks "on" but no longer applies, and hotkeys silently break. Reset the
# TCC entry so the stale grant is dropped and the app re-prompts cleanly below.
echo "==> Resetting stale Accessibility permission…"
tccutil reset Accessibility "${BUNDLE_ID}" 2>/dev/null || true

echo "==> Installing to /Applications…"
rm -rf /Applications/Riffle.app
cp -R dist/Riffle.app /Applications/

echo "==> Launching…"
open /Applications/Riffle.app

cat <<'EOF'

Installed! One thing left to do:

  The old Accessibility permission was cleared (it goes stale on reinstall),
  so Riffle needs it granted again. When macOS prompts, click
  "Open System Settings", or go there manually:

    System Settings > Privacy & Security > Accessibility

  and enable "Riffle". The app picks up the grant automatically within a
  couple of seconds.

Then hold Cmd and press Tab (active screen) or ` (all screens).
EOF
