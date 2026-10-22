#!/bin/bash
# Add a Mac release to the Sparkle appcasts the app updates itself from (App/MacUpdater.swift):
#   website/public/appcast/macos-{arm64,x86_64}.xml, one per package (an appcast entry has one download).
#   Scripts/make-appcast.sh <version> [--key <private EdDSA key file>]
# Run after Scripts/package-mac-release.sh. It signs the DMGs, delta updates and appcasts with the EdDSA key
# (default ~/.sparkle/yingxia_ed25519.key, mode 600, never in git; SUPublicEDKey in project.yml is its public half).
# Deltas from the last releases are made from their DMGs, kept in build/appcast/<arch>/ between releases.
# They are written next to the DMGs as Yingxia<build>-<old build>-<arch>.delta: upload them to yingxia/<version>/
# with the DMGs, then deploy the website, which publishes the appcasts along with releases.json.
set -euo pipefail
cd "$(dirname "$0")/.."

SPARKLE_VERSION=2.10.0 # the Sparkle package version in project.yml
VERSION=${1:?usage: Scripts/make-appcast.sh <version> [--key <file>]}; shift
KEY=~/.sparkle/yingxia_ed25519.key
while [ $# -gt 0 ]; do
  case "$1" in
    --key) KEY="$2"; shift 2 ;;
    *) echo "unknown option $1" >&2; exit 2 ;;
  esac
done
test -f "$KEY" || { echo "missing EdDSA key $KEY" >&2; exit 1; }

TOOLS=build/sparkle-$SPARKLE_VERSION/bin
if [ ! -x "$TOOLS/generate_appcast" ]; then
  mkdir -p "build/sparkle-$SPARKLE_VERSION"
  curl -fsSL "https://github.com/sparkle-project/Sparkle/releases/download/$SPARKLE_VERSION/Sparkle-$SPARKLE_VERSION.tar.xz" \
    | tar -xJ -C "build/sparkle-$SPARKLE_VERSION"
fi

OUT=build/release-mac/$VERSION
PREFIX=https://download.getmegaportal.com/yingxia/$VERSION/
for ARCH in arm64 x86_64; do
  DMG="$OUT/Yingxia-$VERSION-macos-$ARCH.dmg"
  FEED=website/public/appcast/macos-$ARCH.xml
  WORK=build/appcast/$ARCH
  test -f "$DMG" || { echo "missing $DMG" >&2; exit 1; }
  mkdir -p "$WORK"
  cp "$FEED" "$WORK/appcast.xml"
  cp "$DMG" "$WORK/"
  "$TOOLS/generate_appcast" --ed-key-file "$KEY" --download-url-prefix "$PREFIX" --maximum-versions 3 \
    --maximum-deltas 3 -o "$WORK/appcast.xml" "$WORK"
  # generate_appcast points every DMG it still has at this release's folder: send each back to its own version's.
  # Both packages get deltas named Yingxia<build>-<old build>.delta; give each its architecture so they can share
  # the release folder. Then sign the appcast again.
  sed -i '' -E -e "s#${PREFIX//./\\.}(Yingxia-([0-9.]+)-macos-$ARCH\\.dmg)#${PREFIX%/$VERSION/}/\\2/\\1#g" \
    -e "s#(${PREFIX//./\\.}Yingxia[0-9]+-[0-9]+)\\.delta\"#\\1-$ARCH.delta\"#g" "$WORK/appcast.xml"
  "$TOOLS/sign_update" --ed-key-file "$KEY" "$WORK/appcast.xml" >/dev/null
  "$TOOLS/sign_update" --verify --ed-key-file "$KEY" "$WORK/appcast.xml"
  { grep -oE "${PREFIX//./\\.}Yingxia[0-9]+-[0-9]+-$ARCH\\.delta" "$WORK/appcast.xml" || true; } | while read -r url; do
    name=$(basename "$url"); cp "$WORK/${name%-$ARCH.delta}.delta" "$OUT/$name"
  done
  cp "$WORK/appcast.xml" "$FEED"
  echo "$ARCH: $(grep -c '<item>' "$FEED") releases in $FEED"
done
ls -lh "$OUT"/*.delta 2>/dev/null || echo "no deltas (no earlier Sparkle release in build/appcast)"
