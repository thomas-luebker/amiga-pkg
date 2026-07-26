#!/bin/sh
# nightly-publish.sh — the FULLY AUTOMATED catalog refresh + sign + publish.
# Runs on the Pi 5 (loki@192.168.178.91, always-on) via a systemd user
# timer at 03:10 nightly.
# The signing key lives ONLY here and on the offline Desktop copy — never
# in any cloud. GitHub is just the git remote.
set -eu
HOME_DIR="$HOME/amipkg-publisher"
REPO="$HOME_DIR/amiga-pkg"
KEY="$HOME_DIR/signing-key.txt"
LOG="$HOME_DIR/logs/nightly-$(date +%Y%m%d).log"
PUBKEY="tqZXIleRDYeU69ZsLNdvN790MUYdEKqvHctivyIhLEY="
exec >>"$LOG" 2>&1
echo "=== nightly $(date) ==="

notify() {  # best-effort push via the Pi (no secret -> just logs)
    curl -s --max-time 10 -X POST http://127.0.0.1:9092/notify \
        -H 'Content-Type: application/json' \
        -d "{\"title\":\"amipkg nightly\",\"body\":\"$1\"}" >/dev/null 2>&1 || true
}

[ -f "$KEY" ] || { echo "signing key missing at $KEY - aborting"; notify "FAILED: signing key missing on the Trashcan"; exit 1; }

cd "$REPO"
git pull --rebase --quiet

# 1. upstream drift: recompute sha/size/version for curated entries
python3 amigapkg.py refresh || { notify "FAILED: refresh"; exit 1; }
# 2. version overlay for the base catalog
python3 amigapkg.py versions --index docs/packages.json --out versions.json || true
# 3. keep the archive cache fresh (new/changed upstream files)
python3 - <<'PYEOF'
import json, os, subprocess, hashlib
cache = os.path.expanduser('~/amipkg-publisher/PackageCache')
d = json.load(open('docs/packages.json'))
for p in d['packages']:
    a = p.get('archive') or {}
    url, sha = a.get('url'), a.get('sha256')
    if not url or not url.endswith('.lha'):
        continue
    base = url.rsplit('/', 1)[-1].split('?')[0]
    dest = os.path.join(cache, base)
    have = None
    if os.path.exists(dest):
        have = hashlib.sha256(open(dest, 'rb').read()).hexdigest()
    if have is None or (sha and have != sha):
        subprocess.run(['curl', '-sL', '--max-time', '180', '-A', 'amipkg-curator',
                        '-o', dest, url], check=False)
PYEOF
# 4. generate + SIGN (key value only, short-lived temp file)
KEYTMP=$(mktemp)
trap 'rm -f "$KEYTMP"' EXIT
awk '/privateKey:/ {print $2}' "$KEY" > "$KEYTMP"
"$HOME_DIR/pkgindex" generate \
    --rules "$HOME_DIR/ListofPackagestoInstall.CSV" \
    --extra packages/ \
    --archives "$HOME_DIR/PackageCache" \
    --versions versions.json \
    --sign "@$KEYTMP" --public-key "$PUBKEY" \
    --out docs/packages.json
rm -f "$KEYTMP"

# 5. publish only when something actually changed
if git diff --quiet; then
    echo "no changes tonight"
    exit 0
fi
git add packages/ versions.json docs/packages.json docs/packages.json.sig
git commit -m "nightly: automated refresh + re-sign ($(date +%Y-%m-%d))"
git push
CHANGED=$(git show --stat --oneline HEAD | tail -1)
echo "published: $CHANGED"
notify "published catalog update: $CHANGED"
