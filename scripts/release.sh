#!/usr/bin/env bash
# Builds packaging/Pastely-<version>.dmg to share with other Macs.
#
# With a "Developer ID Application" certificate and a notarytool profile in
# the keychain, the app is signed with the hardened runtime, notarized by
# Apple and stapled, and opens anywhere without a warning. Without them it is
# signed with "Pastely Developer" as in build_app.sh; other Macs then ask
# once for System Settings → Privacy & Security → Open Anyway. That stable
# signature also lets them keep the Accessibility permission across updates.
set -euo pipefail
cd "$(dirname "$0")/.."

VERSION="${VERSION:-1.0.0}"
BUILD="${BUILD:-1}"
# Name of the keychain profile saved with `xcrun notarytool store-credentials`.
PROFILE="${NOTARY_PROFILE:-pastely-notary}"
OUT="packaging/Pastely-$VERSION.dmg"

NOTARIZE=0
if security find-identity -p codesigning -v 2>/dev/null | grep -q '"Developer ID Application' &&
   xcrun notarytool history --keychain-profile "$PROFILE" >/dev/null 2>&1; then
  NOTARIZE=1
  IDENTITY="Developer ID Application"
else
  IDENTITY="Pastely Developer"
fi

# Assembled and signed outside the project, as in build_app.sh: iCloud Drive
# tags files with attributes that codesign refuses.
STAGE="$(mktemp -d)"
trap 'rm -rf "$STAGE"' EXIT

INSTALL_DIR="$STAGE/root" SIGN_IDENTITY="$IDENTITY" HARDENED_RUNTIME="$NOTARIZE" \
  REQUIRE_IDENTITY=1 VERSION="$VERSION" BUILD="$BUILD" \
  bash scripts/build_app.sh
APP="$STAGE/root/Pastely.app"
/usr/bin/codesign --verify --strict --deep "$APP"

echo "==> Making the disk image"
ln -s /Applications "$STAGE/root/Applications"
DMG="$STAGE/Pastely.dmg"
hdiutil create -quiet -volname "Pastely" -srcfolder "$STAGE/root" \
  -fs HFS+ -format UDZO "$DMG"

if [[ "$NOTARIZE" == 1 ]]; then
  /usr/bin/codesign --force --sign "$IDENTITY" --timestamp "$DMG"
  echo "==> Notarizing (usually a few minutes)"
  xcrun notarytool submit "$DMG" --keychain-profile "$PROFILE" --wait
  xcrun stapler staple "$DMG"
  spctl -a -vvv -t open --context context:primary-signature "$DMG"
else
  echo "==> Not notarized (no Developer ID certificate or \"$PROFILE\" profile)"
fi

cp "$DMG" "$OUT"
echo "==> Ready to share: $OUT"
