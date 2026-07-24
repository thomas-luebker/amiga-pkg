#!/usr/bin/env python3
"""
amigapkg — a standalone tool for authoring and validating AmigaPKG package
entries. Pure Python 3 stdlib: no third-party packages, no Swift, no
AmigaImager — runs anywhere Python does (Windows/Linux/macOS), so anyone can
contribute a package.

  amigapkg.py add --archive foo.lha --id foo --name "Foo" \
      --category Utilities --version 1.2 --url https://aminet.net/.../foo.lha
  amigapkg.py validate packages/ [--check-archives]

`add` scaffolds a package Entry JSON (computing the archive SHA-256 + size).
`validate` checks entries the way CI does. A maintainer then merges the entry
and signs it into the published index (that signing step is the only
maintainer-only, non-Python part — see MAINTAINERS.md).

The Entry format is documented in schema/entry.schema.json. This tool is the
authoritative Python mirror of AmigaImager's `pkgindex` (Swift) `add`/`validate`
— keep the two in sync; they share the same entry format and rules.
"""
import sys
import os
import json
import re
import hashlib
import argparse
import urllib.request

# Capability vocabulary (mirror of PackageIndex.RecipeCapability). Tier-A =
# portable/on-Amiga-installable; the rest are build-only / escape-hatch.
KNOWN_CAPS = {
    "copy-glob-v1", "strip-junk-v1", "merge-nested-v1", "set-exec-v1",
    "script-inject-v1", "tooltype-edit-v1", "make-assign-v1", "place-file-v1",
    "icon-patch-v1", "adf-unwrap-v1", "installer-script-v1", "host-builtin-v1",
}
ID_RE = re.compile(r"^[a-z0-9][a-z0-9._-]*$")
SHA_RE = re.compile(r"^[0-9a-f]{64}$")


def _fetch(url, timeout=180):
    """Download url via curl (system CA; works for http and https)."""
    import subprocess
    p = subprocess.run(["/usr/bin/curl", "-sL", "--max-time", str(timeout), url],
                       capture_output=True)
    if p.returncode != 0 or not p.stdout:
        raise RuntimeError("curl rc=%d" % p.returncode)
    return p.stdout


def _readme_version(archive_url):
    """For an Aminet .lha URL, read the current Version: from the sibling .readme."""
    if not archive_url.endswith(".lha"):
        return None
    try:
        text = _fetch(archive_url[:-4] + ".readme", 30).decode("latin-1", "replace")
    except Exception:
        return None
    m = re.search(r"(?im)^Version:\s*(.+?)\s*$", text)
    return m.group(1).strip()[:24] if m else None


# --------------------------------------------------------------------------- add
def cmd_add(a):
    if not os.path.isfile(a.archive):
        sys.exit(f"amigapkg: no archive at {a.archive}")
    h = hashlib.sha256()
    with open(a.archive, "rb") as fh:
        for chunk in iter(lambda: fh.read(1 << 16), b""):
            h.update(chunk)
    sha = h.hexdigest()
    size = os.path.getsize(a.archive)
    url = a.url or f"https://REPLACE-ME/{os.path.basename(a.archive)}"

    # Emit every field the (auto-synthesized) Swift decoder requires present —
    # the optional ones (requirements/recipe/sortVersion/install) are omitted.
    entry = {
        "id": a.id,
        "version": a.version,
        "name": a.name or a.id,
        "category": a.category,
        "description": a.desc,
        "deps": [],
        "conflicts": [],
        "provides": [],
        "archive": {"url": url, "mirrors": [], "sha256": sha, "sizeBytes": size},
        "requiredCapabilities": [],
        "tier": "A",
    }
    out = a.out or f"{a.id}.json"
    with open(out, "w", encoding="utf-8") as fh:
        json.dump(entry, fh, sort_keys=True, indent=2)
        fh.write("\n")
    print(f"wrote {out}: id={a.id}, sha256={sha[:16]}…, size={size}")
    print("Set the real archive url (and any deps/recipe), then validate + open a PR.")
    if "REPLACE-ME" in url:
        sys.stderr.write(f"amigapkg: note: archive url is a placeholder — set --url or edit {out}\n")


# ------------------------------------------------------------------------ refresh
def cmd_refresh(a):
    """Re-scan each entry's archive: recompute sha256/size, read the current
    Aminet version, and update the entry when the upstream file changed (a new
    upload). Most Aminet URLs are unversioned, so this both catches new versions
    AND keeps the sha256 valid (else `amipkg fetch` would fail after an update).
    A maintainer then re-signs. `--check-only` reports without writing."""
    changed = updated_files = 0
    for path in (a.paths or ["packages"]):
        for fp in _collect(path):
            try:
                entry = json.load(open(fp, encoding="utf-8"))
            except Exception as e:  # noqa: BLE001
                print(f"skip {fp}: bad JSON ({e})")
                continue
            arch = entry.get("archive") or {}
            url = arch.get("url", "")
            pid = entry.get("id", os.path.basename(fp))
            if not url or "REPLACE-ME" in url:
                continue
            try:
                data = _fetch(url)
            except Exception as e:  # noqa: BLE001
                print(f"WARN {pid}: fetch failed ({e})")
                continue
            new_sha = hashlib.sha256(data).hexdigest()
            if new_sha == arch.get("sha256"):
                print(f"ok      {pid} (unchanged)")
                continue
            new_ver = _readme_version(url) or entry.get("version", "-")
            old_ver = entry.get("version", "-")
            print(f"UPDATED {pid}: {old_ver} -> {new_ver}  sha {str(arch.get('sha256'))[:8]}->{new_sha[:8]}")
            changed += 1
            if not a.check_only:
                arch["sha256"] = new_sha
                arch["sizeBytes"] = len(data)
                entry["version"] = new_ver
                entry["archive"] = arch
                with open(fp, "w", encoding="utf-8") as fh:
                    json.dump(entry, fh, sort_keys=True, indent=2)
                    fh.write("\n")
                updated_files += 1
    verb = "would update" if a.check_only else "updated"
    print(f"\nrefresh: {changed} upstream change(s); {verb} {updated_files if not a.check_only else changed} entr(y/ies)."
          + (" Re-sign + publish." if changed and not a.check_only else ""))


