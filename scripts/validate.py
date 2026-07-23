#!/usr/bin/env python3
"""
validate.py — self-contained CI validator for AmigaPKG package entries.

Mirrors `pkgindex validate` (the authoritative Swift validator in AmigaImager's
AmigaBuildKit). No third-party deps — stdlib only — so public CI needs nothing
but Python 3. Keep the rules here in sync with pkgindex validate.

Usage:
  scripts/validate.py packages/            # validate every entry (offline)
  scripts/validate.py packages/foo.json --check-archives   # also hash-verify
Exit code 0 = all good, 1 = at least one error.
"""
import sys, os, json, re, hashlib, urllib.request

KNOWN_CAPS = {
    "copy-glob-v1", "strip-junk-v1", "merge-nested-v1", "set-exec-v1",
    "script-inject-v1", "tooltype-edit-v1", "make-assign-v1", "place-file-v1",
    "icon-patch-v1", "adf-unwrap-v1", "installer-script-v1", "host-builtin-v1",
}
ID_RE  = re.compile(r"^[a-z0-9][a-z0-9._-]*$")
SHA_RE = re.compile(r"^[0-9a-f]{64}$")

errors = 0
warnings = 0
seen = set()


def err(pid, m):
    global errors
    print(f"ERROR  [{pid}] {m}")
    errors += 1


def warn(pid, m):
    global warnings
    print(f"warn   [{pid}] {m}")
    warnings += 1


def collect(path):
    if os.path.isdir(path):
        return sorted(os.path.join(path, f) for f in os.listdir(path) if f.endswith(".json"))
    return [path]


def entries_in(fp):
    with open(fp, encoding="utf-8") as fh:
        doc = json.load(fh)
    return doc if isinstance(doc, list) else [doc]


def validate(entry, check_archives):
    pid = entry.get("id") or "?"
    if not entry.get("id"):
        err(pid, "missing id")
    elif not ID_RE.match(entry["id"]):
        err(pid, "id must be lower-case [a-z0-9._-]")
    if entry.get("id") in seen:
        err(pid, "duplicate id across the set")
    seen.add(entry.get("id"))

    if not (entry.get("name") or "").strip():
        err(pid, "missing name")
    if not (entry.get("category") or "").strip():
        warn(pid, "empty category")

    for c in entry.get("requiredCapabilities", []):
        if c not in KNOWN_CAPS:
            err(pid, f"unknown capability '{c}'")
    if "installer-script-v1" in entry.get("requiredCapabilities", []):
        warn(pid, "declares installer-script (arbitrary native code) — needs careful review")

    arch = entry.get("archive")
    if not arch:
        warn(pid, "no archive — not fetch-able by amipkg")
        return
    url = arch.get("url", "")
    if not url or "REPLACE-ME" in url:
        err(pid, "archive.url is empty/placeholder")
    sha = arch.get("sha256")
    if sha is None:
        warn(pid, "no archive.sha256 — amipkg can't verify a download")
    elif not SHA_RE.match(sha):
        err(pid, "archive.sha256 must be 64 lower-case hex chars")

    if check_archives and url and sha and SHA_RE.match(sha):
        try:
            with urllib.request.urlopen(url, timeout=60) as r:
                data = r.read()
        except Exception as e:  # noqa: BLE001
            err(pid, f"archive.url not reachable: {e}")
            return
        got = hashlib.sha256(data).hexdigest()
        if got != sha:
            err(pid, f"archive sha256 MISMATCH: url has {got[:16]}…, entry says {sha[:16]}…")
        else:
            print(f"ok     [{pid}] archive sha256 matches ({len(data)} bytes)")


def main():
    args = sys.argv[1:]
    check_archives = "--check-archives" in args
    paths = [a for a in args if not a.startswith("--")] or ["packages"]
    count = 0
    for p in paths:
        for fp in collect(p):
            try:
                ents = entries_in(fp)
            except Exception as e:  # noqa: BLE001
                err(os.path.basename(fp), f"not valid JSON: {e}")
                continue
            for e in ents:
                validate(e, check_archives)
                count += 1
    print(f"validate: {count} entr{'y' if count == 1 else 'ies'}, {errors} error(s), {warnings} warning(s)")
    sys.exit(1 if errors else 0)


if __name__ == "__main__":
    main()
