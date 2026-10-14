#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

VERSION="${VERSION:-1.0.0}"
BUILD="${BUILD:-1}"
# Assembled and signed outside the project: iCloud Drive (e.g. a Documents
# folder) tags files with attributes that codesign refuses. INSTALL_DIR is
# where the finished app goes.
STAGE="$(mktemp -d)"
APP="$STAGE/Pastely.app"
INSTALL_DIR="${INSTALL_DIR:-/Applications}"

echo "==> Building universal release binary (arm64 + x86_64)"
swift build -c release --arch arm64 --arch x86_64

BIN="$(swift build -c release --arch arm64 --arch x86_64 --show-bin-path)/Pastely"
echo "    binary: $BIN"

echo "==> Generating icon"
bash scripts/make_icon.sh >/dev/null

echo "==> Assembling $APP"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/Pastely"
cp packaging/Pastely.icns "$APP/Contents/Resources/Pastely.icns"

sed -e "s/__VERSION__/$VERSION/" -e "s/__BUILD__/$BUILD/" \
    packaging/Info.plist > "$APP/Contents/Info.plist"

printf 'APPL????' > "$APP/Contents/PkgInfo"

# Sign with the "Pastely Developer" certificate when the keychain has one
# (see README). macOS then recognises every rebuild as the same app and keeps
# its Accessibility, Full Disk Access and folder permissions. Without it the
# bundle is signed ad hoc, and those permissions must be granted again after
# each build.
#
# SIGN_IDENTITY may also be a prefix such as "Developer ID Application";
# scripts/release.sh uses that, with HARDENED_RUNTIME=1, for builds that
# Apple notarizes and other Macs open without a warning.
IDENTITY="${SIGN_IDENTITY:-Pastely Developer}"
SIGN_FLAGS=()
if [[ "${HARDENED_RUNTIME:-0}" == 1 ]]; then
  SIGN_FLAGS=(--options runtime --timestamp)
fi
if security find-identity -p codesigning 2>/dev/null | grep -q "\"$IDENTITY"; then
  echo "==> Signing $APP with \"$IDENTITY\""
  /usr/bin/codesign --force --sign "$IDENTITY" ${SIGN_FLAGS[@]+"${SIGN_FLAGS[@]}"} \
    --identifier ch.claudeflaig.pastely "$APP"
elif [[ "${REQUIRE_IDENTITY:-0}" == 1 ]]; then
  echo "error: no \"$IDENTITY\" certificate in the keychain" >&2
  exit 1
else
  echo "==> Signing $APP ad hoc (no \"$IDENTITY\" certificate found)"
  /usr/bin/codesign --force --sign - --identifier ch.claudeflaig.pastely \
    -r='designated => identifier "ch.claudeflaig.pastely"' "$APP"
fi

echo "==> Installing to $INSTALL_DIR/Pastely.app"
rm -rf "$INSTALL_DIR/Pastely.app"
ditto "$APP" "$INSTALL_DIR/Pastely.app"
rm -rf "$STAGE"
APP="$INSTALL_DIR/Pastely.app"

echo "==> Built $APP"
/usr/bin/codesign --verify "$APP" && echo "    signature ok"
/usr/bin/file "$APP/Contents/MacOS/Pastely"
echo "    version $VERSION ($BUILD)"
