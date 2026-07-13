#!/bin/bash
# Cuts a new Riffle release: bumps the version, builds the signed .zip, tags the
# commit, and publishes a GitHub release with the .zip attached (so the in-app
# updater can auto-install it). The new version bumps the minor component and
# resets the patch to 0, e.g. 1.0.1 -> 1.1.0.
set -euo pipefail
cd "$(dirname "$0")"

PLIST="Resources/Info.plist"
REPO="aminaryan80/riffle"

command -v gh >/dev/null 2>&1 || {
  echo "error: GitHub CLI (gh) is required. Install with 'brew install gh' and run 'gh auth login'." >&2
  exit 1
}

# Refuse to release with a dirty tree — the version bump must be the only change.
if [[ -n "$(git status --porcelain)" ]]; then
  echo "error: working tree is dirty. Commit or stash changes before releasing." >&2
  exit 1
fi

CURRENT="$(/usr/libexec/PlistBuddy -c 'Print CFBundleShortVersionString' "${PLIST}")"
IFS='.' read -r MAJOR MINOR _ <<< "${CURRENT}"
NEW="${MAJOR}.$((MINOR + 1)).0"
TAG="v${NEW}"
echo "==> Bumping ${CURRENT} -> ${NEW}"

/usr/libexec/PlistBuddy -c "Set CFBundleVersion ${NEW}" "${PLIST}"
/usr/libexec/PlistBuddy -c "Set CFBundleShortVersionString ${NEW}" "${PLIST}"

./build.sh
ZIP="dist/Riffle-${NEW}.zip"

echo "==> Committing and tagging ${TAG}…"
git add "${PLIST}"
git commit -m "Release ${NEW}"
git tag "${TAG}"

echo "==> Pushing…"
git push origin HEAD
git push origin "${TAG}"

echo "==> Creating GitHub release ${TAG}…"
gh release create "${TAG}" "${ZIP}" \
  --repo "${REPO}" \
  --title "${NEW}" \
  --generate-notes

# The release now lives on GitHub, so the local build artifacts are redundant.
echo "==> Cleaning up dist…"
rm -rf dist

echo "==> Released ${NEW}"
