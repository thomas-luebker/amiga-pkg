#!/bin/sh
# submission-courier.sh — ferry on-Amiga package submissions to GitHub review.
#
# Runs on the Pi every 4 hours (amipkg-courier.timer). Flow:
#   amiga-imager.org dropbox (pending/) --> validate on the Pi -->
#   push branch submission/<id>-<stamp> --> notify Thomas (compare link)
# Invalid submissions are rejected here and NEVER touch the repo. Every
# handled file is ACKed (moved to processed/ on the webspace) either way.
# Trust unchanged: review + offline signing still gate the catalog.
#
# Needs ~/amipkg-publisher/courier.env with COURIER_KEY=<shared secret>.
set -u
HOME_DIR="$HOME/amipkg-publisher"
REPO="$HOME_DIR/amiga-pkg"
ENDPOINT="https://amiga-imager.org/packages"
LOG="$HOME_DIR/logs/courier-$(date +%Y%m%d).log"
mkdir -p "$HOME_DIR/logs"
exec >>"$LOG" 2>&1
echo "=== courier run $(date -u '+%Y-%m-%d %H:%M:%S') UTC ==="

notify() {
    curl -s --max-time 10 -X POST http://127.0.0.1:9092/notify \
        -H 'Content-Type: application/json' \
        -d "{\"title\":\"amipkg submission\",\"body\":\"$1\"}" >/dev/null 2>&1 || true
}

[ -f "$HOME_DIR/courier.env" ] || { echo "courier.env missing"; exit 1; }
. "$HOME_DIR/courier.env"
[ -n "${COURIER_KEY:-}" ] || { echo "COURIER_KEY empty"; exit 1; }

PENDING=$(curl -sf --max-time 30 "$ENDPOINT/submissions?key=$COURIER_KEY" \
    | python3 -c "import json,sys; print('\n'.join(json.load(sys.stdin).get('pending',[])))" 2>/dev/null)
[ -n "$PENDING" ] || { echo "nothing pending"; exit 0; }

export GIT_SSH_COMMAND="ssh -i $HOME/.ssh/amipkg_deploy -o IdentitiesOnly=yes"
cd "$REPO" || exit 1
git fetch -q origin
git checkout -q main
git reset -q --hard origin/main

for FILE in $PENDING; do
    echo "--- $FILE"
    TMP="$HOME_DIR/tmp-submission.json"
    curl -sf --max-time 30 "$ENDPOINT/submissions/$FILE?key=$COURIER_KEY" -o "$TMP" \
        || { echo "fetch failed, skipping"; continue; }
    ID=$(python3 -c "import json;print(json.load(open('$TMP'))['id'])" 2>/dev/null)
    ack() { curl -sf --max-time 30 -X POST "$ENDPOINT/submissions/$FILE?key=$COURIER_KEY" >/dev/null 2>&1 || true; }
    if [ -z "$ID" ]; then
        echo "unparseable submission - rejected"; ack; continue
    fi
    if [ -f "packages/$ID.json" ]; then
        echo "id '$ID' already in catalog - rejected"
        notify "Rejected on-Amiga submission '$ID': id already exists"
        ack; continue
    fi
    # Verify the submitted sha256 against a FRESH download on the Pi: a
    # corrupted download on the submitter's Amiga (flaky WiFi, dying CF)
    # would otherwise produce an entry whose pin never matches the real
    # archive - reviewed, merged, and failing every install.
    SUB_URL=$(python3 -c "import json;print(json.load(open('$TMP'))['archive']['url'])" 2>/dev/null)
    SUB_SHA=$(python3 -c "import json;print(json.load(open('$TMP'))['archive']['sha256'])" 2>/dev/null)
    ARCH="$HOME_DIR/tmp-submission-archive"
    if ! curl -sfL --max-time 300 "$SUB_URL" -o "$ARCH"; then
        echo "archive download failed ($SUB_URL) - rejected"
        notify "Rejected on-Amiga submission '$ID': archive URL not fetchable"
        ack; rm -f "$TMP" "$ARCH"; continue
    fi
    PI_SHA=$(sha256sum "$ARCH" | cut -d' ' -f1)
    rm -f "$ARCH"
    if [ "$PI_SHA" != "$SUB_SHA" ]; then
        echo "sha mismatch: submitted $SUB_SHA, Pi got $PI_SHA - rejected"
        notify "Rejected on-Amiga submission '$ID': sha256 mismatch (their download was likely corrupted)"
        ack; rm -f "$TMP"; continue
    fi
    echo "sha verified on the Pi"

    BRANCH="submission/$ID-$(date -u +%Y%m%d%H%M)"
    git checkout -q -b "$BRANCH"
    cp "$TMP" "packages/$ID.json"
    if python3 amigapkg.py validate >/dev/null 2>&1; then
        git add "packages/$ID.json"
        git commit -q -m "on-Amiga submission: $ID (via amipkg submit)

Authored on a real Amiga - the archive's SHA-256 pin was computed on
the submitting machine. Review license + entry, then merge; the Pi
signs it into the catalog at the next publish."
        if git push -q origin "$BRANCH"; then
            echo "pushed $BRANCH"
            notify "New on-Amiga package submission: $ID - review: github.com/thomas-luebker/amiga-pkg/compare/main...$BRANCH"
        else
            echo "push failed for $BRANCH"
            notify "Submission '$ID' validated but branch push FAILED - check the Pi"
        fi
    else
        echo "validate failed - rejected"
        notify "Rejected on-Amiga submission '$ID': did not pass amigapkg.py validate"
    fi
    rm -f "packages/$ID.json"   # reset --hard ignores UNTRACKED files -
                                # without this a rejected draft poisons
                                # every later validate (smoke-test lesson)
    git checkout -q main
    git reset -q --hard origin/main
    git clean -qfd packages/
    git branch -q -D "$BRANCH" 2>/dev/null || true
    ack
    rm -f "$TMP"
done
echo "done"
