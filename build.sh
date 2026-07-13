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

echo "==> Done: ${APP}"
