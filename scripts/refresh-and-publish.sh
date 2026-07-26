#!/bin/sh
# refresh-and-publish.sh — one-shot backend update of the WHOLE repo.
#
# Re-scans every package entry against its upstream archive (recomputing sha256
# + size, re-reading the Aminet .readme version), then regenerates + Ed25519-
# signs the published index and — with --push — commits and pushes it. This is
# the single command a maintainer runs when "a batch of upstream versions moved"
# rather than editing entries by hand.
#
# Usage (run from anywhere; paths default to the standard checkout):
#   scripts/refresh-and-publish.sh              # refresh + re-sign locally
#   scripts/refresh-and-publish.sh --push       # + git commit & push docs/
#   scripts/refresh-and-publish.sh --check-only # report upstream changes, no writes
#   scripts/refresh-and-publish.sh --key <file> --kit <AmigaBuildKit dir>
#
# Env fallbacks: AMIPKG_SIGNING_KEY, AMIGABUILDKIT_DIR, AMIPKG_ARCHIVES.
#
# The private key never leaves disk: only its `privateKey:` line is copied to a
# short-lived temp file, used to sign, and deleted on exit (even on error).
set -eu

REPO="$(cd "$(dirname "$0")/.." && pwd)"
KEY="${AMIPKG_SIGNING_KEY:-$HOME/Desktop/amiga-imager-repo/SIGNING-KEY-KEEP-OFFLINE.txt}"
KIT="${AMIGABUILDKIT_DIR:-$HOME/Development/AmigaImager/AmigaBuildKit}"
ARCHIVES="${AMIPKG_ARCHIVES:-$HOME/Library/Application Support/AmigaImager/PackageCache}"
PUBKEY="tqZXIleRDYeU69ZsLNdvN790MUYdEKqvHctivyIhLEY="

PUSH=0
CHECK_ONLY=0
while [ $# -gt 0 ]; do
    case "$1" in
        --push)       PUSH=1 ;;
        --check-only) CHECK_ONLY=1 ;;
        --key)        KEY="$2"; shift ;;
        --kit)        KIT="$2"; shift ;;
        *) echo "unknown arg: $1" >&2; exit 2 ;;
    esac
    shift
done

RULES="$KIT/../BundledResources/InputFiles/ListofPackagestoInstall.CSV"

echo "==> Refreshing all entries against upstream…"
if [ "$CHECK_ONLY" = 1 ]; then
    python3 "$REPO/amigapkg.py" refresh "$REPO/packages" --check-only
    echo "(check-only: no entries written, index not re-signed)"
    exit 0
fi
python3 "$REPO/amigapkg.py" refresh "$REPO/packages"

echo "==> Validating…"
python3 "$REPO/amigapkg.py" validate "$REPO/packages"

echo "==> Regenerating + signing the index…"
[ -f "$KEY" ] || { echo "signing key not found: $KEY" >&2; exit 1; }
KEYTMP="$(mktemp)"
trap 'rm -f "$KEYTMP"' EXIT INT TERM
grep '^privateKey:' "$KEY" | sed 's/^privateKey:[[:space:]]*//' > "$KEYTMP"
# Fill missing versions (base-catalog entries have none) from Aminet
# readmes / filenames into the overlay, then bake it into the index.
python3 "$REPO/amigapkg.py" versions --index "$REPO/docs/packages.json" \
    --out "$REPO/versions.json" || true

( cd "$KIT" && swift run pkgindex generate \
    --rules      "$RULES" \
    --extra      "$REPO/packages/" \
    --archives   "$ARCHIVES" \
    --versions   "$REPO/versions.json" \
    --sign       "@$KEYTMP" \
    --public-key "$PUBKEY" \
    --out        "$REPO/docs/packages.json" )
rm -f "$KEYTMP"
trap - EXIT INT TERM

if [ "$PUSH" = 1 ]; then
    echo "==> Committing + pushing…"
    ( cd "$REPO" \
      && git add docs/packages.json docs/packages.json.sig packages/ \
      && git commit -m "publish: refresh upstream versions + re-sign index" \
      && git push )
    echo "==> Published. Amigas pick it up on the next 'amipkg update'."
else
    echo "==> Done (local). Review docs/, then commit+push (or re-run with --push)."
fi
