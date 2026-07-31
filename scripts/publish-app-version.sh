#!/bin/sh
# publish-app-version.sh — publish the Amiga Imager app-update manifests.
#
#   scripts/publish-app-version.sh <version> <build> <zip-url> <notes-url> [<local-zip>]
#   e.g. scripts/publish-app-version.sh 0.99.8 260731 \
#          https://amiga-imager.com/Amiga-Imager-v0.99.8.zip \
#          https://amiga-imager.com/release-notes-v0.99.8/ \
#          ~/Desktop/build/Amiga-Imager-v0.99.8.zip
#
# TWO manifests are published, on purpose:
#
#   docs/appcast/amiga-imager.json  — the original signed manifest. Every
#       release up to and including 0.99.7 polls it (UpdateChecker.swift) and
#       shows a "new version, here are the notes" alert. Keep publishing it
#       until those versions are gone, or they never hear about updates again.
#   docs/appcast/amiga-imager.xml   — the Sparkle appcast, used by 0.99.8+ for
#       real in-app updates. Needs the LOCAL zip: Sparkle records the exact
#       byte length and an EdDSA signature over the archive itself.
#
# The two use DIFFERENT keys, and both are needed:
#   JSON    -> the amipkg project Ed25519 key (AMIPKG_KEYFILE, offline copy).
#   Sparkle -> the Sparkle EdDSA key in the login Keychain, read by
#              sign_update. NEVER stored in a repo. If it is lost, no existing
#              installation can ever be updated again — back it up.
#
# Env: PKGINDEX (pkgindex binary), AMIPKG_KEYFILE (project key file),
#      SPARKLE_BIN (dir holding sign_update; auto-detected from DerivedData).
set -eu
HERE="$(cd "$(dirname "$0")/.." && pwd)"
VER="$1"; BUILD="$2"; ZIPURL="$3"; NOTESURL="$4"; ZIPFILE="${5:-}"
PKGINDEX="${PKGINDEX:-$HOME/Development/AmigaImager/AmigaBuildKit/.build/release/pkgindex}"
KEYFILE="${AMIPKG_KEYFILE:-$HOME/Desktop/amiga-imager-repo/SIGNING-KEY-KEEP-OFFLINE.txt}"
[ -x "$PKGINDEX" ] || { echo "pkgindex not found at $PKGINDEX (build: swift build -c release --product pkgindex)"; exit 1; }
[ -f "$KEYFILE" ] || { echo "key file not found at $KEYFILE"; exit 1; }

# --- 1. the legacy signed JSON manifest (pre-0.99.8 clients) ------------------
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

# --- 2. the Sparkle appcast (0.99.8+) ----------------------------------------
XML="$HERE/docs/appcast/amiga-imager.xml"
if [ -n "$ZIPFILE" ]; then
    [ -f "$ZIPFILE" ] || { echo "zip not found: $ZIPFILE"; exit 1; }
    if [ -n "${SPARKLE_BIN:-}" ]; then
        SIGN="$SPARKLE_BIN/sign_update"
    else
        SIGN="$(find "$HOME/Library/Developer/Xcode/DerivedData" \
                     -path '*artifacts/sparkle/Sparkle/bin/sign_update' \
                     ! -path '*old_dsa*' 2>/dev/null | head -1)"
    fi
    [ -n "$SIGN" ] && [ -x "$SIGN" ] || {
        echo "sign_update not found — build the app once so SwiftPM fetches"
        echo "Sparkle, or set SPARKLE_BIN to the directory holding it."; exit 1; }

    # Prints ready-made attributes: sparkle:edSignature="…" length="…"
    ATTRS="$("$SIGN" "$ZIPFILE")"
    case "$ATTRS" in
        *edSignature*) : ;;
        *) echo "sign_update produced no signature — is the Sparkle key in the Keychain?"; exit 1 ;;
    esac
    PUBDATE="$(date -u '+%a, %d %b %Y %H:%M:%S +0000')"

    cat > "$XML" <<XMLDOC
<?xml version="1.0" encoding="utf-8"?>
<rss version="2.0" xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle">
  <channel>
    <title>Amiga Imager</title>
    <link>https://thomas-luebker.github.io/amiga-pkg/appcast/amiga-imager.xml</link>
    <description>Updates for Amiga Imager.</description>
    <language>en</language>
    <item>
      <title>Version $VER</title>
      <pubDate>$PUBDATE</pubDate>
      <sparkle:releaseNotesLink>$NOTESURL</sparkle:releaseNotesLink>
      <sparkle:version>$BUILD</sparkle:version>
      <sparkle:shortVersionString>$VER</sparkle:shortVersionString>
      <sparkle:minimumSystemVersion>14.0</sparkle:minimumSystemVersion>
      <enclosure url="$ZIPURL" type="application/octet-stream" $ATTRS />
    </item>
  </channel>
</rss>
XMLDOC
    # A malformed appcast silently stops EVERY client from updating, so it is
    # parsed here rather than discovered from a user report.
    python3 -c "import xml.dom.minidom; xml.dom.minidom.parse('$XML')" \
        || { echo "generated appcast is not well-formed XML"; exit 1; }
    echo "sparkle appcast written (build $BUILD)"
else
    echo "NOTE: no local zip given — the Sparkle appcast was NOT updated."
    echo "      0.99.8+ clients will keep seeing the previous version."
fi

cd "$HERE"
git add docs/appcast
git commit -m "appcast: Amiga Imager $VER (build $BUILD)"
git push
echo "published: $VER ($BUILD) -> $ZIPURL"
