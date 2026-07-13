#!/bin/bash
# Builds Riffle.app into ./dist
set -euo pipefail
cd "$(dirname "$0")"

echo "==> Compiling (release)…"
swift build -c release

APP="dist/Riffle.app"
echo "==> Assembling ${APP}…"
rm -rf "${APP}"
mkdir -p "${APP}/Contents/MacOS" "${APP}/Contents/Resources"
cp .build/release/Riffle "${APP}/Contents/MacOS/Riffle"
cp Resources/Info.plist "${APP}/Contents/Info.plist"
cp Resources/Riffle.icns "${APP}/Contents/Resources/Riffle.icns"

echo "==> Code signing (ad-hoc)…"
codesign --force --sign - "${APP}"

# Zip the bundle so it can be attached to a GitHub release as the asset the
# in-app updater downloads. --keepParent keeps "Riffle.app" as the top entry.
VERSION="$(/usr/libexec/PlistBuddy -c 'Print CFBundleShortVersionString' "${APP}/Contents/Info.plist")"
ZIP="dist/Riffle-${VERSION}.zip"
echo "==> Zipping ${ZIP}…"
rm -f "${ZIP}"
ditto -c -k --keepParent "${APP}" "${ZIP}"

echo "==> Done: ${APP}"
echo "==> Release asset: ${ZIP}"
