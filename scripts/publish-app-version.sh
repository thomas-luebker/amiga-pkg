#!/bin/sh
# publish-app-version.sh — publish the Amiga Imager app-update manifest.
#
#   scripts/publish-app-version.sh <version> <build> <zip-url> <notes-url>
#   e.g. scripts/publish-app-version.sh 0.99.6 260728 \
#          https://amiga-imager.com/Amiga-Imager-v0.99.6.zip \
#          https://amiga-imager.com/release-notes-v0.99.6/
#
# Writes docs/appcast/amiga-imager.json, signs it with the project key
# (detached .sig, SAME Ed25519 key as the package index), verifies, commits
# and pushes. The app checks this manifest at launch (UpdateCheck.swift).
#
# Env: PKGINDEX (path to the pkgindex binary), AMIPKG_KEYFILE (key file with
# a "privateKey: <base64>" line; default = the offline Desktop copy).
set -eu
HERE="$(cd "$(dirname "$0")/.." && pwd)"
VER="$1"; BUILD="$2"; ZIPURL="$3"; NOTESURL="$4"
PKGINDEX="${PKGINDEX:-$HOME/Development/AmigaImager/AmigaBuildKit/.build/release/pkgindex}"
KEYFILE="${AMIPKG_KEYFILE:-$HOME/Desktop/amiga-imager-repo/SIGNING-KEY-KEEP-OFFLINE.txt}"
[ -x "$PKGINDEX" ] || { echo "pkgindex not found at $PKGINDEX (build: swift build -c release --product pkgindex)"; exit 1; }
[ -f "$KEYFILE" ] || { echo "key file not found at $KEYFILE"; exit 1; }

OUT="$HERE/docs/appcast/amiga-imager.json"
cat > "$OUT" <<JSON
{
  "version": "$VER",
  "build": $BUILD,
  "url": "$ZIPURL",
  "notesURL": "$NOTESURL"
}
JSON

# Extract ONLY the key value into a session-temp file; never echo it.
KEYTMP="$(mktemp)"
trap 'rm -f "$KEYTMP"' EXIT
awk -F': *' '/^privateKey:/ {print $2}' "$KEYFILE" > "$KEYTMP"
[ -s "$KEYTMP" ] || { echo "no privateKey line in $KEYFILE"; exit 1; }
"$PKGINDEX" signfile "$OUT" --sign "@$KEYTMP" --public-key "tqZXIleRDYeU69ZsLNdvN790MUYdEKqvHctivyIhLEY="

cd "$HERE"
git add docs/appcast
git commit -m "appcast: Amiga Imager $VER (build $BUILD)"
git push
echo "published: $VER ($BUILD) -> $ZIPURL"
