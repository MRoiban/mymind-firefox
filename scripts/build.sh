#!/bin/sh
# Build the Firefox add-on from the official mymind Chrome extension.
#
#   scripts/build.sh                  # download the latest release from the Chrome Web Store
#   scripts/build.sh path/to/ext.crx  # use a downloaded .crx
#   scripts/build.sh path/to/dir      # use an unpacked Chrome build
#
# Produces:
#   upstream/chrome-<version>/        pristine Chrome build (kept for diffing releases)
#   firefox/                          Chrome build + Firefox manifest + patches/firefox.patch
#   dist/mymind-firefox-<version>.xpi installable add-on
set -eu
cd "$(dirname "$0")/.."

CHROME_ID=nmgcefdhjpjefhgcpocffdlibknajbmj
CRX_URL="https://clients2.google.com/service/update2/crx?response=redirect&prodversion=140.0&acceptformat=crx2,crx3&x=id%3D$CHROME_ID%26uc"

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

# 1. Get the Chrome build
src="${1:-}"
if [ -d "$src" ]; then
  cp -R "$src/." "$tmp/src"
else
  if [ -z "$src" ]; then
    echo "Downloading the latest mymind extension from the Chrome Web Store…"
    curl -fsSL -o "$tmp/ext.crx" "$CRX_URL"
    src="$tmp/ext.crx"
  fi
  mkdir "$tmp/src"
  # A .crx is a zip with an extra header; unzip warns about it and exits 1.
  unzip -q "$src" -d "$tmp/src" 2>/dev/null || true
fi
rm -rf "$tmp/src/_metadata"

if [ ! -f "$tmp/src/manifest.json" ]; then
  echo "error: no manifest.json found in $src" >&2
  exit 1
fi

version=$(python3 -I -c 'import json,sys;print(json.load(open(sys.argv[1],encoding="utf-8"))["version"])' "$tmp/src/manifest.json")
upstream="upstream/chrome-$version"

if [ ! -d "$upstream" ]; then
  mkdir -p upstream
  cp -R "$tmp/src" "$upstream"
fi
echo "Chrome build: $upstream"

# 2. Assemble the Firefox build
cp -R "$upstream" "$tmp/firefox"
python3 -I scripts/firefox-manifest.py "$upstream/manifest.json" > "$tmp/firefox/manifest.json"

if ! patch -s -p1 -N -d "$tmp/firefox" < patches/firefox.patch; then
  cat >&2 <<MSG

error: patches/firefox.patch does not apply cleanly to mymind $version.
The Chrome extension changed in a way that needs a manual port — see
"Updating to a new Chrome release" in the README.
MSG
  exit 1
fi
find "$tmp/firefox" \( -name '*.orig' -o -name '*.rej' \) -delete

rm -rf firefox
cp -R "$tmp/firefox" firefox
echo "Firefox build: firefox/"

# 3. Package
mkdir -p dist
xpi="dist/mymind-firefox-$version.xpi"
rm -f "$xpi"
(cd firefox && zip -qr -X "../$xpi" . -x '.*')
echo "Add-on:        $xpi"