# ---------------------------------------------------------------------- validate
def _collect(path):
    if os.path.isdir(path):
        return sorted(os.path.join(path, f) for f in os.listdir(path) if f.endswith(".json"))
    return [path]


def cmd_validate(a):
    errors = warnings = count = 0
    seen = set()

    def err(pid, m):
        nonlocal errors
        print(f"ERROR  [{pid}] {m}")
        errors += 1

    def warn(pid, m):
        nonlocal warnings
        print(f"warn   [{pid}] {m}")
        warnings += 1

    for path in (a.paths or ["packages"]):
        for fp in _collect(path):
            try:
                doc = json.load(open(fp, encoding="utf-8"))
            except Exception as e:  # noqa: BLE001
                err(os.path.basename(fp), f"not valid JSON: {e}")
                continue
            for e in (doc if isinstance(doc, list) else [doc]):
                count += 1
                pid = e.get("id") or "?"
                if not e.get("id"):
                    err(pid, "missing id")
                elif not ID_RE.match(e["id"]):
                    err(pid, "id must be lower-case [a-z0-9._-]")
                if e.get("id") in seen:
                    err(pid, "duplicate id across the set")
                seen.add(e.get("id"))
                if not (e.get("name") or "").strip():
                    err(pid, "missing name")
                if not (e.get("category") or "").strip():
                    warn(pid, "empty category")
                for c in e.get("requiredCapabilities", []):
                    if c not in KNOWN_CAPS:
                        err(pid, f"unknown capability '{c}'")
                if "installer-script-v1" in e.get("requiredCapabilities", []):
                    warn(pid, "declares installer-script (arbitrary native code) — needs careful review")
                arch = e.get("archive")
                if not arch:
                    warn(pid, "no archive — not fetch-able by amipkg")
                    continue
                url = arch.get("url", "")
                if not url or "REPLACE-ME" in url:
                    err(pid, "archive.url is empty/placeholder")
                sha = arch.get("sha256")
                if sha is None:
                    warn(pid, "no archive.sha256 — amipkg can't verify a download")
                elif not SHA_RE.match(sha):
                    err(pid, "archive.sha256 must be 64 lower-case hex chars")
                if a.check_archives and url and sha and SHA_RE.match(sha):
                    try:
                        with urllib.request.urlopen(url, timeout=60) as r:
                            data = r.read()
                    except Exception as ex:  # noqa: BLE001
                        err(pid, f"archive.url not reachable: {ex}")
                        continue
                    got = hashlib.sha256(data).hexdigest()
                    if got != sha:
                        err(pid, f"archive sha256 MISMATCH: url has {got[:16]}…, entry says {sha[:16]}…")
                    else:
                        print(f"ok     [{pid}] archive sha256 matches ({len(data)} bytes)")

    print(f"validate: {count} entr{'y' if count == 1 else 'ies'}, {errors} error(s), {warnings} warning(s)")
    sys.exit(1 if errors else 0)


# --------------------------------------------------------------------------- cli
def main():
    p = argparse.ArgumentParser(prog="amigapkg", description="Author + validate AmigaPKG package entries.")
    sub = p.add_subparsers(dest="cmd", required=True)

    pa = sub.add_parser("add", help="scaffold a package entry from an archive (computes sha256 + size)")
    pa.add_argument("--archive", required=True, help="path to the package .lha")
    pa.add_argument("--id", required=True, help="unique lower-case package id")
    pa.add_argument("--name", default="", help="display name")
    pa.add_argument("--category", default="Utilities", help="e.g. Utilities, Games, Network")
    pa.add_argument("--version", default="-", help="display version")
    pa.add_argument("--url", default="", help="where the .lha is hosted (Aminet preferred)")
    pa.add_argument("--desc", default="", help="short description")
    pa.add_argument("--out", default="", help="output JSON path (default <id>.json)")
    pa.set_defaults(func=cmd_add)

    pr = sub.add_parser("refresh", help="re-scan Aminet: update sha256/size/version when the upstream file changed")
    pr.add_argument("paths", nargs="*", help="files or dirs (default: packages/)")
    pr.add_argument("--check-only", action="store_true", help="report changes without writing")
    pr.set_defaults(func=cmd_refresh)

    pv = sub.add_parser("validate", help="validate entries (schema, ids, capabilities, sha256)")
    pv.add_argument("paths", nargs="*", help="files or dirs (default: packages/)")
    pv.add_argument("--check-archives", action="store_true", help="download each archive and verify its sha256")
    pv.set_defaults(func=cmd_validate)

    args = p.parse_args()
    args.func(args)


if __name__ == "__main__":
    main()
