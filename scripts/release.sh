#!/usr/bin/env bash
# Builds a Pastely.dmg that other Macs open without a Gatekeeper warning:
# signed with a Developer ID certificate and the hardened runtime, notarized
# by Apple and stapled. See "An Freunde weitergeben" in the README for the
# one-time setup (certificate and notarytool profile).
set -euo pipefail
cd "$(dirname "$0")/.."

VERSION="${VERSION:-1.0.0}"
BUILD="${BUILD:-1}"
IDENTITY="${SIGN_IDENTITY:-Developer ID Application}"
# Name of the keychain profile saved with `xcrun notarytool store-credentials`.
PROFILE="${NOTARY_PROFILE:-pastely-notary}"
OUT="packaging/Pastely-$VERSION.dmg"

# Assembled and signed outside the project, as in build_app.sh: iCloud Drive
# tags files with attributes that codesign refuses.
STAGE="$(mktemp -d)"
trap 'rm -rf "$STAGE"' EXIT

INSTALL_DIR="$STAGE/root" SIGN_IDENTITY="$IDENTITY" HARDENED_RUNTIME=1 \
  REQUIRE_IDENTITY=1 VERSION="$VERSION" BUILD="$BUILD" \
  bash scripts/build_app.sh
APP="$STAGE/root/Pastely.app"
/usr/bin/codesign --verify --strict --deep "$APP"

echo "==> Making the disk image"
ln -s /Applications "$STAGE/root/Applications"
DMG="$STAGE/Pastely.dmg"
hdiutil create -quiet -volname "Pastely" -srcfolder "$STAGE/root" \
  -fs HFS+ -format UDZO "$DMG"
/usr/bin/codesign --force --sign "$IDENTITY" --timestamp "$DMG"

echo "==> Notarizing (usually a few minutes)"
xcrun notarytool submit "$DMG" --keychain-profile "$PROFILE" --wait
xcrun stapler staple "$DMG"

echo "==> Checking"
spctl -a -vvv -t open --context context:primary-signature "$DMG"
hdiutil attach -quiet -nobrowse -readonly -mountpoint "$STAGE/mnt" "$DMG"
spctl -a -vvv -t exec "$STAGE/mnt/Pastely.app"
hdiutil detach -quiet "$STAGE/mnt"

cp "$DMG" "$OUT"
echo "==> Ready to share: $OUT"
